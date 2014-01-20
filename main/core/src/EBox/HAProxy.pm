# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::HAProxy
#
#   Zentyal Service to configure HAProxy as a reverse proxy for other services.
#
package EBox::HAProxy;
use base qw(EBox::Module::Service);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Menu::Item;
use EBox::Module::Base;
use EBox::Sudo;
use Error qw(:try);

use constant HAPROXY_DEFAULT_FILE => '/etc/default/haproxy';
use constant HAPROXY_CONF_FILE    => '/var/lib/zentyal/conf/haproxy.cfg';

# Constructor: _create
#
#   Create a new EBox::HAProxy module object
#
# Overrides:
#
#       <EBox::Module::Service::_create>
#
# Returns:
#
#       <EBox::HAProxy> - the recently created model
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name   => 'haproxy',
        printableName => __('Reverse Proxy'),
        @_
    );

    bless($self, $class);
    return $self;
}

# Method: _daemons
#
#   Defines the set of daemons provided by HAProxy.
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'haproxy',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/haproxy.pid'],
        }
    ]
}

# Method: _daemonsToDisable
#
#   Defines the set of daemons that should not be started on boot but handled by Zentyal.
#
# Overrides:
#
#       <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    my ($self) = @_;

    return $self->_daemons();
}

# Method: ports
#
#   Hash of ports configured to be used by HAProxy with the services attached to them.
#
# Returns:
#
#   hash - All configured ports with the services attached with the following format:
#               - $port:
#                   - isSSL:    Boolean  - Whether this port requires SSL usage.
#                   - services: Array    - Array of services attached to this port:
#                       - isDefault:  Boolean - Wether this service is the default for this port.
#                       - name:       String  - The name of this service (without spaces).
#                       - domains:    List    - List of domain names that this service will handle. If it's empty,
#                                               the isDefault flag will be true.
#                       - targetIP:   String  - IP Address where this service is listening on.
#                       - targetPort: String  - Port number where this service is listening on.
#
sub ports
{
    my ($self) = @_;

    my $global = $self->global();
    my $services = $self->model('Services');
    my %ports = ();

    for my $id (@{$services->enabledRows()}) {
        my $row = $services->row($id);
        my $serviceId = $row->elementByName('serviceId')->value();
        my $module = $global->modInstance($row->elementByName('module')->value());

        my $service = {};
        $service->{isDefault} = 1; # FIXME!
        $service->{name} = $serviceId;
        $service->{domains} = $module->targetHAProxyDomains();
        $service->{targetIP} = $module->targetHAProxyIP();
        $service->{targetPort} = $module->targetHAProxyPort();

        my $port = $row->elementByName('port')->value();
        if ($port) {
            if (not exists ($ports{$port})) {
                $ports{$port}->{isSSL} = undef;
                $ports{$port}->{services} = [];
            }
            push (@{$ports{$port}->{services}}, $service);
        }

        my $sslPort = $row->elementByName('sslPort')->value();
        if ($sslPort) {
            if (not exists ($ports{$sslPort})) {
                $ports{$sslPort}->{isSSL} = 1;
                $ports{$sslPort}->{services} = [];
            }
            push (@{$ports{$sslPort}->{services}}, $service);
        }
    }
    return \%ports;
}

# Method: _setConf
#
#   Write the haproxy configuration.
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my @params = ();
    push (@params, haproxyconfpath => HAPROXY_CONF_FILE);
    $self->writeConfFile(HAPROXY_DEFAULT_FILE, 'core/haproxy-default.mas', \@params);

    my $webadminMod = $self->global()->modInstance('webadmin');
    # Prepare webadmin SSL certificates.
    $webadminMod->_writeCAFiles();

    @params = ();
    push (@params, zentyalconfdir => EBox::Config::conf());
    push (@params, ports => $self->ports());
    if (@{$webadminMod->_CAs(1)}) {
        push (@params, caFile => $webadminMod->CA_CERT_FILE());
    } else {
        push (@params, caFile => undef);
    }

    my $permissions = {
        uid => EBox::Config::user(),
        gid => EBox::Config::group(),
        mode => '0644',
        force => 1,
    };

    EBox::Module::Base::writeConfFileNoCheck(HAPROXY_CONF_FILE, 'core/haproxy.cfg.mas', \@params, $permissions);

}

# Method: isEnabled
#
# Overrides:
#
#       <EBox::Module::Service::isEnabled>
#
sub isEnabled
{
    # haproxy always has to be enabled
    return 1;
}

# Method: showModuleStatus
#
#   Indicate to ServiceManager if the module must be shown in Module
#   status configuration.
#
# Overrides:
#
#       <EBox::Module::Service::showModuleStatus>
#
sub showModuleStatus
{
    # we don't want it to appear in module status
    return undef;
}

# Method: addModuleStatus
#
#   Do not show entry in the module status widget
#
# Overrides:
#
#       <EBox::Module::Service::addModuleStatus>
#
sub addModuleStatus
{
}

# Method: _enforceServiceState
#
#   This method will restart always haproxy.
#
sub _enforceServiceState
{
    my ($self) = @_;

    my $script = $self->INITDPATH() . 'haproxy restart';
    EBox::Sudo::root($script);
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::Base::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $separator = 'Core';
    # Between System and Network.
    my $order = 35;

    my $item = new EBox::Menu::Item(
        url       => 'HAProxy/View/Services',
        icon      => 'rproxy',
        text      => $self->printableName(),
        order     => $order,
        separator => $separator);

    $root->add($item);
}

# Method: modsWithHAProxyService
#
#   All configured service modules (EBox::Module::Service) which implement EBox::HAProxy::ServiceBase interface.
#
# Returns:
#
#       A ref to array with all the Module::Service names
#
sub modsWithHAProxyService
{
    my ($self) = @_;

    my @allModules = @{$self->global()->modInstancesOfType('EBox::Module::Service')};

    my @mods;
    foreach my $module (@allModules) {
        $module->configured() or next;
        if ($module->isa('EBox::HAProxy::ServiceBase')) {
            push (@mods, $module);
        }
    }
    return \@mods;
}

1;
