# Copyright (C) 2013-2015 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::OpenChange;

use base qw(
    EBox::Module::Kerberos
    EBox::CA::Observer
);

use EBox::Config;
use EBox::Exceptions::Sudo::Command;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Item;
use EBox::Module::Base;
use EBox::OpenChange::LdapUser;
use EBox::OpenChange::ExchConfigurationContainer;
use EBox::OpenChange::ExchOrganizationContainer;
use EBox::OpenChange::VDomainsLdap;
use EBox::DBEngineFactory;
use EBox::OpenChange::DBEngine;
use EBox::OpenChange::SOGO::DBEngine;

use EBox::Samba;
use EBox::Sudo;
use EBox::Util::Certificate;

use TryCatch::Lite;
use String::Random;
use File::Basename;

use constant SOGO_PORT => 20000;
use constant SOGO_DEFAULT_PREFORK => 3;
use constant SOGO_APACHE_CONF => '/etc/apache2/conf-available/sogo.conf';

use constant SOGO_DEFAULT_FILE => '/etc/default/sogo';
use constant SOGO_CONF_FILE => '/etc/sogo/sogo.conf';
use constant SOGO_PID_FILE => '/var/run/sogo/sogo.pid';
use constant SOGO_LOG_FILE => '/var/log/sogo/sogo.log';

use constant OCSMANAGER_CONF_FILE => '/etc/ocsmanager/ocsmanager.ini';

use constant RPCPROXY_AUTH_CACHE_DIR => '/var/cache/ntlmauthhandler';
use constant RPCPROXY_STOCK_CONF_FILE => '/etc/apache2/conf.d/rpcproxy.conf';

use constant OPENCHANGE_CONF_FILE => '/etc/samba/openchange.conf';
use constant OPENCHANGE_MYSQL_PASSWD_FILE => EBox::Config->conf . '/openchange/mysql.passwd';
use constant OPENCHANGE_IMAP_PASSWD_FILE => EBox::Samba::PRIVATE_DIR() . 'mapistore/master.password';
use constant OPENCHANGE_DOVECOT_PLUGIN_FILE => '/usr/lib/dovecot/modules/lib90_openchange_plugin.so';

use constant APACHE_OCSMANAGER_PORT_HTTP    => 80;
use constant APACHE_OCSMANAGER_PORT_HTTPS   => 443;
use constant APACHE_OCSMANAGER_CONF  => '/etc/apache2/conf-available/zentyal-ocsmanager.conf';

use constant APACHE_PORTS_FILE => '/etc/apache2/ports.conf';

# Method: _create
#
#   The constructor, instantiate module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'openchange',
                                      printableName => 'OpenChange',
                                      @_);
    bless ($self, $class);
    return $self;
}

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        my $firewall = $self->global()->modInstance('firewall');
        $firewall->setInternalService('HTTPS', 'accept');
        $firewall->saveConfigRecursive();
    }

    if ($self->changed()) {
        $self->saveConfigRecursive();
    }
}

# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [
            {
             'action' => __('Enable proxy, proxy_http and headers Apache 2 modules.'),
             'reason' => __('To make OpenChange Webmail be accesible at http://ip/SOGo/.'),
             'module' => 'sogo'
            },
    ];
}


# Method: enableActions
#
# Action to do when openchange module is enabled for first time
#
sub enableActions
{
    my ($self) = @_;

    # Execute enable-module script
    $self->SUPER::enableActions();
    #$self->_setupDNS();

    # FIXME: move this to the new "Enable Webmail" checkbox
    #my $mail = EBox::Global->modInstance('mail');
    #unless ($mail->imap() or $mail->imaps()) {
    #    throw EBox::Exceptions::External(__x('OpenChange Webmail module needs IMAP or IMAPS service enabled if ' .
    #                                         'using Zentyal mail service. You can enable it at ' .
    #                                         '{openurl}Mail -> General{closeurl}.',
    #                                         openurl => q{<a href='/Mail/Composite/General'>},
    #                                         closeurl => q{</a>}));
    #}
}

sub _daemonsToDisable
{
    my ($self) = @_;

    my $daemons = [
        {
            name => 'openchange-ocsmanager',
            type => 'init.d',
        }
    ];
    return $daemons;
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;

    my $daemons = [
        {
            name         => 'zentyal.ocsmanager',
            type         => 'upstart',
            precondition => sub { return $self->isProvisioned() },
        },
        {
            name => 'sogo',
            type => 'init.d',
        }
    ];

    return $daemons;
}

