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
use EBox::Validate qw( checkPort );
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

# Method: ports
#
#   Hash of ports configured to be used by HAProxy with the services attached to them.
#
# Returns:
#
#   hash - All configured ports with the services attached with the following format:
#               - $port:
#                   - isSSL:               Boolean  - Whether this port requires SSL usage.
#                   - services:            Array    - Array of services attached to this port:
#                       - isDefault:       Boolean - Wether this service is the default for this port.
#                       - pathSSLCert:     String  - A full path to the certificate used by this service or undef.
#                       - name:            String  - The name of this service (without spaces).
#                       - domains:         List    - List of domain names that this service will handle. If it's
#                                                    empty, the isDefault and isDefaultForSSL flags will be true.
#                       - targetIP:        String  - IP Address where this service is listening on.
#                       - targetPort:      String  - Port number where this service is listening on.
#
sub ports
{
    my ($self) = @_;

    my $global = $self->global();
    my $services = $self->model('HAProxyServices');
    my %ports = ();

    for my $id (@{$services->enabledRows()}) {
        my $row = $services->row($id);
        my $serviceId = $row->valueByName('serviceId');
        my $module = $global->modInstance($row->valueByName('module'));

        my $service = {};
        $service->{name} = $serviceId;
        $service->{domains} = $module->targetHAProxyDomains();
        $service->{targetIP} = $module->targetHAProxyIP();

        my $enabledPort = $module->isPortEnabledInHAProxy();
        my $port = undef;
        if ($enabledPort) {
            $port = $module->usedHAProxyPort();
            if (not exists ($ports{$port})) {
                $ports{$port}->{isSSL} = undef;
                $ports{$port}->{services} = [];
            }
            $service->{isDefault} = $row->valueByName('defaultPort');
            $service->{targetPort} = $module->targetHAProxyPort();
            push (@{$ports{$port}->{services}}, $service);
        }

        my $enabledSSLPort = $module->isSSLPortEnabledInHAProxy();
        my $sslPort = undef;
        if ($enabledSSLPort) {
            $sslPort = $module->usedHAProxySSLPort();
            if (not exists ($ports{$sslPort})) {
                $ports{$sslPort}->{isSSL} = 1;
                $ports{$sslPort}->{services} = [];
            }
            $service->{isDefault} = $row->valueByName('defaultSSLPort');
            $service->{pathSSLCert} = $module->pathHAProxySSLCertificate();
            $service->{targetPort} = $module->targetHAProxySSLPort();
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

# Method: setHAProxyServicePorts
#
#   Sets the given ports as the ones to be used for the service module provided.
#
# Parameters:
#
#   args - Named parameters:
#       modName        - The module name that handles the service
#       port           - The port where this service should listen for connections or undef.
#       enablePort     - Whether this service's non SSL port should be enabled.
#       defaultPort    - Wehther this service's non SSL port should be the default.
#       sslPort        - The SSL port where this service should listen for connections or undef.
#       enableSSLPort  - Whether this service's SSL port should be enabled.
#       defaultSSLPort - Wehther this service's SSL port should be the default.
#       force          - Whether this service ports should be used even if are set as used elsewhere.
#
sub setHAProxyServicePorts
{
    my ($self, %args) = @_;

    my $services = $self->model('HAProxyServices');
    $services->setServicePorts(%args);
}

# Method: updateServicePorts
#
#   Adds or updates Zentyal's service to point to the given ports.
#
# Parameters:
#
#   modName - The module name that handles the service.
#   ports   - A list reference of ports to be handled by this service.
#
sub updateServicePorts
{
    my ($self, $modName, $ports) = @_;

    my $global = $self->global();
    if ($global->modExists('services')) {
        my $servicesMod = $global->modInstance('services');
        my $module = $global->modInstance($modName);

        my @servicePorts = ();
        foreach my $port (@{$ports}) {
            EBox::Validate::checkPort($port, __("port"));

            my $servicePort = {
                protocol        => 'tcp',
                sourcePort      => 'any',
                destinationPort => $port
            };

            push(@servicePorts, $servicePort);
        }

        my $readOnly = 0;
        if ($modName eq 'webadmin') {
            $readOnly = 1;
        }
        my $serviceName = "zentyal_$modName";
        my @serviceParams = ();
        push (@serviceParams, name          => $serviceName);
        push (@serviceParams, printableName => $module->printableName());
        push (@serviceParams, description   => $module->printableName());
        push (@serviceParams, services      => \@servicePorts);
        push (@serviceParams, internal      => 1);
        push (@serviceParams, readOnly      => $readOnly);
        push (@serviceParams, allowEmpty    => 1);

        if ($servicesMod->serviceExists(name => $serviceName)) {
            # The service already exists, we just update it.
            $servicesMod->setMultipleService(@serviceParams);
        } else {
            # Add the new internal service.
            $servicesMod->addMultipleService(@serviceParams);
            if ($global->modExists('firewall')) {
                # Allow access from the internal networks to this service by default.
                my $firewallMod = $global->modInstance('firewall');
                $firewallMod->setInternalService($serviceName, 'accept');
            }
        }
    }
}

# Method: initialSetup
#
# Overrides:
#
#   <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    my $redis = $self->redis();

    # Migrate the existing zentyal service definition to follow the new layout handled by HAProxy.
    my @servicesKeys = $redis->_keys('services/*/ServiceTable/keys/*');
    foreach my $key (@servicesKeys) {
        my $value = $redis->get($key);
        unless (ref $value eq 'HASH') {
            next;
        }
        unless ((defined $value->{internal}) and $value->{internal}) {
            next;
        }
        if ($value->{name} eq 'administration') {
            # WebAdmin.
            my $webadminMod = $self->global()->modInstance('webadmin');
            $value->{name} = 'zentyal_' . $webadminMod->name();
            $value->{printableName} = $webadminMod->printableName(),
            $value->{description} = $webadminMod->printableName(),
            $redis->set($key, $value);
        } elsif ($value->{name} eq 'webserver') {
            # WebServer.
            my $webserverMod = $self->global()->modInstance('webserver');
            $value->{name} = 'zentyal_' . $webserverMod->name();
            $value->{printableName} = $webserverMod->printableName(),
            $value->{description} = $webserverMod->printableName(),
            $redis->set($key, $value);
        }

    }
}

1;
