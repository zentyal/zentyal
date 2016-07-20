# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Firewall;

use base qw(EBox::Module::Service
            EBox::Objects::Observer
            EBox::NetworkObserver
            EBox::LogObserver);

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;
use EBox::Global;
use EBox::Firewall::Model::ToInternetRuleTable;
use EBox::Firewall::Model::InternalToEBoxRuleTable;
use EBox::Firewall::Model::ExternalToEBoxRuleTable;
use EBox::Firewall::Model::EBoxOutputRuleTable;
use EBox::Firewall::Model::ExternalToInternalRuleTable;
use EBox::Firewall::Model::EBoxServicesRuleTable;
use EBox::Firewall::Model::RedirectsTable;

use EBox::FirewallLogHelper;
use EBox::Validate qw( :all );
use EBox::Util::Lock;
use TryCatch;

# Time in sec. to be blocked to work on iptables
use constant BLOCKED_TIMEOUT => 10;

sub _create
{
    my $class = shift;
    my $self =$class->SUPER::_create(name => 'firewall',
                                     printableName => __('Firewall'),
                                     @_);

    $self->{'ToInternetRuleModel'} = $self->model('ToInternetRuleTable');
    $self->{'InternalToEBoxRuleModel'} = $self->model('InternalToEBoxRuleTable');
    $self->{'ExternalToEBoxRuleModel'} = $self->model('ExternalToEBoxRuleTable');
    $self->{'EBoxOutputRuleModel'} = $self->model('EBoxOutputRuleTable');
    $self->{'ExternalToInternalRuleTable'} = $self->model('ExternalToInternalRuleTable');
    $self->{'EBoxServicesRuleTable'} = $self->model('EBoxServicesRuleTable');
    $self->{'RedirectsTable'} = $self->model('RedirectsTable');

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
                'action' => __('Flush previous firewall rules'),
                'reason' => __('The Zentyal firewall will flush any previous firewall '
                               . 'rules which have been added manually or by another tool'),
                'module' => 'firewall'
        },
        {
                'action' => __('Secure by default'),
                'reason' => __('Just a few connections are allowed by default. ' .
                               'Make sure you add the proper incoming and outcoming ' .
                               'rules to make your system work as expected. Usually, ' .
                               'all outcoming connections are denied by default, and ' .
                               'only SSH and HTTPS incoming connections are allowed.'),
                'module' => 'firewall'

        }
        ];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules only if installing the first time
    unless ($version) {
        $self->setInternalService('zentyal_webadmin', 'accept');
        $self->setInternalService('ssh', 'accept');

        my $services = EBox::Global->modInstance('network');
        my $any = $services->serviceId('any');

        unless (defined $any) {
            EBox::error('Cannot add default rules: Service "any" not found.');
            return;
        }

        # Allow any Zentyal output by default
        $self->model('EBoxOutputRuleTable')->add(
            decision => 'accept',
            destination =>  { destination_any => undef },
            service => $any,
        );

        # Allow any Internet access from internal networks
        $self->model('ToInternetRuleTable')->add(
            decision => 'accept',
            source => { source_any => undef },
            destination =>  { destination_any => undef },
            service => $any,
        );
    }
}

sub restoreDependencies
{
    my ($self) = @_;

    return ['network'];
}

# utility used by CGI

sub externalIfaceExists
{
    my $network = EBox::Global->modInstance('network');
    my $externalIfaceExists = @{$network->ExternalIfaces()  } > 0;

    return $externalIfaceExists;
}

## internal utility functions

sub _checkAction # (action, name?)
{
    my ($i, $name) = @_;

    if ($i eq "allow" || $i eq "deny") {
        return 1;
    }

    if (defined($name)) {
        throw EBox::Exceptions::InvalidData('data' => $name,
                                                    'value' => $i);
    } else {
        return 0;
    }
}

## api functions
sub isRunning
{
    my ($self) = @_;
    return $self->isEnabled();
}

sub _supportActions
{
    return undef;
}