# Method: isRunning
#
#   Links Openchange running status to Samba status.
#
# Overrides: <EBox::Module::Service::isRunning>
#
sub isRunning
{
    my ($self) = @_;

    my $running = $self->SUPER::isRunning();

    if ($running) {
        my $usersMod = $self->global()->modInstance('samba');
        return $usersMod->isRunning();
    } else {
        return $running;
    }
}

sub usedFiles
{
    my @files = ();
    push (@files, {
        file => SOGO_DEFAULT_FILE,
        reason => __('To configure sogo daemon'),
        module => 'openchange'
    });
    push (@files, {
        file => SOGO_CONF_FILE,
        reason => __('To configure sogo parameters'),
        module => 'openchange'
    });
    push (@files, {
        file => OCSMANAGER_CONF_FILE,
        reason => __('To configure autodiscovery service'),
        module => 'openchange'
    });
    push (@files, {
        file => RPCPROXY_STOCK_CONF_FILE,
        reason => __('Remove RPC Proxy stock file to avoid interference'),
        module => 'openchange'
    });
    push (@files, {
        file => SOGO_APACHE_CONF,
        reason => __('To make SOGo webmail available'),
        module => 'sogo'
    });
    push (@files, {
        file => APACHE_OCSMANAGER_CONF,
        reason => __('To make autodiscovery service available'),
        module => 'sogo'
    });

    return \@files;
}

sub writeSambaConfig
{
    my ($self) = @_;

    my $openchangeProvisionedWithMySQL = $self->isProvisionedWithMySQL();
    my $openchangeNotificationsReady = $self->notificationsReady();
    my $openchangeConnectionString = undef;
    my $oc = [];
    if ($openchangeProvisionedWithMySQL) {
        $openchangeConnectionString = $self->connectionString();
        # format of connection string: "mysql://user:password@localhost/db_name
        my ($mysqlUser, $mysqlPass, $mysqlHost, $mysqlDb) =
            $openchangeConnectionString =~ /mysql:\/\/(\w+):(\w+)\@(\w+)\/(\w+)/;
        push (@{$oc}, 'openchangeNamedpropsMysqlUser' => $mysqlUser);
        push (@{$oc}, 'openchangeNamedpropsMysqlPass' => $mysqlPass);
        push (@{$oc}, 'openchangeNamedpropsMysqlHost' => $mysqlHost);
        push (@{$oc}, 'openchangeNamedpropsMysqlDb' => $mysqlDb);
    }
    push (@{$oc}, 'openchangeProvisionedWithMySQL' => $openchangeProvisionedWithMySQL);
    push (@{$oc}, 'openchangeConnectionString' => $openchangeConnectionString);
    push (@{$oc}, 'openchangeNotificationsReady' => $openchangeNotificationsReady);
    $self->writeConfFile(OPENCHANGE_CONF_FILE, 'samba/openchange.conf.mas', $oc,
                         { 'uid' => 'root', 'gid' => 'ebox', mode => '640' });
}

# Method: _setConf
#
# Overrides:
#
#       <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $state = $self->get_state();
    if ($state->{provision_from_wizard}) {
        my $orgName = $state->{provision_from_wizard}->{orgName};
        my $provisionModel = $self->model('Provision');
        $provisionModel->provision($orgName);
        delete $state->{provision_from_wizard};
        $self->set_state($state);
    }
    if ($state->{provision}) {
        my $params = delete $state->{provision};
        my $provisionModel = $self->model('Provision');
        $provisionModel->provision($params->{orgName}, undef, %{$params});
        $self->set_state($state);
    }

    $self->_writeSOGoDefaultFile();
    $self->_writeSOGoConfFile();
    $self->_setupSOGoDatabase();

    $self->_setApachePortsConf();

    $self->_setOCSManagerConf();

    $self->_writeCronFile();

    $self->_setupActiveSync();
}

# TODO: Review, is this really necessary?
sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled) {
        EBox::Sudo::root('service sogo restart');
        # FIXME: common way to restart apache for rpcproxy, sogo and
        #        activesync only if there are changes?
        #        currently we are doing more than necessary
        EBox::Sudo::root('service apache2 restart');
    }
}

