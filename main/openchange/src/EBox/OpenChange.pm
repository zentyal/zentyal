# Copyright (C) 2013 Zentyal S.L.
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

use base qw(EBox::Module::Service EBox::LdapModule
            EBox::HAProxy::ServiceBase EBox::VDomainModule);

use EBox::Config;
use EBox::DBEngineFactory;
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
use EBox::Sudo;
use EBox::Util::Certificate;

use TryCatch::Lite;
use String::Random;
use File::Basename;

use constant SOGO_PORT => 20000;
use constant SOGO_DEFAULT_PREFORK => 1;

use constant SOGO_DEFAULT_FILE => '/etc/default/sogo';
use constant SOGO_CONF_FILE => '/etc/sogo/sogo.conf';
use constant SOGO_PID_FILE => '/var/run/sogo/sogo.pid';
use constant SOGO_LOG_FILE => '/var/log/sogo/sogo.log';

use constant OCSMANAGER_CONF_FILE => '/etc/ocsmanager/ocsmanager.ini';
use constant OCSMANAGER_INC_FILE  => '/var/lib/zentyal/conf/openchange/ocsmanager.conf';

use constant RPCPROXY_AUTH_CACHE_DIR => '/var/cache/ntlmauthhandler';
use constant RPCPROXY_PORT           => 62081;
use constant RPCPROXY_STOCK_CONF_FILE => '/etc/apache2/conf.d/rpcproxy.conf';
use constant REWRITE_POLICY_FILE => '/etc/postfix/generic';

use constant OPENCHANGE_MYSQL_PASSWD_FILE => EBox::Config->conf . '/openchange/mysql.passwd';

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

    #FIXME: is this deprecated (in 3.4)? needs to be done always? better to include a version check
    $self->_migrateFormKeys();

    if (defined($version)
            and (EBox::Util::Version::compare($version, '3.3.3') < 0)) {
        $self->_migrateOutgoingDomain();
    }

    if ($self->changed()) {
        $self->saveConfigRecursive();
    }
}

# Migration of form keys after extracting the rewrite rule for outgoing domain
# from the provision form.
#
sub _migrateOutgoingDomain
{
  my ($self) = @_;

  my $oldKeyValue = $self->get('Provision/keys/form');
  $self->set('Configuration/keys/form', $oldKeyValue);
}

# Migration of form keys to better names (between development versions)
#
# * Migrate redis keys from firstorganization to organizationname and firstorganizationunit to administrativegroup
#
sub _migrateFormKeys
{
    my ($self) = @_;
    my $modelName = 'Provision';
    my @keys = ("openchange/conf/$modelName/keys/form", "openchange/ro/$modelName/keys/form");

    my $state = $self->get_state();
    my $keyField = 'organizationname';
    my $redis = $self->redis();
    foreach my $key (@keys) {
        my $value = $redis->get($key);
        if (defined $value->{firstorganization}) {
            $state->{$modelName}->{$keyField} = $value->{firstorganization};
            delete $value->{firstorganization};
        }
        if (defined $value->{organizationname}) {
            $state->{$modelName}->{$keyField} = $value->{organizationname};
            delete $value->{organizationname};
        }
        if (defined $value->{firstorganizationunit}) {
            delete $value->{firstorganizationunit};
        }
        if (defined $value->{administrativegroup}) {
            delete $value->{administrativegroup};
        }
        $redis->set($key, $value);
    }
    if ($self->isProvisioned()) {
        # The organization name is only useful if the server is already provisioned.
        $self->set_state($state);
    }
}

# Method: enableActions
#
# Action to do when openchange module is enabled for first time
#
sub enableActions
{
    my ($self) = @_;
    $self->SUPER::enableActions();
    $self->_setupDNS();
}

