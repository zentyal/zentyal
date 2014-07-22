# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Zarafa;

no warnings 'experimental::smartmatch';
use feature qw(switch);

use base qw(EBox::Module::Service EBox::LdapModule EBox::KerberosModule);

use EBox::Config;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::Users::User;
use EBox::WebServer;
use EBox::ZarafaLdapUser;
use EBox::MyDBEngine;

use Encode;
use TryCatch::Lite;
use Net::LDAP::LDIF;
use Storable;

use constant ZARAFACONFFILE => '/etc/zarafa/server.cfg';
use constant ZARAFALDAPCONFFILE => '/etc/zarafa/ldap.openldap.cfg';
use constant ZARAFAWEBAPPCONFFILE => '/etc/zarafa/webaccess-ajax/config.php';
use constant ZARAFAXMPPCONFFILE => '/usr/share/zarafa-webapp/plugins/xmpp/config.php';
use constant ZARAFAGATEWAYCONFFILE => '/etc/zarafa/gateway.cfg';
use constant ZARAFAMONITORCONFFILE => '/etc/zarafa/monitor.cfg';
use constant ZARAFASPOOLERCONFFILE => '/etc/zarafa/spooler.cfg';
use constant ZARAFAICALCONFFILE => '/etc/zarafa/ical.cfg';
use constant ZARAFADAGENTCONFFILE => '/etc/zarafa/dagent.cfg';

use constant ZARAFA_LICENSED_INIT => '/etc/init.d/zarafa-licensed';

use constant KEYTAB_FILE => '/etc/zarafa/zarafa.keytab';

use constant FIRST_RUN_FILE => '/var/lib/zentyal/conf/zentyal-zarafa.first';
use constant STATS_CMD      => '/usr/bin/zarafa-stats';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'zarafa',
                      printableName => 'Groupware',
                      @_);

    bless($self, $class);
    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('Add Zarafa LDAP schema'),
            'reason' => __('Zentyal will need this schema to store Zarafa users.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Add vmail system user'),
            'reason' => __('Zentyal will need this to deliver mail to Zarafa.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Create MySQL Zarafa database'),
            'reason' => __('This database will store the data needed by Zarafa.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Create default SSL key/certificates'),
            'reason' => __('This self-signed default certificates will be used by Zarafa POP3/IMAP gateway.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Add zarafa link to www data directory'),
            'reason' => __('Zarafa will be accesible at http://ip/webaccess/ and http://ip/webapp/.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Install English/United States locale on the system if it is not already installed'),
            'reason' => __('Zarafa needs this locale to run.'),
            'module' => 'zarafa'
        },

    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    my ($self) = @_;

    my $files = [
        {
            'file' => ZARAFACONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa.')
        },
        {
            'file' => ZARAFALDAPCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa LDAP connection.')
        },
        {
            'file' => ZARAFAWEBAPPCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa webaccess.')
        },
        {
            'file' => ZARAFAXMPPCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa XMPP integration.')
        },
        {
            'file' => ZARAFAGATEWAYCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa gateway server.')
        },
        {
            'file' => ZARAFAMONITORCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa quota monitoring server.')
        },
        {
            'file' => ZARAFASPOOLERCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa mail delivering server.')
        },
        {
            'file' => ZARAFAICALCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa ical server.')
        },
        {
            'file' => ZARAFADAGENTCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa dagent LMTP delivering server.')
        },
    ];
    # XXX This will never show at enable, remove it?
    my $vhost = $self->model('GeneralSettings')->vHostValue();
    my $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                   EBox::WebServer::VHOST_PREFIX. $vhost .'/zentyal-zarafa';
    if ($vhost ne 'disabled') {
        push(@{$files}, { 'file' => $destFile, 'module' => 'zarafa',
                          'reason' => "To configure Zarafa on $vhost virtual host." });
    }
    return $files;
}

sub kerberosServicePrincipals
{
    my ($self) = @_;

    my $data = { service    => 'http',
                 principals => [ 'HTTP' ],
                 keytab     => KEYTAB_FILE,
                 keytabUser => 'www-data' };
    return $data;
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;
    $self->checkUsersMode();

    $self->performLDAPActions();

    $self->kerberosCreatePrincipals();

    # Execute enable-module script
    $self->SUPER::enableActions();
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
        my $firewall = EBox::Global->modInstance('firewall');
        $firewall or
            return;
        $firewall->addServiceRules($self->_serviceRules());
        $firewall->saveConfigRecursive();
    }
}

