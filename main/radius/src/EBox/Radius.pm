# Copyright (C) 2009-2018 Zentyal S.L.
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

package EBox::Radius;

use base qw(
    EBox::Module::Kerberos
    EBox::LogObserver
);

use EBox::Global;
use EBox::Gettext;

use EBox::Ldap;
use EBox::Radius::LogHelper;
use EBox::Radius::LdapUser;

use constant CONFDIR => "/etc/freeradius/3.0/";
use constant USERSCONFFILE => CONFDIR . 'mods-config/files/authorize';
use constant LDAPCONFFILE => CONFDIR . 'mods-available/ldap';
use constant KRB5CONFFILE => CONFDIR . 'mods-available/krb5';
use constant RADIUSDCONFFILE => CONFDIR . 'radiusd.conf';
use constant CLIENTSCONFFILE => CONFDIR . 'clients.conf';
use constant EAPCONFFILE => CONFDIR . 'mods-available/eap';
use constant DEFAULTSRVCONFFILE => CONFDIR . 'sites-available/default';
use constant INNERTUNNELSRVCONFFILE => CONFDIR . 'sites-available/inner-tunnel';
use constant MSCHAPCONFFILE => CONFDIR . 'mods-available/mschap';
use constant CERTSDIR => CONFDIR . 'certs';

# Constructor: _create
#
#      Create a new EBox::Radius module object
#
# Returns:
#
#      <EBox::Radius> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'radius',
            printableName => 'RADIUS',
            @_);

    bless($self, $class);
    return $self;
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Create RADIUS certificates for TTLS'),
        'reason' => __x('Zentyal will create the needed certificates for TTLS ' .
                       'in {d}.', d => CERTSDIR),
        'module' => 'radius'
    },
    {
        'action' => __('Allow others to read /var/log/freeradius'),
        'reason' => __('Zentyal will change default permissions on RADIUS log ' .
                       'directory to allow to read the logs.'),
        'module' => 'radius'
    },
    ];
}

# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => USERSCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure allowed LDAP group.')
                      },
                      { 'file' => LDAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS LDAP module.')
                      },
                      { 'file' => RADIUSDCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS daemon.')
                      },
                      { 'file' => CLIENTSCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS clients.')
                      },
                      { 'file' => EAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS EAP.')
                      },
                      { 'file' => DEFAULTSRVCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure default RADIUS vhost.')
                      },
                      { 'file' => INNERTUNNELSRVCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS inner-tunnel vhost.')
                      },
                      { 'file' => MSCHAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS mschap.')
                      },
         );

    return \@usedFiles;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('network');

        my $serviceName = 'RADIUS';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('Zentyal RADIUS system'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'deny');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

sub _services
{
    return [
             { # radius auth
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '1812',
             },
             { # radius acct
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '1813',
             },
    ];
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [ { 'name' => 'freeradius', 'type' => 'systemd' } ];
}

# Method: _regenConfig
#
#   Overrides <EBox::Module::Service::_regenConfig>
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    if ($self->global()->modInstance('samba')->isProvisioned()) {
        $self->SUPER::_regenConfig(@_);
    }
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->writeConfFile(RADIUSDCONFFILE, "radius/radiusd.conf.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(DEFAULTSRVCONFFILE, "radius/default.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(INNERTUNNELSRVCONFFILE, "radius/inner-tunnel.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(MSCHAPCONFFILE, "radius/mschap.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });

    $self->_setUsers();
    $self->_setEAP();
    $self->_setLDAP();
    $self->_setKRB5();
    $self->_setClients();
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    return unless $enabled;

    EBox::Sudo::silentRoot('grep "ntlm auth = yes" /etc/samba/smb.conf');
    if ($? != 0) {
        $self->global()->addModuleToPostSave('samba');
    }
}