sub _enforceServiceState
{
    my ($self) = @_;
    use EBox::Iptables;
    my $ipt = new EBox::Iptables;

    EBox::Util::Lock::lock('iptables', 1, BLOCKED_TIMEOUT);
    try {
        my @helpers = ();
        if ($self->isEnabled()) {
            foreach my $mod (@{ $self->global()->modInstancesOfType('EBox::FirewallObserver') }) {
                if (not $mod->configured() and not $mod->isEnabled()) {
                    next;
                }
                my $helper = $mod->firewallHelper();
                if ($helper) {
                    $helper->beforeFwRestart();
                    push(@helpers, $helper);
                }
            }
            $ipt->start();
            foreach my $helper (@helpers) {
                $helper->afterFwRestart();
            }
        } else {
            $ipt->stop();
        }
    } catch ($e) {
        EBox::error("Error restarting firewall: $e");
    }
    EBox::Util::Lock::unlock('iptables');
}

sub _stopService
{
    my ($self) = @_;

    use EBox::Iptables;
    EBox::Util::Lock::lock('iptables', 1, BLOCKED_TIMEOUT);
    try {
        my $ipt = new EBox::Iptables;
        $ipt->stop();
    } catch {
    }
    EBox::Util::Lock::unlock('iptables');
}

# Method: removePortRedirectionsOnIface
#
#       Removes all the port redirections on a given interface
#
# Parameters:
#
#       iface - network intercace
#
sub removePortRedirectionsOnIface # (interface)
{
    my ($self, $iface) = @_;

    my $model = $self->{'RedirectsTable'};
    foreach my $rowId (@{$model->ids()}) {
        my $row = $model->row($rowId);
        if ($row->valueByName('interface') eq $iface) {
            $model->removeRow($rowId);
        }
    }
}

# Method: availablePort
#
#       Checks if a port is not configured to be used by any service
#
# Parameters:
#
#       proto - protocol
#       port - port number
#       interface - interface
#
# Returns:
#
#       boolean - true if it's available, otherwise undef
#
# Note:
#    portUsedByService returns the information of what is using the port
sub availablePort
{
    my ($self, $proto, $port, $iface) = @_;
    return not $self->portUsedByService($proto, $port, $iface);
}


# Method: portUsedByService
#
#       Checks if a port is configured to be used by a service
#
# Parameters:
#
#       proto - protocol
#       port - port number
#       interface - interface
#
# Returns:
#
#       false - if it is not used not empty string - if it is in use, the string
#               contains the name of what is using it
sub portUsedByService
{
   my ($self, $proto, $port, $iface) = @_;
    defined($proto) or return undef;
    ($proto ne "") or return undef;
    defined($port) or return undef;
    ($port ne "") or return undef;
    my $global = EBox::Global->getInstance($self->isReadOnly());
    my $network = $global->modInstance('network');
    my $services = $network;

    # if it's an internal interface, check all services
    unless ($iface &&
            ($network->ifaceIsExternal($iface) || $network->vifaceExists($iface))) {
        my $used = $services->portUsedByService($proto, $port);
        if ($used) {
            return $used;
        }
    }

    # check for port redirections on the interface, on all internal ifaces
    # if its
    my @ifaces = ();
    if ($iface) {
        push(@ifaces, $iface);
    } else {
        my $tmp = $network->InternalIfaces();
        @ifaces = @{$tmp};
    }
    my $redirs = $self->{'RedirectsTable'}->ids();
    foreach my $ifc (@ifaces) {
        foreach my $id (@{$redirs}) {
            my $red = $self->{'RedirectsTable'}->row($id);
            ($red->valueByName('protocol') eq $proto) or next;
            ($red->valueByName('interface') eq $ifc) or next;
            ($red->valueByName('external_port') eq $port) and
                return __('port redirections');
        }
    }

    my @mods = @{$global->modInstances()};
    foreach my $mod (@mods) {
        $mod->can('usesPort') or
            next;
        if ($mod->usesPort($proto, $port, $iface)) {
            return $mod->printableName();
        }
    }

    return 0;
}

