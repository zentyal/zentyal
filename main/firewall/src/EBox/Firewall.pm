# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::Firewall;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::ObjectsObserver
            EBox::NetworkObserver
            EBox::LogObserver);

use EBox::Objects;
use EBox::Global;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Firewall::Model::ToInternetRuleTable;
use EBox::Firewall::Model::InternalToEBoxRuleTable;
use EBox::Firewall::Model::ExternalToEBoxRuleTable;
use EBox::Firewall::Model::EBoxOutputRuleTable;
use EBox::Firewall::Model::ExternalToInternalRuleTable;
use EBox::Firewall::Model::EBoxServicesRuleTable;
use EBox::Firewall::Model::RedirectsTable;

use EBox::Firewall::Model::PacketTrafficDetails;
use EBox::Firewall::Model::PacketTrafficGraph;
use EBox::Firewall::Model::PacketTrafficReportOptions;


use EBox::FirewallLogHelper;
use EBox::Gettext;

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
    $self->{'PacketTrafficDetails'} = $self->model('PacketTrafficDetails');
    $self->{'PacketTrafficGraph'} = $self->model('PacketTrafficGraph');
    $self->{'PacketTrafficReportOptions'} = $self->model('PacketTrafficReportOptions');

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
        $self->setInternalService('administration', 'accept');
        $self->setInternalService('ssh', 'accept');

        my $services = EBox::Global->modInstance('services');
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

    return ['services'];
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
    if($self->isEnabled()) {
        $ipt->start();
    } else {
        $ipt->stop();
    }
}

sub _stopService
{
    my ($self) = @_;

    use EBox::Iptables;
    my $ipt = new EBox::Iptables;
    $ipt->stop();
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
#       Checks if a port is available, i.e: it's not used by any module.
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
sub availablePort # (proto, port, interface)
{
    my ($self, $proto, $port, $iface) = @_;
    defined($proto) or return undef;
    ($proto ne "") or return undef;
    defined($port) or return undef;
    ($port ne "") or return undef;
    my $global = EBox::Global->getInstance($self->isReadOnly());
    my $network = $global->modInstance('network');
    my $services = $global->modInstance('services');

    # if it's an internal interface, check all services
    unless ($iface &&
            ($network->ifaceIsExternal($iface) || $network->vifaceExists($iface))) {
        unless ($services->availablePort($proto, $port)) {
            return undef;
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
            ($red->valueByName('external_port') eq $port) and return undef;
        }
    }

    my @mods = @{$global->modInstances()};
    foreach my $mod (@mods) {
        $mod->can('usesPort') or
            next;
        if ($mod->usesPort($proto, $port, $iface)) {
            return undef;
        }
    }
    return 1;
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

    my $serviceMod = EBox::Global->modInstance('services');

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
                                        'text' => $self->printableName(),
                                        'separator' => 'Gateway',
                                        'order' => 310);

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

    my $servicesMod = EBox::Global->modInstance('services');

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

    my $serviceMod = EBox::Global->modInstance('services');

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

            'consolidate' => $self->_consolidate(),
           }];
}


sub _consolidate
{
    my ($self) = @_;

    my $table = 'firewall_packet_traffic';
    my $spec = {
                filter      => sub {
                    my ($row_r) = @_;
                    return $row_r->{event} eq 'drop'
                },
                accummulateColumns => { drop => 0  },
                consolidateColumns => {
                                       event   => {
                                            conversor => sub { return 1 },
                                            accummulate => sub {
                                                my ($v) = @_;
                                                if ($v eq 'drop') {
                                                    return 'drop';
                                                }


                                            },
                                        },
                                      }
               };

    return {  $table => $spec };

}


sub logHelper
{
    my ($self) = @_;

    return (new EBox::FirewallLogHelper);
}

# sub consolidateReportQueries
# {
#     return [
#         {
#             'target_table' => 'firewall_report',
#             'query' => {
#                 'select' => 'event, fw_src AS source, fw_proto AS proto, fw_dpt AS dport, COUNT(event) AS packets',
#                 'from' => 'firewall',
#                 'group' => 'event, source, proto, dport'
#             }
#         }
#     ];
# }

# sub report
# {
#     my ($self, $beg, $end, $options) = @_;

#     my $report = {};

#     my $db = EBox::DBEngineFactory::DBEngine();

#     $report->{'dropped_packets'} = $self->runMonthlyQuery($beg, $end, {
#         'select' => 'event, SUM(packets) AS packets',
#         'from' => 'firewall_report',
#         'where' => "event = 'drop'",
#         'group' => 'event',
#     }, { 'key' => 'event' } );

#     $report->{'top_dropped_sources'} = $self->runQuery($beg, $end, {
#         'select' => 'source, SUM(packets) AS packets',
#         'from' => 'firewall_report',
#         'where' => "event = 'drop'",
#         'group' => 'source',
#         'limit' => $options->{'max_dropped_sources'},
#         'order' => 'packets DESC'
#     });

#     return $report;
# }

1;