sub _setApachePortsConf
{
    my ($self) = @_;

    my $params = [];
    push (@{$params}, bindAddress => '0.0.0.0');
    push (@{$params}, port        => APACHE_OCSMANAGER_PORT_HTTP);
    push (@{$params}, sslPort     => APACHE_OCSMANAGER_PORT_HTTPS);
    $self->writeConfFile(APACHE_PORTS_FILE,
                         'openchange/apache-ports.conf.mas',
                         $params);
}

sub _setupActiveSync
{
    my ($self) = @_;

    my $enabled = (-f '/etc/apache2/conf-enabled/zentyal-activesync.conf');
    my $enable = $self->model('ActiveSync')->value('activesync');
    if ($enabled xor $enable) {
        if ($enable) {
            EBox::Sudo::root('a2enconf zentyal-activesync');
        } else {
            EBox::Sudo::silentRoot('a2disconf zentyal-activesync');
        }
        my $global = $self->global();
        if ($global->modExists('sogo')) {
            $global->addModuleToPostSave('sogo');
        }
    }
}

sub _writeCronFile
{
    my ($self) = @_;

    my $cronfile = '/etc/cron.d/zentyal-openchange';
    if ($self->isEnabled()) {
        my $accountScript = EBox::Config::scripts($self->name()) . 'account';
        unless ($self->st_entry_exists('cron_rand_hour') and $self->st_entry_exists('cron_rand_min')) {
            $self->st_set_int('cron_rand_hour', int(rand(24)));
            $self->st_set_int('cron_rand_min', int(rand(60)));
        }
        my ($randHour, $randMin) = ($self->st_get_int('cron_rand_hour'), $self->st_get_int('cron_rand_min'));
        my $crontab = "$randMin $randHour * * * root $accountScript 2> /dev/null";
        # FIXME: this may cause unexpected samba restarts during save changes, etc
        # my $checkScript = '/usr/share/zentyal-openchange/check_oc.py';
        # $crontab .= "* * * * * root $checkScript || /sbin/restart samba-ad-dc";
        EBox::Sudo::root("echo '$crontab' > $cronfile");
    } else {
        EBox::Sudo::root("rm -f $cronfile");
    }
}

sub _writeSOGoDefaultFile
{
    my ($self) = @_;

    my $array = [];
    my $prefork = EBox::Config::configkey('sogod_prefork');
    unless (length $prefork) {
        $prefork = SOGO_DEFAULT_PREFORK;
    }
    push (@{$array}, prefork => $prefork);
    $self->writeConfFile(SOGO_DEFAULT_FILE,
        'openchange/sogo.mas',
        $array, { uid => 0, gid => 0, mode => '755' });
}

sub _writeSOGoConfFile
{
    my ($self) = @_;

    my $array = [];

    my $sysinfo = $self->global->modInstance('sysinfo');
    my $timezoneModel = $sysinfo->model('TimeZone');
    my $sogoTimeZone = $timezoneModel->row->printableValueByName('timezone');

    my $users = $self->global->modInstance('samba');
    my $dcHostName = $users->ldap()->rootDse->get_value('dnsHostName');
    my (undef, $sogoMailDomain) = split (/\./, $dcHostName, 2);

    push (@{$array}, sogoPort => SOGO_PORT);
    push (@{$array}, sogoLogFile => SOGO_LOG_FILE);
    push (@{$array}, sogoPidFile => SOGO_PID_FILE);
    push (@{$array}, sogoTimeZone => $sogoTimeZone);
    push (@{$array}, sogoMailDomain => $sogoMailDomain);

    my $mail = $self->global->modInstance('mail');
    my $retrievalServices = $mail->model('RetrievalServices');
    my $sieveEnabled = $retrievalServices->value('managesieve');
    my $sieveServer = ($sieveEnabled ? 'sieve://127.0.0.1:4190' : '');
    my $imapServer = '127.0.0.1:143';
    my $smtpServer = '127.0.0.1:25';
    push (@{$array}, imapServer => $imapServer);
    push (@{$array}, smtpServer => $smtpServer);
    push (@{$array}, sieveServer => $sieveServer);

    my $sogoDbEngine = $self->_sogoDBEngine();
    my $dbName = $sogoDbEngine->_dbname();
    my $dbUser = $sogoDbEngine->_dbuser();
    my $dbPass = $sogoDbEngine->_dbpass();
    push (@{$array}, dbName => $dbName);
    push (@{$array}, dbUser => $dbUser);
    push (@{$array}, dbPass => $dbPass);
    push (@{$array}, dbHost => '127.0.0.1');
    push (@{$array}, dbPort => 3306);

    my $baseDN = $self->ldap->dn();
    if (EBox::Config::boolean('openchange_disable_multiou')) {
        $baseDN = "ou=Users,$baseDN";
    }

    push (@{$array}, sambaBaseDN => $users->ldap()->dn());
    push (@{$array}, sambaBindDN => $self->_kerberosServiceAccountDN());
    push (@{$array}, sambaBindPwd => $self->_kerberosServiceAccountPassword());
    push (@{$array}, sambaHost => "ldap://127.0.0.1"); #FIXME? not working using $users->ldap()->url()

    my (undef, undef, undef, $gid) = getpwnam('sogo');
    $self->writeConfFile(SOGO_CONF_FILE,
        'openchange/sogo.conf.mas',
        $array, { uid => 0, gid => $gid, mode => '640' });
}