# Method: requestAvailablePort
#
#       Returns the same requested port if available or the next
#       available one if not.
#
# Parameters:
#
#       protocol     - requested port protocol
#       port         - requested port number
#       alternative  - *optional* alternative port if preferred is not available
#
sub requestAvailablePort
{
    my ($self, $protocol, $port, $alternative) = @_;

    # Check port availability
    my $available = 0;
    do {
        $available = $self->availablePort($protocol, $port);
        unless ($available) {
            if (defined ($alternative)) {
                $port = $alternative;
                $alternative = undef;
            } else {
                $port++;
            }
        }
    } until ($available);

    return $port;
}

# Method: usesIface
#
#       Implements EBox::NetworkObserver interface.
#
#
sub usesIface # (iface)
{
    my ($self, $iface) = @_;

    my $model = $self->{'RedirectsTable'};
    foreach my $rowId (@{$model->ids()}) {
        my $row = $model->row($rowId);
        if ($row->valueByName('interface') eq $iface) {
            return 1;
        }
    }

    my $snatModel = $self->model('SNAT');
    if ($snatModel->usesIface($iface)) {
        return 1;
    }

    return undef;
}

# Method: ifaceMethodChanged
#
#       Implements EBox::NetworkObserver interface.
#
#
sub ifaceMethodChanged # (iface, oldmethod, newmethod)
{
    my ($self, $iface, $oldm, $newm) = @_;

    ($newm eq 'static') and return undef;
    ($newm eq 'dhcp') and return undef;

    return $self->usesIface($iface);
}

# Method: vifaceDelete
#
#       Implements EBox::NetworkObserver interface.
#
#
sub vifaceDelete # (iface, viface)
{
    my ($self, $iface, $viface) = @_;
    return $self->usesIface("$iface:$viface");
}

# Method: freeIface
#
#       Implements EBox::NetworkObserver interface.
#
#
sub freeIface # (iface)
{
    my ($self, $iface) = @_;
    $self->removePortRedirectionsOnIface($iface);
    $self->model('SNAT')->freeIface($iface);
}

# Method: freeViface
#
#       Implements EBox::NetworkObserver interface.
#
#
sub freeViface # (iface, viface)
{
    my ($self, $iface, $viface) = @_;
    $self->removePortRedirectionsOnIface("$iface:$viface");
    $self->model('SNAT')->freeViface($iface, $viface);
}

# Method: setInternalService
#
#   This method adds a rule to the "internal networks to Zentyal services"
#   table.
#
#   In case the service has already been configured with a custom
#   rule by the user the adding operation is aborted.
#
#   Modules configuring internal services running on Zentyal should use
#   this method if they wish to allow access from internal networks
#   to the service by default.
#
# Parameters:
#
#   service - service's name
#   decision - accept or deny
#
# Returns:
#
#   boolan - true if the rule has been added, otherwise false and
#            that implies there is already a custom rule
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#   <EBox::Exceptions::DataNotFound>
sub setInternalService
{
    my ($self, $service, $decision) = @_;

    return $self->_setService($service, $decision, 1);
}

# Method: setExternalService
#
#   This method adds a rule to the "external networks to Zentyal services"
#   table.
#
#   In case the service has already been configured with a custom
#   rule by the user the adding operation is aborted.
#
#   Modules configuring internal services running on Zentyal should use
#   this method if they wish to allow access from external networks
#   to the service by default.
#
# Parameters:
#
#   service - service's name
#   decision - accept or deny
#
# Returns:
#
#   boolan - true if the rule has been added, otherwise false and
#            that implies there is already a custom rule
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#   <EBox::Exceptions::DataNotFound>
sub setExternalService
{
    my ($self, $service, $decision) = @_;

    return $self->_setService($service, $decision, 0);
}