# set up the Users configuration
sub _setUsers
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('Auth');

    push (@params, bygroup => $model->getByGroup());
    push (@params, group => $model->getGroup());

    $self->writeConfFile(USERSCONFFILE, "radius/authorize.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}

# set up the EAP configuration
sub _setEAP
{
    my ($self) = @_;

    my @params = ();

    if (EBox::Global->modExists('ca')) {
        my $ca = EBox::Global->modInstance('ca');
        my $model = $ca->model('Certificates');
        if ($model->isEnabledService('RADIUS')) {
            push (@params, capath => '/var/lib/zentyal/CA/cacert.pem');
        } else {
            push (@params, capath => '${cadir}/ca.pem');
        }
    } else {
        push (@params, capath => '${cadir}/ca.pem');
    }

    $self->writeConfFile(EAPCONFFILE, "radius/eap.conf.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}

# set up the LDAP configuration
sub _setLDAP
{
    my ($self) = @_;

    my $port;
    my @params = ();

    my $ldap = $self->ldap();
    my $ldapConf = $ldap->ldapConf();

    my $url = $ldapConf->{'ldap'};
    push (@params, url => $url);
    push (@params, dn => $ldapConf->{'dn'});
    push (@params, rootdn => $self->_kerberosServiceAccountDN());
    push (@params, password => $self->_kerberosServiceAccountPassword());

    $self->writeConfFile(LDAPCONFFILE, "radius/ldap.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}

# set up the KRB5 configuration
sub _setKRB5
{
    my ($self) = @_;

    my @params = ();

    my $info = $self->_kerberosKeytab();
    my $spns = $self->_kerberosFullSPNs();

    push (@params, keytab => $info->{path});
    push (@params, service_principal => @{$spns}[0]);

    use File::Basename;
    my $krb5ConfFile = '../mods-available/' . basename(KRB5CONFFILE);
    my $krb5LinkFile = CONFDIR . 'mods-enabled/' . basename(KRB5CONFFILE);
    EBox::Sudo::root("ln -snf $krb5ConfFile $krb5LinkFile");

    $self->_kerberosRefreshKeytab();
    $self->writeConfFile(KRB5CONFFILE, "radius/krb5.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}

# set up the RADIUS clients
sub _setClients
{
    my ($self) = @_;

    my @params = ();
    my $model = $self->model('Clients');

    push (@params, clients => $model->getClients());
    $self->writeConfFile(CLIENTSCONFFILE, "radius/clients.conf.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}

# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item(
            'url' => 'Radius/Composite/General',
            'icon' => 'radius',
            'separator' => 'Gateway',
            'order' => 225,
            'text' => 'RADIUS'));
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
             serviceId => 'RADIUS',
             service =>  __('RADIUS'),
             path    =>  CERTSDIR . '/freeradius.pem',
             user => 'root',
             group => 'freerad',
             mode => '0440',
            },
           ];
}

sub logHelper
{
    my ($self) = @_;
    return EBox::Radius::LogHelper->new();
}

sub tableInfo
{
    my ($self) = @_;

    my $titles = { 'timestamp' => __('Date'),
                   'event'     => __('Event'),
                   'login'      => __('User'),
                   'client'    => __('Client'),
                   'port'      => __('Port'),
                   'mac'       => __('MAC'),
                 };
    my @order = ( 'timestamp', 'event', 'login', 'client',
                  'mac');

    my $events = { 'Login OK' => __('Login OK'),
                   'Login incorrect' => __('Login incorrect'),
                  };
    return [{
            'name' => __('RADIUS'),
            'tablename' => 'radius_auth',
            'titles' => $titles,
            'order' => \@order,
            'filter' => ['login', 'client', 'mac'],
            'events' => $events,
            'eventcol' => 'event',
           }];
}

sub _ldapModImplementation
{
    return new EBox::Radius::LdapUser();
}

# Method: _kerberosServicePrincipals
#
#   Return the service principal names to add to the service account.
#
#   To be implemented by the module.
#
# Return:
#
#   Array ref - Containing the SPNs
#
sub _kerberosServicePrincipals
{
    my ($self) = @_;

    my $spns;
    push (@{$spns}, "radius");
    return \@{$spns};
}

# Method: _kerberosKeytab
#
#   Return the necessary information to extract the keytab for the service.
#   The keytab will contain the service account keys with all its service
#   principals.
#
#   To be implemented by the module
#
# Return:
#
#   Hash ref - Containig the following pairs:
#       path - The path where the keytab will be extracted
#       user - The owner user for the extracted keytab
#       group - The owner group for the extracted keytab
#       mode - The mode for the extracted keytab
#
sub _kerberosKeytab
{
    my ($self) = @_;

    my $account = $self->_kerberosServiceAccount();

    return { 
	'path'  => CONFDIR . "$account.keytab",
        'user'  => 'root', 
	'group' => 'freerad', 
	'mode'  => '640' 
    };
}

1;