sub _setOCSManagerConf
{
    my ($self) = @_;

    my $global  = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $users   = $global->modInstance('samba');
    my $mail    = $global->modInstance('mail');
    my $adminMail = $mail->model('SMTPOptions')->value('postmasterAddress');
    my $hostname = $sysinfo->hostName();

    my $rpcProxyHttp = 0;
    my $rpcProxyHttps = 0;
    my $vdomains = $self->model('VDomains');
    foreach my $id (@{$vdomains->ids()}) {
        my $row = $vdomains->row($id);
        $rpcProxyHttp |= $row->valueByName('rpcproxy_http');
        $rpcProxyHttps |= $row->valueByName('rpcproxy_https');
    }

    my $confFileParams = [
        bindDn       => $self->_kerberosServiceAccountDN(),
        bindPwd      => $self->_kerberosServiceAccountPassword(),
        baseDn       => 'CN=Users,' . $users->ldap()->dn(),
        port         => 389,
        adminMail    => $adminMail,
        rpcProxy     => $rpcProxyHttp,
        rpcProxySSL  => $rpcProxyHttps,
        mailboxesDir => EBox::Mail::VDOMAINS_MAILBOXES_DIR(),
    ];
    if ($rpcProxyHttp or $rpcProxyHttps) {
        my $network = $global->modInstance('network');
        push (@{$confFileParams}, intNetworks => $network->internalNetworks());
    }
    $self->writeConfFile(OCSMANAGER_CONF_FILE,
                         'openchange/ocsmanager.ini.mas',
                         $confFileParams,
                         { uid => 0, gid => 0, mode => '640' });

    my @cmds;
    my $user = 'www-data';
    my $group = 'www-data';
    push (@cmds, 'rm -rf ' . RPCPROXY_STOCK_CONF_FILE);
    push (@cmds, 'mkdir -p ' . RPCPROXY_AUTH_CACHE_DIR);
    push (@cmds, "chown -R $user:$group " . RPCPROXY_AUTH_CACHE_DIR);
    push (@cmds, 'chmod 0750 ' . RPCPROXY_AUTH_CACHE_DIR);
    push (@cmds, 'a2disconf *zentyal-ocsmanager-* || true');
    push (@cmds, 'rm -f /etc/apache2/conf-available/*zentyal-ocsmanager-*');
    EBox::Sudo::root(@cmds);

    if ($self->isEnabled() && $self->isProvisioned()) {
        my $fid = 100;
        my $model = $self->model('VDomains');
        foreach my $id (@{$model->ids()}) {
            my $row = $model->row($id);
            my $domain = $row->printableValueByName('vdomain');
            my $autodiscover = $row->valueByName('autodiscoverRecord');
            my $rpcProxyHttp = $row->valueByName('rpcproxy_http');
            my $rpcProxyHttps = $row->valueByName('rpcproxy_https');
            my $webmailHttp = $row->valueByName('webmail_http');
            my $webmailHttps = $row->valueByName('webmail_https');
            my $certificate = $self->_setCert($domain);

            if ($webmailHttp or $rpcProxyHttp) {
                my $params = [];
                push (@{$params}, user => $user);
                push (@{$params}, group => $group);
                push (@{$params}, port => APACHE_OCSMANAGER_PORT_HTTP);
                push (@{$params}, ssl => 0);
                push (@{$params}, hostname => $hostname);
                push (@{$params}, domain => $domain);
                push (@{$params}, autodiscover => 0);
                push (@{$params}, ews => 0);
                push (@{$params}, rpcproxy => $rpcProxyHttp);
                push (@{$params}, rpcproxyAuthCacheDir => RPCPROXY_AUTH_CACHE_DIR);
                push (@{$params}, webmail => $webmailHttp);
                push (@{$params}, debug => EBox::Config::boolean('debug'));

                my $conf = "${fid}-zentyal-ocsmanager-${domain}";
                my $file = "/etc/apache2/conf-available/$conf.conf";
                $self->writeConfFile($file,
                                     "openchange/apache-ocsmanager.conf.mas",
                                     $params,
                                     { uid => 0, gid => 0, mode => '644' });
                try {
                    EBox::Sudo::root("a2enconf $conf");
                } catch (EBox::Exceptions::Sudo::Command $e) {
                    # Already enabled?
                    if ($e->exitValue() != 1) {
                        $e->throw();
                    }
                }
            }

            if (EBox::Sudo::fileTest('-f', $certificate)) {
                my $sslParams = [];
                push (@{$sslParams}, user => $user);
                push (@{$sslParams}, group => $group);
                push (@{$sslParams}, port => APACHE_OCSMANAGER_PORT_HTTPS);
                push (@{$sslParams}, ssl => 1);
                push (@{$sslParams}, hostname => $hostname);
                push (@{$sslParams}, domain => $domain);
                push (@{$sslParams}, autodiscover => 1);
                push (@{$sslParams}, ews => 1);
                push (@{$sslParams}, rpcproxy => $rpcProxyHttps);
                push (@{$sslParams}, rpcproxyAuthCacheDir =>
                    RPCPROXY_AUTH_CACHE_DIR);
                push (@{$sslParams}, webmail => $webmailHttps);
                push (@{$sslParams}, certificate => $certificate);

                my $conf = "${fid}-zentyal-ocsmanager-${domain}-ssl";
                my $file = "/etc/apache2/conf-available/$conf.conf";

                $self->writeConfFile($file,
                                     "openchange/apache-ocsmanager.conf.mas",
                                     $sslParams,
                                     { uid => 0, gid => 0, mode => '644' });
                try {
                    EBox::Sudo::root("a2enconf $conf");
                } catch (EBox::Exceptions::Sudo::Command $e) {
                    # Already enabled?
                    if ($e->exitValue() != 1) {
                        $e->throw();
                    }
                }
            }

            $fid++;
        }
    }
}