# Method: reprovisionLDAP
#
# Overrides:
#
#      <EBox::LdapModule::reprovisionLDAP>
sub reprovisionLDAP
{
    my ($self) = @_;

    $self->SUPER::reprovisionLDAP();

    # regenerate kerberos keytab
    $self->kerberosCreatePrincipals();
}

sub _serviceRules
{
    return [
             {
              'name' => 'Groupware',
              'description' => __('Groupware services (Zarafa)'),
              'internal' => 1,
              'protocol' => 'tcp',
              'sourcePort' => 'any',
              'destinationPorts' => [ 236, 237, 8080, 8443 ],
              'rules' => { 'external' => 'deny', 'internal' => 'accept' },
             },
    ];
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableService to notify mail
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    if ($self->changed()) {
        my $mail = EBox::Global->modInstance('mail');
        $mail->setAsChanged();
    }
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my $daemons = [
        {
            'name' => 'zarafa-server',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-server.pid']
        },
        {
            'name' => 'zarafa-monitor',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-monitor.pid']
        },
        {
            'name' => 'zarafa-spooler',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-spooler.pid']
        },
        {
            'name' => 'zarafa-dagent',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-dagent.pid']
        },
        {
            'name' => 'zarafa-search',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-search.pid'],
            'precondition' => \&indexerEnabled
        },
        {
            'name' => 'zarafa-gateway',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-gateway.pid'],
            'precondition' => \&gatewayEnabled
        },
        {
            'name' => 'zarafa-ical',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-ical.pid'],
            'precondition' => \&icalEnabled
        },
    ];

    if (-x ZARAFA_LICENSED_INIT) {
        push (@{$daemons},
            {
                'name' => 'zarafa-licensed',
                'type' => 'init.d',
                'pidfiles' => ['/var/run/zarafa-licensed.pid'],
                'precondition' => \&licensedEnabled
            },
        );
    }

    return $daemons;
}

# Method: gatewayEnabled
#
#       Returns true if any of the gateways are enabled
#
sub gatewayEnabled
{
    my ($self) = @_;

    my $gatewaysMod = $self->model('Gateways');

    return ($gatewaysMod->pop3Value() or
            $gatewaysMod->pop3sValue() or
            $gatewaysMod->imapValue() or
            $gatewaysMod->imapsValue());
}

# Method: icalEnabled
#
#       Returns true if ical or icals are enabled
#
sub icalEnabled
{
    my ($self) = @_;

    my $gatewaysMod = $self->model('Gateways');

    return ($gatewaysMod->icalValue() or
            $gatewaysMod->icalsValue());
}

# Method: indexerEnabled
#
#       Returns true if indexer is enabled
#
sub indexerEnabled
{
    my ($self) = @_;

    my $zarafa_indexer = EBox::Config::configkey('zarafa_indexer');

    return ($zarafa_indexer eq 'yes');
}

# Method: licensedEnabled
#
#       Returns true if licensed is enabled
#
sub licensedEnabled
{
    my ($self) = @_;

    my $zarafa_licensed = EBox::Config::configkey('zarafa_licensed');

    return ($zarafa_licensed eq 'yes');
}