# Method: enableService
#
#   Override EBox::Module::Service::enableService to notify samba
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    if ($self->changed()) {
        my $global = $self->global();
        # Mark mail as changed to make dovecot listen IMAP protocol at least
        # on localhost
        my $mail = $global->modInstance('mail');
        $mail->setAsChanged();


        if ($self->_rpcProxyEnabled() and  $global->modExists('webserver')) {
            my $webserverMod = $global->modInstance("webserver");
            # Mark webserver as changed to load the configuration of rpcproxy
            $webserverMod->setAsChanged() if $webserverMod->isEnabled();
        }

        # Mark samba as changed to write smb.conf
        my $samba = $global->modInstance('samba');
        $samba->setAsChanged();

        # Mark webadmin as changed so we are sure nginx configuration is
        # refreshed with the new includes
        $global->modInstance('webadmin')->setAsChanged();
    }
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
            precondition => sub { return $self->_autodiscoverEnabled() },
        },
        {
            name         => 'zentyal.zoc-migrate',
            type         => 'upstart',
            precondition => sub { return $self->isProvisioned() },
        },
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
        my $sambaMod = $self->global()->modInstance('samba');
        return $sambaMod->isRunning();
    } else {
        return $running;
    }
}

sub _autodiscoverEnabled
{
    my ($self) = @_;
    return $self->isProvisioned();
}

sub _rpcProxyEnabled
{
    my ($self) = @_;
    if (not $self->isProvisioned() or not $self->isEnabled()) {
        return 0;
    }

    my $rpcpSettings = $self->model('RPCProxy');
    return $rpcpSettings->enabled();
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

    return \@files;
}

sub _setConf
{
    my ($self) = @_;

    $self->_writeSOGoDefaultFile();
    $self->_writeSOGoConfFile();
    $self->_setupSOGoDatabase();
    $self->_setAutodiscoverConf();
    $self->_setRPCProxyConf();
    $self->_clearDownloadableCert();
    $self->_writeRewritePolicy();
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

    my $samba = $self->global->modInstance('samba');
    my $dcHostName = $samba->ldb->rootDse->get_value('dnsHostName');
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

    my $dbName = $self->_sogoDbName();
    my $dbUser = $self->_sogoDbUser();
    my $dbPass = $self->_sogoDbPass();
    push (@{$array}, dbName => $dbName);
    push (@{$array}, dbUser => $dbUser);
    push (@{$array}, dbPass => $dbPass);
    push (@{$array}, dbHost => '127.0.0.1');
    push (@{$array}, dbPort => 3306);

    my $baseDN = $self->ldap->dn();
    if (EBox::Config::boolean('openchange_disable_multiou')) {
        $baseDN = "ou=Users,$baseDN";
    }

    push (@{$array}, ldapBaseDN => $baseDN);
    push (@{$array}, ldapBindDN => $self->ldap->roRootDn());
    push (@{$array}, ldapBindPwd => $self->ldap->getRoPassword());
    push (@{$array}, ldapHost => $self->ldap->LDAPI());

    my (undef, undef, undef, $gid) = getpwnam('sogo');
    $self->writeConfFile(SOGO_CONF_FILE,
        'openchange/sogo.conf.mas',
        $array, { uid => 0, gid => $gid, mode => '640' });
}

sub _setAutodiscoverConf
{
    my ($self) = @_;
    my $global  = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $samba   = $global->modInstance('samba');
    my $mail    = $global->modInstance('mail');

    my $server    = $sysinfo->hostDomain();
    my $adminMail = $mail->model('SMTPOptions')->value('postmasterAddress');
    if ($adminMail eq 'postmasterRoot') {
        $adminMail = 'postmaster@' . $server;
    }
    my $confFileParams = [
        bindDn    => 'cn=Administrator',
        bindPwd   => $samba->administratorPassword(),
        baseDn    => 'CN=Users,' . $samba->ldb()->dn(),
        port      => 389,
        adminMail => $adminMail,
    ];

    $self->writeConfFile(OCSMANAGER_CONF_FILE,
                         'openchange/ocsmanager.ini.mas',
                         $confFileParams,
                         { uid => 0, gid => 0, mode => '640' }
                        );

    # manage the nginx include file
    my $webadmin = $global->modInstance('webadmin');
    if ($self->isEnabled()) {
        my $confDir = EBox::Config::conf() . 'openchange';
        EBox::Sudo::root("mkdir -p '$confDir'");
        my $incParams = [
            server => $server
           ];
        $self->writeConfFile(OCSMANAGER_INC_FILE,
                             "openchange/ocsmanager.nginx.mas",
                             $incParams,
                             { uid => 0, gid => 0, mode => '644' }
                        );
        $webadmin->addNginxInclude(OCSMANAGER_INC_FILE);
    } else {
        $webadmin->removeNginxInclude(OCSMANAGER_INC_FILE);
    }
}