# Method: _setCert
#
#   Check if the certificate has been issued for the domain and retrieve the
#   metadata. If the certificate is issued, builds the PEM necessary for
#   apache.
#
# Returns:
#
#   The path of the certificate used by apache
#
sub _setCert
{
    my ($self, $domain) = @_;

    my $ca = $self->global()->modInstance('ca');
    if (not $ca->isAvailable()) {
        EBox::error("Failed to configure EWS: CA is not available");
        return undef;
    }

    my $certPath;
    my $model = $self->model('VDomains');
    my $metadata =  $model->certificate($domain);
    if (defined $metadata) {
        EBox::debug("Certificate for $domain in place");
        my $path = "/etc/ocsmanager/${domain}.pem";
        if ($metadata->{state} eq 'V') {
            my $domaincrt = $metadata->{path};
            my $domainkey = $ca->getKeys($domain)->{privateKey};
            my $cmd = "cat '$domaincrt' '$domainkey' > '$path'";
            EBox::Sudo::root($cmd);
            $certPath = $path;
        } else {
            EBox::warn("Certificate for domain '$domain' is not valid");
            EBox::Sudo::root("rm -f '$path'");
        }
    } else {
        EBox::warn("No certificate for domain '$domain'");
    }

    return $certPath;
}

# Method: menu
#
#   Add an entry to the menu with this module.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
        'name' => 'Mail',
        'icon' => 'mail',
        'text' => __('Mail'),
        'tag' => 'main',
        'order' => 4
    );

    $folder->add(new EBox::Menu::Item(
        url => 'Mail/OpenChange',
        text => $self->printableName(),
        order => 3)
    );

    $root->add($folder);
}

sub _ldapModImplementation
{
    return new EBox::OpenChange::LdapUser();
}

# Method: isProvisioned
#
#     Return true if the OpenChange is provisioned in Samba + DBs.
#
#     It is independent from saving changes state
#
# Returns:
#
#     Boolean
#
sub isProvisioned
{
    my ($self) = @_;

    my $state = $self->get_state();
    my $provisioned = $state->{isProvisioned};
    if (defined $provisioned and $provisioned) {
        return 1;
    }
    return 0;
}

