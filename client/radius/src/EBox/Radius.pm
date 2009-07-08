# Copyright (C) 2008 eBox Technologies S.L.
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


package EBox::Radius;

# Class: EBox::Radius
#
#

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::FirewallObserver);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::Ldap;

use constant LDAPATTRMAPCONFFILE => '/etc/freeradius/ldap.attrmap';
use constant PAPCONFFILE => '/etc/freeradius/modules/pap';
use constant LDAPCONFFILE => '/etc/freeradius/modules/ldap';
use constant CLIENTSCONFFILE => '/etc/freeradius/clients.conf';
use constant DEFAULTSRVCONFFILE => '/etc/freeradius/sites-available/default';
use constant INNERTUNNELSRVCONFFILE => '/etc/freeradius/sites-available/inner-tunnel';

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
            printableName => __('RADIUS'),
            domain => 'ebox-radius',
            @_);

    bless($self, $class);
    return $self;
}


# Method: modelClasses
#
# Overrides:
#
#      <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::Radius::Model::Clients',
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
        'EBox::Radius::Composite::General',
    ];
}


# Method: actions
#
# Overrides:
#
#      <EBox::Module::Service::actions>
#
#sub actions
#{
#    return [
#    {
#        'action' => __('Enable default RADIUS vhost.'),
#        'reason' => __('To configure EAP channel.'),
#        'module' => 'radius'
#    },
#    {
#        'action' => __('Enable RADIUS inner-tunnel vhost.'),
#        'reason' => __('To configure PAP inner authentication.'),
#        'module' => 'radius'
#    },
#    ];
#}


# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => LDAPATTRMAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To map LDAP attributes with RADIUS attributes.')
                      },
                      { 'file' => LDAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS LDAP module.')
                      },
                      { 'file' => PAPCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS PAP module.')
                      },
                      { 'file' => CLIENTSCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS clients.')
                      },
                      { 'file' => DEFAULTSRVCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure default RADIUS vhost.')
                      },
                      { 'file' => INNERTUNNELSRVCONFFILE,
                        'module' => 'radius',
                        'reason' => __('To configure RADIUS inner-tunnel vhost.')
                      },
         );

    return \@usedFiles;
}


# Method: enableActions
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::enableActions>
#
#sub enableActions
#{
#    my ($self) = @_;
#
#    EBox::Sudo::root(EBox::Config::share() .
#                     '/ebox-radius/ebox-radius-enable');
#}


# Method: enableService
#
# Overrides:
#
#      <EBox::Module::Service::enableService>
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
}


# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'freeradius',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/freeradius/freeradius.pid'],
        }
    ];
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

    $self->writeConfFile(PAPCONFFILE, "radius/pap.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(LDAPATTRMAPCONFFILE, "radius/ldap.attrmap.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(DEFAULTSRVCONFFILE, "radius/default.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
    $self->writeConfFile(INNERTUNNELSRVCONFFILE, "radius/inner-tunnel.mas",
                         undef, { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });

    $self->_setLDAP();
    $self->_setClients();
}


# set up the LDAP configuration
sub _setLDAP
{
    my ($self) = @_;

    my @params = ();

    my $users = EBox::Global->modInstance('users');

    my $ldap = EBox::Ldap->instance();
    my $ldapConf = $ldap->ldapConf();
    push (@params, url => $ldapConf->{'ldap'});
    push (@params, dn => $ldapConf->{'dn'});
    push (@params, rootdn => $ldapConf->{'rootdn'});
    push (@params, password => $ldap->getPassword());

    $self->writeConfFile(LDAPCONFFILE, "radius/ldap.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'freerad', mode => '640' });
}


# set up the RADIUS clients
sub _setClients
{
    my ($self) = @_;

    my $model = $self->model('Clients');

    my @params = ();
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
            'separator' => __('Gateway'),
            'order' => 225,
            'text' => __('RADIUS')));
}

1;