sub _setService
{
    my ($self, $service, $decision, $internal) = @_;

    my $serviceMod = EBox::Global->modInstance('network');

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument('service');
    }

    unless (defined($decision)) {
        throw EBox::Exceptions::MissingArgument('decision');
    }

    unless ($decision eq 'accept' or $decision eq 'deny') {
        throw EBox::Exceptions::InvalidData('data' => 'decision',
                        value => $decision, 'advice' => 'accept or deny');
    }

    my $serviceId = $serviceMod->serviceId($service);

    unless (defined($serviceId)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service',
                                             'value' => $service);
    }

    my $model;
    if ($internal) {
        $model = 'InternalToEBoxRuleModel';
    } else {
        $model = 'ExternalToEBoxRuleModel';
    }
    my $rulesModel = $self->{$model};

    # Do not add rule if there is already a rule
    if ($rulesModel->findValue('service' => $serviceId)) {
        EBox::info("Existing rule for $service overrides default rule");
        return undef;
    }

    my %params;
    $params{'decision'} = $decision;
    $params{'source_selected'} = 'source_any';
    $params{'service'} = $serviceId;

    $rulesModel->addRow(%params);

    return 1;
}

# Method: enableLog
#
#   Override <EBox::LogObserver>
#
#
sub enableLog
{
    my ($self, $enable) = @_;

    $self->setLogging($enable);
}

# Method: setLogging
#
#   This method is used to enable/disable the iptables logging facilities.
#
#   When enabled, it will log drop packets to syslog, and they will be
#   introduced into the Zentyal log DB.
#
# Parameters:
#
#   enable - boolean true to enable, false to disable
#
sub setLogging
{
    my ($self, $enable) = @_;

    if ($enable xor $self->logging()) {
        $self->set_bool('logging', $enable);
    }
}

# Method: logging
#
#   This method is used to fetch the logging status which is set by the user
#
#
# Returns:
#
#   boolean true to enable, false to disable
#
sub logging
{
    my ($self) = @_;

    return  $self->get_bool('logging');
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Firewall',
                                        'icon' => 'firewall',
                                        'text' => $self->printableName(),
                                        'tag' => 'main',
                                        'order' => 7);

    $folder->add(new EBox::Menu::Item('url' => 'Firewall/Filter',
                                      'text' => __('Packet Filter')));

    $folder->add(new EBox::Menu::Item('url' => 'Firewall/View/RedirectsTable',
                                      'text' => __('Port Forwarding')));
    $folder->add(new EBox::Menu::Item('url' => 'Firewall/View/SNAT',
                                      'text' => __('SNAT')));

    $root->add($folder);
}

# Method: addInternalService
#
#  Helper method to add new internal services to the service module and related
#  firewall rules
#
#
#  Named Parameters:
#    name - name of the service
#    protocol - protocol used by the service
#    sourcePort - source port used by the service (default : any)
#    destinationPort - destination port used by the service (default : any)
#    target - target for the firewall rule (default: allow)
#
sub addInternalService
{
    my ($self, %params) = @_;
    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');

    $self->_addService(%params);

    my @fwRuleParams = ($params{name});
    push @fwRuleParams, $params{target} if exists $params{target};
    $self->_fwRuleForInternalService(@fwRuleParams);

    $self->saveConfigRecursive();
}