# Method: setProvisioned
#
#     Set the OpenChange whether OpenChange is provisioned in Samba +
#     DBs.
#
#     It is independent from saving changes state.
#
# Parameters:
#
#     provisioned - Boolean to set the provisioned state
#
sub setProvisioned
{
    my ($self, $provisioned) = @_;

    my $state = $self->get_state();
    $state->{isProvisioned} = $provisioned;
    $self->set_state($state);
}

# Method: users
#
#     Return the users that has used OpenChange at least once, that
#     is, the MAPI users
#
# Returns:
#
#     Array ref - empty array if not provisioned, an array with
#     usernames otherwise
#
sub users
{
    my ($self) = @_;

    if (not $self->isProvisioned()) {
        return 0;
    }

    my $dbEngine = new EBox::OpenChange::DBEngine($self);
    $dbEngine->connect();

    my @users;
    my $ret =  $dbEngine->query_hash({'select' => 'name', 'from' => 'mailboxes'});
    if ($ret) {
        @users = map { $_->{'name'} } @{$ret};
    }
    return \@users;
}

sub _mysqlDumpFile
{
    my ($self, $dir) = @_;
    return $dir . '/openchange.dump';
}

sub _sogoDumpFile
{
    my ($self, $dir) = @_;
    return $dir . '/sogo.dump';
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    if (not $self->isProvisioned()) {
        # if not provisioned, there is no db to dump
        return;
    }

    # backup openchange database
    my $dumpFile = $self->_mysqlDumpFile($dir);
    my $dbengine = EBox::OpenChange::DBEngine->new($self);
    $dbengine->dumpDB($dumpFile);

    # backup now sogo database
    $dumpFile = $self->_sogoDumpFile($dir);
    $dbengine = $self->_sogoDBEngine();
    $dbengine->dumpDB($dumpFile);
}

sub restoreConfig
{
    my ($self, $dir, @params) = @_;

    $self->stopService();

    $self->SUPER::restoreConfig($dir, @params);

    # import from state only the provision keys
    my $state = $self->get_state();
    $self->_load_state_from_file($dir);
    my $stateFromBackup = $self->get_state();
    $state->{isProvisioned} = $stateFromBackup->{isProvisioned};
    $state->{Provision}     = $stateFromBackup->{Provision};
    $self->set_state($state);

    if ($self->isProvisioned()) {
        # recreate db
        EBox::Sudo::root(EBox::Config::scripts('openchange') .
              'generate-database');

        # load openchange database data
        my $dumpFile = $self->_mysqlDumpFile($dir);
        if (-r $dumpFile) {
            my $dbengine = EBox::OpenChange::DBEngine->new($self);
            $dbengine->restoreDBDump($dumpFile);
        }

        # load sogo database data
        $dumpFile = $self->_sogoDumpFile($dir);
        if (-r $dumpFile) {
            my $dbengine = $self->_sogoDBEngine();
            $dbengine->restoreDBDump($dumpFile);
        }
    }

    $self->_startService();
}

sub _setupSOGoDatabase
{
    my ($self) = @_;

    my $sogoDB = $self->_sogoDBEngine();
    my $dbUser = $sogoDB->_dbuser();
    my $dbPass = $sogoDB->_dbpass();
    my $dbName = $sogoDB->_dbname();
    my $dbHost = '127.0.0.1';

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->updateMysqlConf();
    $db->sqlAsSuperuser(sql => "CREATE DATABASE IF NOT EXISTS $dbName");
    $db->sqlAsSuperuser(sql => "GRANT ALL ON $dbName.* TO $dbUser\@$dbHost " .
                               "IDENTIFIED BY \"$dbPass\";");
    $db->sqlAsSuperuser(sql => 'flush privileges;');
}

sub _sogoDBEngine
{
    my ($self) = @_;
    if (not $self->{'_sogoDBengine'}) {
        $self->{'_sogoDBengine'} = EBox::OpenChange::SOGO::DBEngine->new();
    }

    return $self->{'_sogoDBengine'};
}