sub internalVHosts
{
    my ($self) = @_;
    if ($self->_rpcProxyEnabled) {
        return [ $self->_rpcProxyConfFile() ];
    }

    return [];
}

sub _rpcProxyConfFile
{
    my ($self) = @_;
    return EBox::WebServer::SITES_AVAILABLE_DIR() .'zentyaloc-rpcproxy.conf';
}

sub _setRPCProxyConf
{
    my ($self) = @_;

    # remove stock rpcproxy.conf file because it could interfere
    EBox::Sudo::root('rm -rf ' . RPCPROXY_STOCK_CONF_FILE);

    if ($self->_rpcProxyEnabled()) {
        my $rpcProxyConfFile = $self->_rpcProxyConfFile();
        my @params = (
            rpcproxyAuthCacheDir => RPCPROXY_AUTH_CACHE_DIR,
            port   => RPCPROXY_PORT
           );

        $self->writeConfFile(
            $rpcProxyConfFile, 'openchange/apache-rpcproxy.conf.mas',
             \@params);

        my @cmds;
        push (@cmds, 'mkdir -p ' . RPCPROXY_AUTH_CACHE_DIR);
        push (@cmds, 'chown -R www-data:www-data ' . RPCPROXY_AUTH_CACHE_DIR);
        push (@cmds, 'chmod 0750 ' . RPCPROXY_AUTH_CACHE_DIR);
        EBox::Sudo::root(@cmds);
    }
}

sub _rpcProxyCertificate
{
    return EBox::Config::conf() . 'openchange/ssl/ssl.pem';
}

sub _createRPCProxyCertificate
{
    my ($self) = @_;
    my $issuer;
    try {
        $issuer = $self->_rpcProxyHosts()->[0];
    } catch($ex) {
        EBox::error("Error when getting host name for RPC proxy: $ex. \nCertificates for this service will be left untouched");
    };
    if (not $issuer) {
        EBox::error("Not found issuer. Certifcate for RPC proxy will left untouched");
        return;
    }

    my $certPath = $self->_rpcProxyCertificate();
    if (EBox::Sudo::fileTest('-r', $certPath) and ($issuer eq EBox::Util::Certificate::getCertIssuer($certPath))) {
        # correct, nothing to do besides updating download version
        $self->_updateDownloadableCert();
        return undef;
    }

    my $certDir = dirname($certPath);
    my $parentCertDir = dirname($certDir);
    EBox::Sudo::root("rm -rf '$certDir'",
                     # create parent dir if it does not exists
                     "mkdir -p -m770 '$parentCertDir'",
                    );
    if ($issuer eq $self->global()->modInstance('sysinfo')->fqdn()) {
        my $webadminCert = $self->global()->modInstance('webadmin')->pathHTTPSSSLCertificate();
        if ($issuer eq EBox::Util::Certificate::getCertIssuer($webadminCert)) {
            # reuse webadmin certificate if issuer == fqdn
            my $webadminCertDir = dirname($webadminCert);
            EBox::Sudo::root("cp -r $webadminCertDir $certDir");
            $self->_updateDownloadableCert();
            return;
        }
    }

    # create certificate
    my $RSA_LENGTH = 1024;
    my ($keyFile, $keyUpdated)  = EBox::Util::Certificate::generateRSAKey($certDir, $RSA_LENGTH);
    my $certFile = EBox::Util::Certificate::generateCert($certDir, $keyFile, $keyUpdated, $issuer);
    my $pemFile = EBox::Util::Certificate::generatePem($certDir, $certFile, $keyFile, $keyUpdated);
    $self->_updateDownloadableCert();
}

sub _updateDownloadableCert
{
    my ($self) = @_;
    my $certPath = $self->_rpcProxyCertificate();
    $certPath =~ s/pem$/cert/;
    my $downloadPath = EBox::Config::downloads() . 'rpcproxy.crt';
    EBox::Sudo::root("cp '$certPath' '$downloadPath'",
                     "chown ebox.ebox '$downloadPath'"
                    );
}

