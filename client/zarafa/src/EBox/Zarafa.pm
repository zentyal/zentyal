# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Zarafa;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::LdapModule
            );

use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::ZarafaLdapUser;
use EBox::Exceptions::DataExists;
use EBox::WebServer;

use Error qw(:try);

use constant ZARAFACONFFILE => '/etc/zarafa/server.cfg';
use constant ZARAFALDAPCONFFILE => '/etc/zarafa/ldap.openldap.cfg';
use constant ZARAFAWEBACCCONFFILE => '/etc/zarafa/webaccess-ajax/config.php';
use constant ZARAFAGATEWAYCONFFILE => '/etc/zarafa/gateway.cfg';
use constant ZARAFAMONITORCONFFILE => '/etc/zarafa/monitor.cfg';
use constant ZARAFASPOOLERCONFFILE => '/etc/zarafa/spooler.cfg';
use constant ZARAFAICALCONFFILE => '/etc/zarafa/ical.cfg';
use constant ZARAFAINDEXERCONFFILE => '/etc/zarafa/indexer.cfg';

use constant ZARAFA_WEBACCESS_DIR => '/usr/share/zarafa-webaccess';
use constant HTTPD_ZARAFA_WEBACCESS_DIR => '/var/www/webaccess';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'zarafa',
                      domain => 'ebox-zarafa',
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
            'action' => __('Create MySQL Zarafa database.'),
            'reason' => __('This database will store the data needed by Zarafa.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Create default SSL key/certificates.'),
            'reason' => __('This self-signed default certificates will be used by Zarafa POP3/IMAP gateway.'),
            'module' => 'zarafa'
        },
        {
            'action' => __('Add zarafa link to www data directory.'),
            'reason' => __('Zarafa will be accesible at http://ip/webaccess/.'),
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
            'file' => ZARAFAWEBACCCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa webaccess.')
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
            'file' => ZARAFAINDEXERCONFFILE,
            'module' => 'zarafa',
            'reason' => __('To properly configure Zarafa indexing server.')
        },
    ];
    # XXX This will never show at enable, remove it?
    my $vhost = $self->model('GeneralSettings')->vHostValue();
    my $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                   EBox::WebServer::VHOST_PREFIX. $vhost .'/ebox-zarafa';
    if ($vhost ne 'disabled') {
        push(@{$files}, { 'file' => $destFile, 'module' => 'zarafa',
                          'reason' => "To configure Zarafa on $vhost virtual host." });
    }
    return $files;
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    EBox::Sudo::root(EBox::Config::share() . '/ebox-zarafa/ebox-zarafa-enable');
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    my ($self) = @_;

    return [
        'EBox::Zarafa::Model::VMailDomain',
        'EBox::Zarafa::Model::GeneralSettings',
        'EBox::Zarafa::Model::Gateways',
        'EBox::Zarafa::Model::Quota',
        'EBox::Zarafa::Model::ZarafaUser',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::Zarafa::Composite::General',
    ];
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
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
            'name' => 'zarafa-indexer',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/zarafa-indexer.pid'],
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

    return $zarafa_indexer;
}

# Method: _setConf
#
#       Overrides base method. It writes the Zarafa service configuration
#
sub _setConf
{
    my ($self) = @_;

    my @array = ();

    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->ldap();
    my $ldapconf = $ldap->ldapConf;

    push(@array, 'ldapsrv' => '127.0.0.1');
    unless ($users->mode() eq 'slave') {
        push(@array, 'ldapport', $ldapconf->{'port'});
    } else {
        push(@array, 'ldapport', $ldapconf->{'translucentport'});
    }
    push(@array, 'ldapbase' => $ldapconf->{'dn'});
    $self->writeConfFile(ZARAFALDAPCONFFILE,
                 "zarafa/ldap.openldap.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    my $server_bind = EBox::Config::configkey('zarafa_server_bind');
    my $attachment_storage = EBox::Config::configkey('zarafa_attachment_storage');
    my $attachment_path = EBox::Config::configkey('zarafa_attachment_path');
    my $zarafa_indexer = EBox::Config::configkey('zarafa_indexer');
    push(@array, 'server_bind' => $server_bind);
    push(@array, 'hostname' => $self->_hostname());
    push(@array, 'mysql_user' => 'zarafa');
    push(@array, 'mysql_password' => $self->_getPassword());
    push(@array, 'attachment_storage' => $attachment_storage);
    push(@array, 'attachment_path' => $attachment_path);
    push(@array, 'quota_warn' => $self->model('Quota')->warnQuota());
    push(@array, 'quota_soft' => $self->model('Quota')->softQuota());
    push(@array, 'quota_hard' => $self->model('Quota')->hardQuota());
    push(@array, 'indexer' => $zarafa_indexer);
    $self->writeConfFile(ZARAFACONFFILE,
                 "zarafa/server.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

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
    push(@array, 'icals' => $self->model('Gateways')->icalValue() ? 'yes' : 'no');
    push(@array, 'timezone' => $self->_timezone());
    $self->writeConfFile(ZARAFAICALCONFFILE,
                 "zarafa/ical.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    @array = ();
    $self->writeConfFile(ZARAFAINDEXERCONFFILE,
                 "zarafa/indexer.cfg.mas",
                 \@array, { 'uid' => '0', 'gid' => '0', mode => '644' });

    $self->_setSpellChecking();
    $self->_setWebServerConf();
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

    # Delete all possible ebox-zarafa configuration
    my $vHostPattern = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                       EBox::WebServer::VHOST_PREFIX. '*/ebox-zarafa';
    EBox::Sudo::root('rm -f ' . "$vHostPattern");

    my $vhost = $self->model('GeneralSettings')->vHostValue();
    my $activesync = $self->model('GeneralSettings')->activeSyncValue();

    my @cmds = ();

    if ($vhost eq 'disabled') {
        push(@cmds, 'a2ensite zarafa-webaccess');
        push(@cmds, 'a2ensite zarafa-webaccess-mobile');
        if ($activesync) {
            push(@cmds, 'a2ensite z-push');
        } else {
            push(@cmds, 'a2dissite z-push');
        }
    } else {
        push(@cmds, 'a2dissite zarafa-webaccess');
        push(@cmds, 'a2dissite zarafa-webaccess-mobile');
        push(@cmds, 'a2dissite z-push');
        my $destFile = EBox::WebServer::SITES_AVAILABLE_DIR . 'user-' .
                       EBox::WebServer::VHOST_PREFIX. $vhost .'/ebox-zarafa';
        $self->writeConfFile($destFile, 'zarafa/apache.mas', [ activesync => $activesync ]);
    }
    try {
        EBox::Sudo::root(@cmds);
    } catch EBox::Exceptions::Sudo::Command with {
    }
}

sub _setSpellChecking
{
    my ($self) = @_;

    my $spell = $self->model('GeneralSettings')->spellCheckingValue();

    if ($spell) {
        EBox::Sudo::root(EBox::Config::share() . '/ebox-zarafa/ebox-zarafa-spell enable');
    } else {
        EBox::Sudo::root(EBox::Config::share() . '/ebox-zarafa/ebox-zarafa-spell disable');
    }
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
    $root->add(new EBox::Menu::Item('url' => 'Zarafa/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Office',
                                    'order' => 560));
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
             service =>  __('Zarafa Gateway Server'),
             path    =>  '/etc/zarafa/ssl/ssl.pem',
             user => 'root',
             group => 'root',
             mode => '0400',
        },
    ];
}

1;