# Method: configurationContainer
#
#   Return the ExchConfigurationContainer object that models the
#   msExchConfigurationConainer entry for this installation.
#
# Returns:
#
#   EBox::OpenChange::ExchConfigurationContainer object.
#
sub configurationContainer
{
    my ($self) = @_;

    my $usersMod = $self->global->modInstance('samba');
    unless ($usersMod->isEnabled() and $usersMod->isProvisioned()) {
        return undef;
    }
    my $defaultNC = $usersMod->ldap()->dn();
    my $dn = "CN=Microsoft Exchange,CN=Services,CN=Configuration,$defaultNC";

    my $object = new EBox::OpenChange::ExchConfigurationContainer(dn => $dn);
    if ($object->exists) {
        return $object;
    } else {
        return undef;
    }
}

# Method: organizations
#
#   Return a list of ExchOrganizationContainer objects that belong to this
#   installation.
#
# Returns:
#
#   An array reference of ExchOrganizationContainer objects.
#
sub organizations
{
    my ($self) = @_;

    my $list = [];
    my $usersMod = $self->global->modInstance('samba');
    my $configurationContainer = $self->configurationContainer();

    return $list unless ($configurationContainer);

    my $params = {
        base => $configurationContainer->dn(),
        scope => 'one',
        filter => '(objectclass=msExchOrganizationContainer)',
        attrs => ['*'],
    };
    my $result = $usersMod->ldap()->search($params);
    foreach my $entry ($result->sorted('cn')) {
        my $organization =
            new EBox::OpenChange::ExchOrganizationContainer(entry => $entry);
        push (@{$list}, $organization);
    }

    return $list;
}

# Method: _getPassword
#
#   Read a password file (one line, contents chomped) as root
#
sub _getPassword
{
    my ($self, $path, $target) = @_;

    try {
        my ($pwd) = @{EBox::Sudo::root("cat \"$path\"")};
        $pwd =~ s/[\n\r]//g;
        return $pwd;
    } catch($ex) {
        EBox::error("Error trying to read $path '$ex'");
        throw EBox::Exceptions::Internal(
            "Could not open $path to get $target password.");
    };
}

# Method: getImapMasterPassword
#
#   We can login as any user on imap server with this, the first time
#   this method is called a new password will be generated and put it
#   on a file inside samba private directory (SOGo will look for this
#   password there)
#
# Returns:
#
#   Password to use as master password for imap server. We can login
#   as any user with this.
#
sub getImapMasterPassword
{
    my ($self) = @_;

    unless (EBox::Sudo::fileTest('-e', OPENCHANGE_IMAP_PASSWD_FILE)) {
        # Generate password file
        EBox::debug("Generating imap master password file");
        my $parentDir = dirname(OPENCHANGE_IMAP_PASSWD_FILE);
        EBox::Sudo::root("mkdir -p -m700 '$parentDir'");
        my $generator = new String::Random();
        my $pass = $generator->randregex('\w\w\w\w\w\w\w\w');
        EBox::Module::Base::writeFile(OPENCHANGE_IMAP_PASSWD_FILE,
            "$pass", { mode => '0640', uid => 'root', gid => 'ebox' });
    }

    return $self->_getPassword(OPENCHANGE_IMAP_PASSWD_FILE, "Imap master");
}

# Method: isProvisionedWithMySQL
#
#   Since Zentyal 3.4 MySQL backends are the default ones but on previous
#   versions they didn't exist.
#
# Returns:
#
#   Whether OpenChange module has been provisioned using MySQL backends or not.
#
sub isProvisionedWithMySQL
{
    my ($self) = @_;

    return ($self->isProvisioned() and (-e OPENCHANGE_MYSQL_PASSWD_FILE));
}

# Method: connectionString
#
#   Get a connection string to be used for the different configurable backends of
#   OpenChange: named properties, openchangedb and indexing.
#
#   Currently MySQL is used as backend, the first time this method is called an
#   openchange user will be created
#
# Returns:
#
#   string with the following format schema://user:password@host/table, schema will
#   be, normally, mysql (because is the only one supported right now)
#
sub connectionString
{
    my ($self) = @_;

    unless (-e OPENCHANGE_MYSQL_PASSWD_FILE) {
        EBox::Sudo::root(EBox::Config::scripts('openchange') .
                'generate-database');
    }

    my $pwd = $self->_getPassword(OPENCHANGE_MYSQL_PASSWD_FILE, "Openchange MySQL");

    return "mysql://openchange:$pwd\@localhost/openchange";
}