sub _clearDownloadableCert
{
    my ($self) = @_;
    my $downloadPath = EBox::Config::downloads() . 'rpcproxy.crt';
    EBox::Sudo::root("rm -f $downloadPath");
}
sub _writeRewritePolicy
{
    my ($self) = @_;

    if ($self->isProvisioned()) {
        my $sysinfo = $self->global()->modInstance('sysinfo');
        my $defaultDomain = $sysinfo->hostDomain();

        my $rewriteDomain = $self->model('Configuration')->row()->printableValueByName('outgoingDomain');

        my @rewriteParams;
        push @rewriteParams, ('defaultDomain' => $defaultDomain);
        push @rewriteParams, ('rewriteDomain' => $rewriteDomain);

        $self->writeConfFile(REWRITE_POLICY_FILE,
            'openchange/rewriteDomainPolicy.mas',
            \@rewriteParams, { uid => 0, gid => 0, mode => '644' });

        EBox::Sudo::root('/usr/sbin/postmap ' . REWRITE_POLICY_FILE);
    }
}

# Method: menu
#
#   Add an entry to the menu with this module.
#
sub menu
{
    my ($self, $root) = @_;

    my $separator = 'Communications';
    my $order = 900;

    my $folder = new EBox::Menu::Folder(
        name => 'OpenChange',
        icon => 'openchange',
        text => $self->printableName(),
        separator => $separator,
        order => $order);

    $folder->add(new EBox::Menu::Item(
        url       => 'OpenChange/Composite/General',
        text      => __('Setup'),
        order     => 0));

    if ($self->isProvisioned()) {
        $folder->add(new EBox::Menu::Item(
            url       => 'OpenChange/Migration/Connect',
            text      => __('MailBox Migration'),
            order     => 1));
    }

    $root->add($folder);
}

sub _ldapModImplementation
{
    return new EBox::OpenChange::LdapUser();
}

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

sub setProvisioned
{
    my ($self, $provisioned) = @_;

    my $state = $self->get_state();
    $state->{isProvisioned} = $provisioned;
    $self->set_state($state);
}

sub _setupSOGoDatabase
{
    my ($self) = @_;

    my $dbUser = $self->_sogoDbUser();
    my $dbPass = $self->_sogoDbPass();
    my $dbName = $self->_sogoDbName();
    my $dbHost = '127.0.0.1';

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->enableInnoDBIfNeeded();
    $db->sqlAsSuperuser(sql => "CREATE DATABASE IF NOT EXISTS $dbName");
    $db->sqlAsSuperuser(sql => "GRANT ALL ON $dbName.* TO $dbUser\@$dbHost " .
                               "IDENTIFIED BY \"$dbPass\";");
    $db->sqlAsSuperuser(sql => 'flush privileges;');
}

sub _sogoDbName
{
    my ($self) = @_;

    return 'sogo';
}

sub _sogoDbUser
{
    my ($self) = @_;

    my $dbUser = EBox::Config::configkey('sogo_dbuser');
    return (length $dbUser > 0 ? $dbUser : 'sogo');
}

