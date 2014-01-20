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

# Method: checkServicePort
#
#   Check whether a given port is being used outside HAProxy.
#
# Parameters:
#
#   port    - The port we want to check for usage.
#
sub checkServicePort
{
    my ($self, $port) = @_;

    my $haproxyPorts = $self->ports();

    if (exists $haproxyPorts->{$port}) {
        # It's a port handled by haproxy, we accept it.
        return;
    }

    my $global = $self->global();
    my $firewallMod = $global->modInstance('firewall');
    if (defined $firewallMod) {
        unless ($firewallMod->availablePort("tcp", $port)) {
            throw EBox::Exceptions::External(__x(
                'Zentyal is already configured to use port {p} for another service. Choose another port or free it and retry.',
                p => $port
            ));
        }
    }

    my $netstatLines = EBox::Sudo::root('netstat -tlnp');
    foreach my $line (@{ $netstatLines }) {
        my ($proto, $recvQ, $sendQ, $localAddr, $foreignAddr, $state, $PIDProgram) = split '\s+', $line, 7;
        if ($localAddr =~ m/:$port$/) {
            my ($pid, $program) = split '/', $PIDProgram;
            throw EBox::Exceptions::External(__x(
                q{Port {p} is already in use by program '{pr}'. Choose another port or free it and retry.},
                p => $port,
                pr => $program,
            ));
        }
    }
}

# Method: setServicePorts
#
#   Sets the given ports as the ones to be used for the service module provided.
#
# Parameters:
#
#   modName - The module name that handles the service
#   port    - The port where this service should listen for connections or undef.
#   sslPort - The SSL port where this service should listen for connections or undef.
#   enable  - Whether this service should be enabled.
#   force   - Whether this service ports should be used even if are set as used elsewhere.
#
sub setServicePorts
{
    my ($self, $modName, $port, $sslPort, $enable, $force) = @_;

    unless ($force) {
        $self->checkServicePort($port) if ($port);
        $self->checkServicePort($sslPort) if ($sslPort);
    }

    my $module = $self->global()->modInstance($modName);
    my $services = $self->model('Services');
    my $moduleRow = $services->find(serviceId => $module->HAProxyServiceId());

    if (defined $moduleRow) {
        if ($module->blockHAProxyPort()) {
            if (defined $port) {
                EBox::error("Tried to set the HTTP port of '$modName' to '$port' but it's not editable");
            }
        } else {
            my $port = $moduleRow->elementByName('port');
            $port->setValue($port);
        }
        if ($module->blockHAProxySSLPort()) {
            if (defined $sslPort) {
                EBox::error("Tried to set the HTTPS port of '$modName' to '$sslPort' but it's not editable");
            }
        } else {
            my $sslPort = $moduleRow->elementByName('sslPort');
            $sslPort->setValue($sslPort);
        }
        $moduleRow->store();
    } else {
        # There isn't yet a definition for the module Service, we add it now.
        if ($module->blockHAProxyPort()) {
            if (defined $port) {
                EBox::error("Tried to set the HTTP port of '$modName' to '$port' but it's not editable");
            }
            $port = $module->defaultHAProxyPort();
        }
        if ($module->blockHAProxySSLPort()) {
            if (defined $sslPort) {
                EBox::error("Tried to set the HTTPS port of '$modName' to '$sslPort' but it's not editable");
            }
            $sslPort = $module->defaultHAProxySSLPort();
        }

        $services->add(
            module        => $module->name(),
            serviceId     => $module->HAProxyServiceId(),
            service       => $module->printableName(),
            port          => $port,
            blockPort     => $module->blockHAProxyPort(),
            sslPort       => $sslPort,
            blockSSLPort  => $module->blockHAProxySSLPort(),
            canBeDisabled => $module->allowDisableHAProxyService(),
            enable        => $enable);
    }

    $self->updateServicePorts($modName, [$port, $sslPort]);
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
        my $services = $global->modInstance('services');
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

        if (@servicePorts) {
            $services->setMultipleService(
                'name'          => "zentyal_$modName",
                'printableName' => $module->printableName(),
                'description' => __x('{modName} Web Server', modName => $module->printableName()),
                'services' => \@servicePorts,
                'internal' => 1,
                'readOnly' => 1
            );
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
    my $key = 'webadmin/conf/AdminPort/keys/form';
    my $value = $redis->get($key);
    unless ($value) {
        # Fallback to the 'ro' version.
        $key = 'webadmin/ro/AdminPort/keys/form';
        $value = $redis->get($key);
    }
    if ($value) {
        if (defined $value->{port}) {
            # There are keys to migrate...
            $self->setServicePorts('webadmin', undef, $value->{port}, 1, 1);
        }

        my @keysToRemove = ('webadmin/conf/AdminPort/keys/form', 'webadmin/ro/AdminPort/keys/form');
        $redis->unset(@keysToRemove);
    }

    # Migrate the webadmin zentyal's service definition to follow the new layout.
    my $webadminMod = $self->global()->modInstance('webadmin');
    my @servicesKeys = $redis->_keys('services/*/ServiceTable/keys/*');
    foreach my $key (@servicesKeys) {
        my $value = $redis->get($key);
        unless (ref $value eq 'HASH') {
            next;
        }
        unless ((defined $value->{internal}) and $value->{internal} and
                (defined $value->{readOnly}) and $value->{readOnly}) {
            next;
        }
        if ($value->{name} eq 'administration') {
            $value->{name} = 'zentyal_' . $webadminMod->name();
            $value->{printableName} = $webadminMod->printableName(),
            $value->{description} = __x('{modName} Web Server', modName => $webadminMod->printableName()),
            $redis->set($key, $value);
        }
    }
}

1;