# Method: certificateIsReserved
#
# returns whether the certificate is reserved for use by openchange. Reserved
# certifcates must be issued only by openchange because they need
# special fields (dns alt names, ..)
#
# Parameters:
#   cn - certificate common name
sub certificateIsReserved
{
    my ($self, $cn) = @_;
    my $vdomains = $self->model('VDomains');
    my $managed = defined $vdomains->find(vdomain => $cn);
    return $managed;
}

# Method: notificationsReady
#
# Returns: If the notifications are ready
#
sub notificationsReady
{
    my ($self) = @_;

    return (-e OPENCHANGE_DOVECOT_PLUGIN_FILE);
}

# EBox::CA::Observer methods
sub certificateRevoked
{
    my ($self, $commonName, $isCACert) = @_;

    if ($self->isProvisioned()) {
        if ($isCACert) {
            return 1;
        }
        my $model = $self->model('VDomains');
        foreach my $id (@{$model->ids()}) {
            my $row = $model->row($id);
            my $vdomain = $row->printableValueByName('vdomain');
            if (lc ($vdomain) eq lc ($commonName)) {
                return $model->certificate($commonName) ? 1 : 0;
            }
        }
    }
    return 0;
}

sub certificateRevokeDone
{
    my ($self, $commonName, $isCACert) = @_;

    return unless $self->isProvisioned();

    my $model = $self->model('VDomains');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $vdomain = $row->printableValueByName('vdomain');
        if (lc ($vdomain) eq lc ($commonName)) {
            $row->elementByName('webmail_https')->setValue(0);
            $row->elementByName('rpcproxy_https')->setValue(0);
            $row->store();
        }
    }
}

sub certificateRenewed
{
    my ($self, $commonName, $isCACert) = @_;
    $self->_certificateChanges($commonName, $isCACert);
}

sub freeCertificate
{
    my ($self, $commonName) = @_;
    $self->_certificateChanges($commonName);
}

sub _certificateChanges
{
    my ($self, $commonName, $isCACert) = @_;

    my $removeAll = 0;
    if ($isCACert) {
        $removeAll = 1;
    }

    # Remove all certificates used by OCS manager and set module as changed
    # to regenerate them
    my $model = $self->model('VDomains');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $vdomain = $row->printableValueByName('vdomain');
        if ((lc ($commonName) eq lc ($vdomain)) or $removeAll) {
            $self->setAsChanged(1);
            EBox::Sudo::root("rm -f '/etc/ocsmanager/${vdomain}.pem'");
        }
    }
}

sub _kerberosServicePrincipals
{
    return undef;
}

sub _kerberosKeytab
{
    return undef;
}

# Method: cleanForReprovision
#
# Overriden to remove also status of openchange provision and configuration
# related with mail virtual domains, because they can change after reprovision
sub cleanForReprovision
{
    my ($self) = @_;

    my $state = $self->get_state();
    delete $state->{'_schemasAdded'};
    delete $state->{'_ldapSetup'};
    delete $state->{'Provision'};
    delete $state->{'isProvisioned'};
    $self->set_state($state);

    $self->dropSOGODB();

    my @modelsToClean = qw(Provision RPCProxy Configuration);
    foreach my $name (@modelsToClean) {
        $self->model($name)->removeAll(1);
    }

    # remove rpcproxy certificates
    my $model = $self->model('VDomains');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $vdomain = $row->printableValueByName('vdomain');
        EBox::Sudo::root("rm -f '/etc/ocsmanager/${vdomain}.pem");
    }

    $self->setAsChanged(1);
}

sub dropSOGODB
{
    my ($self) = @_;

    if ($self->isProvisionedWithMySQL()) {
        # It removes the file with mysql password and the user from mysql
        EBox::Sudo::root(EBox::Config::scripts('openchange') .
              'remove-database');
    }

    # Drop SOGo database and db user. To avoid error if it does not exists,
    # the user is created and granted harmless privileges before drop it
    my $sogoDB = $self->_sogoDBEngine();
    my $dbName = $sogoDB->_dbname();
    my $dbUser = $sogoDB->_dbuser();

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->sqlAsSuperuser(sql => "DROP DATABASE IF EXISTS $dbName");
    $db->sqlAsSuperuser(sql => "GRANT USAGE ON *.* TO $dbUser");
    $db->sqlAsSuperuser(sql => "DROP USER $dbUser");
}

sub wizardPages
{
    my ($self) = @_;

    return [{ page => '/OpenChange/Wizard/Provision', order => 410 }];
}

1;