# Method: addServiceRules
#
#  Helper method to add a set of new internal services and
#  the firewall rules associated to them
#
#  Takes as argument an array ref of hashes with the following keys:
#    name             - name of the service
#    protocol         - protocol used by the service
#    sourcePort       - source port used by the service (default : any)
#    destinationPorts - array ref of destination port numbers
#    services         - array ref of hashes with protocol, sourcePort
#                       and destinationPort
#    rules - array ref of tables and decision
#              example: [ 'internal' => 'accept', 'external' => 'deny' ]
#
#  Important: destinationPorts and services are mutually exclusive
#
sub addServiceRules
{
    my ($self, $services) = @_;

    my $servicesMod = EBox::Global->modInstance('network');

    foreach my $service (@{$services}) {
        my $name = $service->{'name'};
        unless ($servicesMod->serviceExists(name => $name)) {
            unless (defined ($service->{'readOnly'})) {
                $service->{'readOnly'} = 1;
            }
            if (exists $service->{'destinationPorts'}) {
                my $protocol = $service->{'protocol'};
                my $sourcePort = $service->{'sourcePort'};
                my @ports;
                foreach my $port (@{$service->{'destinationPorts'}}) {
                    push (@ports, { 'protocol' => $protocol,
                                    'sourcePort' => $sourcePort,
                                    'destinationPort' => $port });
                }
                $service->{'services'} = \@ports;
            }
            $servicesMod->addMultipleService(%{$service});
        }
        my %rules = %{$service->{'rules'}};
        while (my ($table, $decision) = each (%rules)) {
            if ($table eq 'internal') {
                $self->setInternalService($name, $decision);
            } elsif ($table eq 'external') {
                $self->setExternalService($name, $decision);
            } elsif ($table eq 'output') {
                $self->model('EBoxOutputRuleTable')->add(
                        decision => $decision,
                        destination => { destination_any => undef },
                        service => $servicesMod->serviceId($name),
                );
            } elsif ($table eq 'internet') {
                $self->model('ToInternetRuleTable')->add(
                        decision => $decision,
                        source => { source_any => undef },
                        destination =>  { destination_any => undef },
                        service => $servicesMod->serviceId($name),
                );
            }
        }
    }
}

sub _fwRuleForInternalService
{
    my ($self, $service, $target) = @_;

    $service or
        throw EBox::Exceptions::MissingArgument('service');
    $target or
        $target = 'accept';

    $self->setInternalService($service, $target);
}

sub _addService
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{protocol} or
        throw EBox::Exceptions::MissingArgument('protocol');
    exists $params{sourcePort} or
        $params{sourcePort} = 'any';
    exists $params{destinationPort} or
        $params{destinationPort} = 'any';

    my $serviceMod = EBox::Global->modInstance('network');

    if (not $serviceMod->serviceExists('name' => $params{name})) {
        $serviceMod->addService('name' => $params{name},
                'printableName' => $params{printableName},
                'protocol' => $params{protocol},
                'sourcePort' => $params{sourcePort},
                'destinationPort' => $params{destinationPort},
                'description' => $params{description},
                'internal' => 1,
                'readOnly' => 1
                );
    } else {
        $serviceMod->setService('name' => $params{name},
                'printableName' => $params{printableName},
                'protocol' => $params{protocol},
                'sourcePort' => $params{sourcePort},
                'destinationPort' => $params{destinationPort},
                'description' => $params{description},
                'internal' => 1,
                'readOnly' => 1);

        EBox::info(
            "Not adding $params{name} service as it already exists instead");
    }

    $serviceMod->saveConfig();
}

# Impelment LogHelper interface
sub tableInfo
{
    my ($self) = @_ ;

    my $titles = {
                  'timestamp' => __('Date'),
                  'fw_in'     => __('Input interface'),
                  'fw_out'    => __('Output interface'),
                  'fw_src'    => __('Source'),
                  'fw_dst'    => __('Destination'),
                  'fw_proto'  => __('Protocol'),
                  'fw_spt'    => __('Source port'),
                  'fw_dpt'    => __('Destination port'),
                  'event'     => __('Decision')
                 };

    my @order = qw(timestamp fw_in fw_out fw_src fw_dst fw_proto fw_spt fw_dpt event);

    my $events = { 'drop' => __('DROP'), 'log' => __('LOG'), 'redirect' => __('REDIRECT'), };

    return [{
            'name' => __('Firewall'),
            'tablename' => 'firewall',
            'titles' => $titles,
            'order' => \@order,
            'timecol' => 'timestamp',
            'filter' => ['fw_in', 'fw_out', 'fw_src',
                         'fw_dst', 'fw_proto', 'fw_spt', 'fw_dpt'],
            'types' => { 'fw_src' => 'IPAddr', 'fw_dst' => 'IPAddr' },
            'events' => $events,
            'eventcol' => 'event',
            'disabledByDefault' => 1,
           }];
}

sub logHelper
{
    my ($self) = @_;

    return (new EBox::FirewallLogHelper);
}

1;