# Method: _setConf
#
#       Overrides base method. It writes the Zarafa service configuration
#
sub _setConf
{
    my ($self) = @_;

    my @array = ();

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->ldap();
    my $ldapconf = $ldap->ldapConf;

    my $gssapiHostname = 'ns.' . $sysinfo->hostDomain();

    push(@array, 'ldapsrv' => '127.0.0.1');
    push(@array, 'ldapport', $ldapconf->{'port'});
    push(@array, 'ldapbase' => $ldapconf->{'dn'});
    push(@array, 'ldapuser' => $ldap->roRootDn());
    push(@array, 'ldappwd' => $ldap->getRoPassword());
    $self->writeConfFile(ZARAFALDAPCONFFILE,
                 "zarafa/ldap.openldap.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    my $server_bind;
    my $server_ssl_enabled;
    if ($self->model('GeneralSettings')->soapValue()) {
        $server_bind = '0.0.0.0';
        $server_ssl_enabled = 'no';
    } else {
        $server_bind = '127.0.0.1';
        $server_ssl_enabled = 'no';
    }
    my $attachment_storage = EBox::Config::configkey('zarafa_attachment_storage');
    my $attachment_path = EBox::Config::configkey('zarafa_attachment_path');
    my $zarafa_indexer = EBox::Config::configkey('zarafa_indexer');
    my $enable_hosted_zarafa = EBox::Config::configkey('zarafa_enable_hosted_zarafa');
    my $enable_sso = $self->model('GeneralSettings')->ssoValue() ? 'yes' : 'no';
    push(@array, 'server_bind' => $server_bind);
    push(@array, 'hostname' => $self->_hostname());
    push(@array, 'mysql_user' => 'zarafa');
    push(@array, 'mysql_password' => $self->_getPassword());
    push(@array, 'attachment_storage' => $attachment_storage);
    push(@array, 'attachment_path' => $attachment_path);
    push(@array, 'server_ssl_enabled' => $server_ssl_enabled);
    push(@array, 'quota_warn' => $self->model('Quota')->warnQuota());
    push(@array, 'quota_soft' => $self->model('Quota')->softQuota());
    push(@array, 'quota_hard' => $self->model('Quota')->hardQuota());
    push(@array, 'enable_hosted_zarafa' => $enable_hosted_zarafa);
    push(@array, 'enable_sso' => $enable_sso);
    push(@array, 'indexer' => $zarafa_indexer);
    $self->writeConfFile(ZARAFACONFFILE,
                 "zarafa/server.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '640' });

    @array = ();
    push(@array, 'pop3' => $self->model('Gateways')->pop3Value() ? 'yes' : 'no');
    push(@array, 'pop3s' => $self->model('Gateways')->pop3sValue() ? 'yes' : 'no');
    push(@array, 'imap' => $self->model('Gateways')->imapValue() ? 'yes' : 'no');
    push(@array, 'imaps' => $self->model('Gateways')->imapsValue() ? 'yes' : 'no');
    $self->writeConfFile(ZARAFAGATEWAYCONFFILE,
                 "zarafa/gateway.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    $self->writeConfFile(ZARAFAMONITORCONFFILE,
                 "zarafa/monitor.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    my $always_send_delegates = EBox::Config::configkey('zarafa_always_send_delegates');
    push(@array, 'always_send_delegates' => $always_send_delegates);
    $self->writeConfFile(ZARAFASPOOLERCONFFILE,
                 "zarafa/spooler.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    push(@array, 'ical' => $self->model('Gateways')->icalValue() ? 'yes' : 'no');
    push(@array, 'icals' => $self->model('Gateways')->icalsValue() ? 'yes' : 'no');
    push(@array, 'timezone' => $self->_timezone());
    $self->writeConfFile(ZARAFAICALCONFFILE,
                 "zarafa/ical.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    $self->writeConfFile(ZARAFADAGENTCONFFILE,
                 "zarafa/dagent.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    my $jabber = $self->model('GeneralSettings')->jabberValue();
    if ($jabber and EBox::Global->modExists('jabber')) {
        @array = ();
        my $jabberMod = EBox::Global->modInstance('jabber');
        push(@array, 'domain' => $jabberMod->model('GeneralSettings')->domainValue());
        $self->writeConfFile(ZARAFAXMPPCONFFILE,
                     "zarafa/xmpp-config.php.mas",
                     \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });
    }

    $self->_setSpellChecking();
    $self->_setWebServerConf();

    my $db = EBox::DBEngineFactory::DBEngine();
    $db->updateMysqlConf();

    $self->_createVMailDomainsOUs();
}

# Method: _postServiceHook
#
#     Override this method to setup shared folders.
#
# Overrides:
#
#     <EBox::Module::Service::_postServiceHook>
#
sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled and -f FIRST_RUN_FILE) {
        my $cmd = 'zarafa-admin -s';
        EBox::Sudo::rootWithoutException($cmd);
        unlink FIRST_RUN_FILE;
    }

    return $self->SUPER::_postServiceHook($enabled);
}

# Method: stats
#
#     Get the data from zarafa stats command
#
# Returns:
#
#     Hash ref - containing the user stats whose key is the username
#     containing as value a hash ref with user data
#
sub stats
{
    my ($self) = @_;

    my $statsStr = EBox::Sudo::root(STATS_CMD . ' --users');

    my @stats = @{$statsStr}[2 .. $#{$statsStr}];

    # my %map = ( '0x6748001E' => 'username',
    #             '0x3001001E' => 'fullname',
    #             '0x39FE001E' => 'email',
    #             '0x67210003' => 'soft_quota',
    #             '0x67220003' => 'hard_quota',
    #             '0x0E080014' => 'size' );
    my %header = ( 'username' => 1,
                   'fullname' => 2,
                   'email'    => 3,
                   'soft_quota' => 6,
                   'hard_quota' => 7,
                   'size' => 5 );

    # Results in a hash by username
    my %result;
    foreach my $line (@stats) {
        chomp($line);
        $line =~ s:\t+:\t:g;
        my @fields = split(/\t/, $line);
        my $user = {};
        foreach my $fieldName (qw(username fullname email soft_quota hard_quota size)) {
            $user->{$fieldName} = $fields[$header{$fieldName}];
        }
        while( my ($k, $v) = each(%{$user}) ) {
            if ( $v =~ m/^error: 0x/ ) {
                # Not valid value, then set to -1
                $user->{$k} = -1;
            }
            given ( $k ) {
                when ( ['soft_quota', 'hard_quota'] ) {
                    if ( $v != -1 ) {
                        # Store the result in bytes
                        $user->{$k} = $v * 1024;
                    }
                }
            }
        }
        $result{$user->{username}} = $user;
    }

    return \%result;
}

sub _hostname
{
    my $fqdn = `hostname --fqdn`;
    chomp $fqdn;
    return $fqdn;
}

sub _getPassword
{

    my $path = EBox::Config->conf . "/ebox-zarafa.passwd";
    open(PASSWD, $path) or
        throw EBox::Exceptions::Internal("Could not open $path to " .
                "get Zarafa password.");

    my $pwd = <PASSWD>;
    close(PASSWD);

    $pwd =~ s/[\n\r]//g;

    return $pwd;
}

sub _timezone
{

    my $path = '/etc/timezone';
    open(TZ, $path) or
        throw EBox::Exceptions::Internal("Could not open $path to " .
                "get server timezone.");

    my $timezone = <TZ>;
    close(TZ);

    $timezone =~ s/[\n\r]//g;

    return $timezone;
}

sub _setWebServerConf
{
    my ($self) = @_;

    # Delete all possible zentyal-zarafa configuration
    my $vHostPattern = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                       EBox::WebServer::VHOST_PREFIX. '*/ebox-zarafa';
    EBox::Sudo::root('rm -f ' . "$vHostPattern");

    my @array = ();
    my $vhost = $self->model('GeneralSettings')->vHostValue();
    my $activesync = $self->model('GeneralSettings')->activeSyncValue();
    my $jabber = $self->model('GeneralSettings')->jabberValue();
    my $enable_sso = $self->model('GeneralSettings')->ssoValue();
    my $realm = EBox::Global->modInstance('users')->kerberosRealm();

    push(@array, 'activesync' => $activesync);
    push(@array, 'jabber' => $jabber);
    push(@array, 'enable_sso' => $enable_sso);
    push(@array, 'realm' => $realm);

    EBox::Sudo::root(EBox::Config::scripts('zarafa') .
                     'zarafa-sso ' . ($enable_sso ? 'enable' : 'disable'));

    my $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . '/zarafa-webapp-xmpp';
    $self->writeConfFile($destFile, 'zarafa/zarafa-webapp-xmpp.mas', \@array);

    $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . '/zarafa-web-sso';
    $self->writeConfFile($destFile, 'zarafa/zarafa-web-sso.mas', \@array);

    my @cmds = ();

    if ($vhost eq 'disabled') {
        push(@cmds, 'a2ensite zarafa-webaccess');
        push(@cmds, 'a2ensite zarafa-webapp');
        if ($activesync) {
            push(@cmds, 'a2ensite d-push');
        } else {
            push(@cmds, 'a2dissite d-push');
        }
        if ($jabber) {
            push(@cmds, 'a2enmod proxy_http');
            push(@cmds, 'a2ensite zarafa-webapp-xmpp');
        } else {
            push(@cmds, 'a2dissite zarafa-webapp-xmpp');
            push(@cmds, 'a2dismod proxy_http');
        }
        if ($enable_sso) {
            push(@cmds, 'a2enmod auth_kerb');
            push(@cmds, 'a2ensite zarafa-web-sso');
        } else {
            push(@cmds, 'a2dissite zarafa-web-sso');
            push(@cmds, 'a2dismod auth_kerb');
        }
    } else {
        push(@cmds, 'a2dissite zarafa-webaccess');
        push(@cmds, 'a2dissite zarafa-webapp');
        push(@cmds, 'a2dissite zarafa-webapp-xmpp');
        push(@cmds, 'a2dissite zarafa-web-sso');
        push(@cmds, 'a2dissite d-push');
        if ($jabber) {
            push(@cmds, 'a2enmod proxy_http');
        } else {
            push(@cmds, 'a2dismod proxy_http');
        }
        if ($enable_sso) {
            push(@cmds, 'a2enmod auth_kerb');
        } else {
            push(@cmds, 'a2dismod auth_kerb');
        }
        my $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                       EBox::WebServer::VHOST_PREFIX. $vhost .'/ebox-zarafa';
        $self->writeConfFile($destFile, 'zarafa/apache.mas', \@array);
    }
    try {
        EBox::Sudo::root(@cmds);
    } catch (EBox::Exceptions::Sudo::Command $e) {
    }
}

sub _setSpellChecking
{
    my ($self) = @_;

    my $spell = $self->model('GeneralSettings')->spellCheckingValue();

    EBox::Sudo::root(EBox::Config::scripts('zarafa') .
                     'zarafa-spell ' . ($spell ? 'enable' : 'disable'));
}

sub _createVMailDomainsOUs
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    my $namingContext = $usersMod->defaultNamingContext();

    my $dn = "ou=zarafa," . $namingContext->dn();
    my $ou = new EBox::Users::OU(dn => $dn);
    unless ($ou and $ou->exists()) {
        $ou = EBox::Users::OU->create(name => 'zarafa', parent => $namingContext, ignoreMods => ['samba']);
    }

    my @vdomains = @{$self->model('VMailDomains')->vdomains()};

    foreach my $vdomain (@vdomains) {
        $self->_addVMailDomainOU($vdomain, $ou);
    }
}

sub _addVMailDomainOU
{
    my ($self, $vdomain, $parent) = @_;

    my $dn = "ou=$vdomain," . $parent->dn();
    my $ou = new EBox::Users::OU(dn => $dn);
    return if ($ou and $ou->exists());

    $ou = EBox::Users::OU->create(name => $vdomain, parent => $parent, ignoreMods => ['samba']);
    $ou->add('objectClass', [ 'zarafa-company' ], 1);
    $ou->save();
}

# Method: addModuleStatus
#
#   Overrides EBox::Module::Service::addModuleStatus
#
sub addModuleStatus
{
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'Zarafa',
                                        'icon' => 'zarafa',
                                        'text' => $self->printableName(),
                                        'separator' => 'Communications',
                                        'order' => 605
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'Zarafa/Composite/General',
                                      'text' => __('General')
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'Zarafa/View/VMailDomains',
                                      'text' => __('Virtual Mail Domains')
                 )
    );

    $root->add($folder);
}

# Method: _ldapModImplementation
#
#      All modules using any of the functions in LdapUserBase.pm
#      should override this method to return the implementation
#      of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
#
sub _ldapModImplementation
{
    return new EBox::ZarafaLdapUser();
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issue for this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       service - name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#
sub certificates
{
    my ($self) = @_;

    return [
        {
             serviceId => 'Zarafa Gateway Server',
             service =>  __('Zarafa Gateway Server'),
             path    =>  '/etc/zarafa/ssl/ssl.pem',
             user => 'root',
             group => 'root',
             mode => '0400',
        },
    ];
}

1;