sub _sogoDbPass
{
    my ($self) = @_;

    # Return value if cached
    if (defined $self->{sogo_db_password}) {
        return $self->{sogo_db_password};
    }

    # Cache and return value if user configured
    my $dbPass = EBox::Config::configkey('sogo_dbpass');
    if (length $dbPass) {
        $self->{sogo_db_password} = $dbPass;
        return $dbPass;
    }

    # Otherwise, read from file
    my $path = EBox::Config::conf() . "sogo_db.passwd";

    # If file does not exists, generate random password and stash to file
    if (not -f $path) {
        my $generator = new String::Random();
        my $pass = $generator->randregex('\w\w\w\w\w\w\w\w');

        my ($login, $password, $uid, $gid) = getpwnam(EBox::Config::user());
        EBox::Module::Base::writeFile($path, $pass,
            { mode => '0600', uid => $uid, gid => $gid });
        $self->{sogo_db_password} = $pass;
        return $pass;
    }

    unless (defined ($self->{sogo_db_password})) {
        open (PASSWD, $path) or
            throw EBox::Exceptions::External('Could not get SOGo DB password');
        my $pwd = <PASSWD>;
        close (PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{sogo_db_password} = $pwd;
    }

    return $self->{sogo_db_password};
}

# setup the dns to add autodiscover host
sub _setupDNS
{
    my ($self) = @_;
    my $sysinfo    = $self->global()->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $hostName   = $sysinfo->hostName();
    my $autodiscoverAlias = 'autodiscover';
    if ("$autodiscoverAlias.$hostName"  eq $hostDomain) {
        # strangely the hostname is already the autodiscover name
        return;
    }

    my $dns = $self->global()->modInstance('dns');

    my $domainRow = $dns->model('DomainTable')->find(domain => $hostDomain);
    if (not $domainRow) {
        throw EBox::Exceptions::External(
            __x("The expected domain '{d}' could not be found in the dns module",
                d => $hostDomain
               )
           );
    }

    my $hostRow = $domainRow->subModel('hostnames')->find(hostname => $hostName);
    if (not $hostRow) {
        throw EBox::Exceptions::External(
          __x("The required host record '{h}' could not be found in " .
              "the domain '{d}'.<br/>",
              h => $hostName,
              d => $hostDomain
             )
         );
    }

    my $aliasModel = $hostRow->subModel('alias');
    if ($aliasModel->find(alias => $autodiscoverAlias)) {
        # already added, nothing to do
        return;
    }
    # add the autodiscover alias
    $aliasModel->addRow(alias => $autodiscoverAlias);
}


# Method: configurationContainer
#
#   Return the ExchConfigurationContainer object that models the msExchConfigurationConainer entry for this
#   installation.
#
# Returns:
#
#   EBox::OpenChange::ExchConfigurationContainer object.
#
sub configurationContainer
{
    my ($self) = @_;

    my $sambaMod = $self->global->modInstance('samba');
    unless ($sambaMod->isEnabled() and $sambaMod->isProvisioned()) {
        return undef;
    }
    my $defaultNC = $sambaMod->ldb()->dn();
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
#   Return a list of ExchOrganizationContainer objects that belong to this installation.
#
# Returns:
#
#   An array reference of ExchOrganizationContainer objects.
#
sub organizations
{
    my ($self) = @_;

    my $list = [];
    my $sambaMod = $self->global->modInstance('samba');
    my $configurationContainer = $self->configurationContainer();

    return $list unless ($configurationContainer);

    my $params = {
        base => $configurationContainer->dn(),
        scope => 'one',
        filter => '(objectclass=msExchOrganizationContainer)',
        attrs => ['*'],
    };
    my $result = $sambaMod->ldb()->search($params);
    foreach my $entry ($result->sorted('cn')) {
        my $organization = new EBox::OpenChange::ExchOrganizationContainer(entry => $entry);
        push (@{$list}, $organization);
    }

    return $list;
}

sub _rpcProxyHostForDomain
{
    my ($self, $domain) = @_;

    my $dns = $self->global()->modInstance('dns');
    my $domainExists = grep { $_->{name} eq $domain  } @{  $dns->domains() };
    if (not $domainExists) {
        throw EBox::Exceptions::External(__x('Domain {dom} not able to serve RPCProxy: is not configured in {oh}DNS module{ch}',
                                             dom => $domain,
                                             oh => '<a href="/DNS/Composite/Global">',
                                             ch => '</a>'
                                            ));
    }


    my $dns = $self->global()->modInstance('dns');
    my @hosts = @{ $dns->getHostnames($domain)  };
    my @ips;
    my $network = $self->global()->modInstance('network');
    foreach my $iface (@{ $network->ExternalIfaces() }) {
        my $addresses = $network->ifaceAddresses($iface);
        push @ips, map { $_->{address} } @{  $addresses };
    }

    my $matchedHost;
    my $matchedHostMatchs = 0;
    foreach my $host (@hosts) {
        my $matchs = 0;
        foreach my $hostIp (@{ $host->{ip} }) {
            foreach my $ip (@ips) {
                if ($hostIp eq $ip) {
                    $matchs += 1;
                    last;
                }
            }
            if ($matchs > $matchedHostMatchs) {
                $matchedHost = $host->{name};
                $matchedHostMatchs = $matchs;
                if (@ips == $matchedHostMatchs) {
                    last;
                }
            }
        }
    }

    if (not $matchedHost) {
        EBox::Exceptions::External->throw(__x('Domain cannot use RPC Proxy becasue we cannot find this host in {oh}DNS domain {dom}{ch}',
                                              dom => $domain,
                                              oh => '<a href="/DNS/Composite/Global">',
                                              ch => '</a>'
                                             ));
    }
    return $matchedHost . '.' . $domain;
}

sub _rpcProxyDomain
{
    my ($self) = @_;
    return $self->model('Configuration')->row()->printableValueByName('outgoingDomain');
}

sub _rpcProxyHosts
{
    my ($self) = @_;
    my @hosts;
    my $domain = $self->_rpcProxyDomain();
    push @hosts, $self->_rpcProxyHostForDomain($domain);
    return \@hosts;
}

sub HAProxyInternalService
{
    my ($self) = @_;
    my $RPCProxyModel = $self->model('RPCProxy');
    if (not $self->_rpcProxyEnabled()) {
        return [];
    }

    my $hosts;
    try {
        $hosts = $self->_rpcProxyHosts();
    } catch ($ex) {
        EBox::error("Error when getting host name for RPC proxy: $ex. \nThis feature will be disabled until the error is fixed");
    };
    if (not $hosts) {
        return [];
    }

    my @services;
    if ($RPCProxyModel->httpsEnabled()) {
        my $rpcpService = {
            name => 'oc_rpcproxy_https',
            port => 443,
            printableName => 'OpenChange RPCProxy',
            targetIP => '127.0.0.1',
            targetPort => RPCPROXY_PORT,
            hosts    => $hosts,
            paths       => ['/rpc/rpcproxy.dll', '/rpcwithcert/rpcproxy.dll'],
            pathSSLCert => $self->_rpcProxyCertificate(),
            isSSL   => 1,
        };
        push @services, $rpcpService;
    }

    if ($RPCProxyModel->httpEnabled()) {
        my $httpRpcpService = {
            name => 'oc_rpcproxy_http',
            port => 80,
            printableName => 'OpenChange RPCProxy',
            targetIP => '127.0.0.1',
            targetPort => RPCPROXY_PORT,
            hosts    => $hosts,
            paths       => ['/rpc/rpcproxy.dll', '/rpcwithcert/rpcproxy.dll'],
            isSSL   => 0,
        };
        push @services, $httpRpcpService;
    }

    return \@services;
}

sub HAProxyPreSetConf
{
    my ($self) = @_;
    if ($self->_rpcProxyEnabled()) {
        # the certificate must be in place before harpoxy restarts
        $self->_createRPCProxyCertificate();
    }
}

sub _vdomainModImplementation
{
    my ($self) = @_;
    return EBox::OpenChange::VDomainsLdap->new($self);
}

sub _getMySQLPassword
{
    my $path = OPENCHANGE_MYSQL_PASSWD_FILE;
    open(PASSWD, $path) or
        throw EBox::Exceptions::Internal("Could not open $path to " .
                "get Openchange MySQL password.");

    my $pwd = <PASSWD>;
    close(PASSWD);

    $pwd =~ s/[\n\r]//g;

    return $pwd;
}

# Method: isProvisionedWithMySQL
#
# Returns:
#
#   Whether OpenChange module has been provisioned using MySQL backends or not.
#
#   Since Zentyal 3.4 they are the default backends but on previous versions
#   they didn't exist.
#
sub isProvisionedWithMySQL
{
    my ($self) = @_;

    return $self->isProvisioned() and (-e OPENCHANGE_MYSQL_PASSWD_FILE);
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
    my $pwd = $self->_getMySQLPassword();

    return "mysql://openchange:$pwd\@localhost/openchange";
}

sub notifiyDNSChange
{
    my ($self, $domain) = @_;
    if (not $self->enabled()) {
        return;
    }

    my $rpcpDomain = $self->_rpcProxyDomain();
    if ($domain eq $rpcpDomain) {
        $self->global()->modInstance('haproxy')->setAsChanged(1);
    }
}

1;
