# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

use base qw(EBox::GConfModule 
                EBox::ObjectsObserver 
                EBox::NetworkObserver
                EBox::LogObserver
                EBox::Model::ModelProvider
                EBox::ServiceModule::ServiceInterface
                EBox::Model::CompositeProvider
                );

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
use EBox::Firewall::Model::RedirectsTable;

use EBox::Firewall::Model::Report::PacketTrafficDetails;
use EBox::Firewall::Model::Report::PacketTrafficGraph;
use EBox::Firewall::Model::Report::PacketTrafficReportOptions;


use EBox::FirewallLogHelper;
use EBox::Order;
use EBox::Gettext;

sub _create
{
    my $class = shift;
    my $self =$class->SUPER::_create(
                                     name => 'firewall',
                                     domain => 'ebox-firewall',
                                     printableName => __('firewall'),
                                     @_);
    $self->{'ToInternetRuleModel'} = 
        new EBox::Firewall::Model::ToInternetRuleTable(
                                                       'gconfmodule' => $self,
                                                       'directory' => 'ToInternetRuleTable',
                                                      );

    $self->{'InternalToEBoxRuleModel'} = 
        new EBox::Firewall::Model::InternalToEBoxRuleTable(
                                                           'gconfmodule' => $self,
                                                           'directory' => 'InternalToEBoxRuleTable',
                                                          );

    $self->{'ExternalToEBoxRuleModel'} = 
        new EBox::Firewall::Model::ExternalToEBoxRuleTable(
                                                           'gconfmodule' => $self,
                                                           'directory' => 'ExternalToEBoxRuleTable',
                                                          );

    $self->{'EBoxOutputRuleModel'} = 
        new EBox::Firewall::Model::EBoxOutputRuleTable(
                                                       'gconfmodule' => $self,
                                                       'directory' => 'EBoxOutputRuleTable',
                                                      );
    $self->{'ExternalToInternalRuleTable'} = 
        new EBox::Firewall::Model::ExternalToInternalRuleTable(
                                                               'gconfmodule' => $self,
                                                               'directory' => 'ExternalToInternalRuleTable',
                                                              );
    $self->{'RedirectsTable'} = 
        new EBox::Firewall::Model::RedirectsTable(
                                                     'gconfmodule' => $self,
                                                     'directory' => 'RedirectsTable',
                                                    );


    $self->{'PacketTrafficDetails'} = new EBox::Firewall::Model::Report::PacketTrafficDetails (
                                                                                               'gconfmodule' => $self,
                                                                                               'directory' => 'PacketTrafficDetails',
                                                                                              );

    $self->{'PacketTrafficGraph'} = new EBox::Firewall::Model::Report::PacketTrafficGraph (
                                                                                           'gconfmodule' => $self,
                                                                                           'directory' => 'PacketTrafficGraph',
                                                                                          );

    $self->{'PacketTrafficReportOptions'} = new EBox::Firewall::Model::Report::PacketTrafficReportOptions (
                                                                                                           'gconfmodule' => $self,
                                                                                                           'directory' => 'PacketTrafficReportOptions',
                                                                                                          );



                                                 

    bless($self, $class);
    return $self;
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    return [ 
        {
                'action' => __('Flush previous firewall rules'),
                'reason' => __('The eBox firewall will flush any previous firewall '
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

#  Method: serviceModuleName
#
#   Override EBox::ServiceModule::ServiceInterface::servivceModuleName
#
sub serviceModuleName
{
    return 'firewall';
}

#  Method: enableModDepends
#
#   Override EBox::ServiceModule::ServiceInterface::enableModDepends
#
sub enableModDepends 
{
    return ['network'];
}

# Method: models
#
#      Overrides <EBox::Model::ModelProvider::models>
#
sub models 
{
    my ($self) = @_;

    return [
            $self->{'ToInternetRuleModel'},
            $self->{'InternalToEBoxRuleModel'},
            $self->{'ExternalToEBoxRuleModel'},
            $self->{'EBoxOutputRuleModel'},
            $self->{'ExternalToInternalRuleTable'},
            $self->{'RedirectsTable'},

            $self->{'PacketTrafficDetails'},
            $self->{'PacketTrafficGraph'},
            $self->{'PacketTrafficReportOptions'},
           ];
}




sub compositeClasses
{
    return [
            'EBox::Firewall::Composite::Report::PacketTrafficReport',
           ]
}

# Method: _exposedMethods
#
# Overrides:
#
#      <EBox::Model::ModelProvider::_exposedMethods>
#
sub _exposedMethods
{
    my %exposedMethods = (
                addOutputService => { 
                            action => 'add',
                            path   => [ 'EBoxOutputRuleTable' ] 
                        },
                removeOutputService => { 
                            action => 'del',
                            path   => [ 'EBoxOutputRuleTable' ],
                            indexes => [ 'id' ]
                        },
                getOutputService => { 
                            action  => 'get',
                            path    => [ 'EBoxOutputRuleTable' ],
                            indexes => [ 'position' ],
                        },
            );

    return \%exposedMethods;

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

sub _supportsActions
{
    return undef;
}

sub _regenConfig
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


#
# Method: denyAction 
#
#       Returns the deny action
#
# Returns:
#
#       string - holding the deny action, DROP or REJECT
#
sub denyAction
{
    my ($self) = @_;
    return $self->get_string("deny");
}

#
# Method: setDenyAction 
#
#       Sets the deny action
#
# Parameters:
#
#       action - 'DROP' or 'REJECT'
#   
# Exceptions:
#
#       InvalidData - action not valid
#
sub setDenyAction # (action) 
{
    my ($self, $action) = @_;
    if ($action ne "DROP" && $action ne "REJECT") {
                throw EBox::Exceptions::InvalidData('data' => __('action'),
                                                    'value' => $action);
            } elsif ($action eq $self->denyAction()) {
                return;
            }
        $self->set_string("deny", $action);
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
    foreach my $row (@{$model->rows()}) {
        if ($row->valueByName('interface') eq $iface) {
            $model->removeRow($row->id());
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
    my $global = EBox::Global->getInstance();
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
    my $redirs = $self->{'RedirectsTable'}->rows();
    foreach my $ifc (@ifaces) {
        foreach my $red (@{$redirs}) {
            ($red->valueByName('protocol') eq $proto) or next;
            ($red->valueByName('interface') eq $ifc) or next;
            ($red->valueByName('external_port') eq $port) and return undef;
        }
    }

    my @mods = @{$global->modInstancesOfType('EBox::FirewallObserver')};
    foreach my $mod (@mods) {
        if ($mod->usesPort($proto, $port, $iface)) {
            return undef;
        }
    }
    return 1;
}

#
# Method: localRedirects
#
#       Returns a list of local redirections
#
# Returns:
#       
#       array ref - holding the local redirections
#
sub localRedirects
{
    my ($self) = @_;
    return $self->array_from_dir("localredirects");
}

#
# Method: addLocalRedirect
#
#       Adds a local redirection. Packets directed at certain port to
#       the local machine are redirected to the given port
#
# Parameters:
#       
#       service - string: name of a service to redirect packets
#       port - port to redirect from 
#
#
sub addLocalRedirect # (service, port) 
{
    my ($self, $name, $port) = @_;
    checkName($name) or throw EBox::Exceptions::Internal(
                                __x("Name '{name}' is invalid", name => $name));
    checkPort($port, __("port"));

    my $protocol = $self->serviceProtocol($name);
    ($protocol && $protocol ne "") or 
        throw EBox::Exceptions::Internal("Unknown service: $name");
    
    my @redirects = $self->all_dirs("localredirects");
    foreach (@redirects) {
        my $tmpsrv = $self->get_string("$_/service");
        if ($tmpsrv eq $name) {
            if ($self->get_int("$_/port") eq $port) {
                return;
            } else {
                next;
            }
        }
        my $tmpproto = $self->serviceProtocol($tmpsrv);
        ($tmpproto eq $protocol) or next;
        if ($self->get_int("$_/port") eq $port) {
            throw EBox::Exceptions::Internal
                ("Port $port already redirected to service $tmpsrv");
                }
    }
    
    my $id = $self->get_unique_id("r","localredirects");
    
    $self->set_string("localredirects/$id/service", $name);
    $self->set_int("localredirects/$id/port", $port);
}

#
# Method: removeLocalRedirects 
#
#       Removes all local redirections for a service
#
# Parameters:
#       
#       service - string: name of a service to remove local redirections 
#
#
sub removeLocalRedirects # (service) 
{
    my ($self, $name) = @_;
    checkName($name) or throw EBox::Exceptions::Internal(
                                __x("Name '{name}' is invalid", name => $name));

    my @redirects = $self->all_dirs("localredirects");
    foreach (@redirects) {
        if ($self->get_string("$_/service") eq $name) {
            $self->delete_dir("$_");
        }
    }
}

#
# Method: removeLocalRedirect 
#
#       Removes a local redirection for a service
#
# Parameters:
#       
#       service - string: name of a service to remove local redirections 
#
#
sub removeLocalRedirect # (service, port) 
{
    my ($self, $name, $port) = @_;
    checkName($name) or throw EBox::Exceptions::Internal(
                                __x("Name '{name}' is invalid", name => $name));

    my @redirects = $self->all_dirs("localredirects");
    foreach (@redirects) {
        ($self->get_string("$_/service") eq $name) or next;
        ($self->get_int("$_/port") eq $port) or next;
        $self->delete_dir("$_");
    }
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
    foreach my $row (@{$model->rows()}) {
        if ($row->valueByName('interface') eq $iface) {
            return 1;
        }
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
}

#
# Method: OutputRules
#
#       Returns the output rules
#
# Return:
#
#       array ref - each element contains the following elements:
#            - protocol - string: protocol (tcp|udp)
#            - port - string: port number
sub OutputRules
{
    my ($self) = @_;
    return $self->array_from_dir("rules/output");
}

# Method: removeOutputRule
#
#       Removes an output rule
#
# Parameters:
#
#       protocol - string: protocol (tcp|udp)
#       port - string: port number
#
# Returns:
#
#       boolean - true if it's deleted, otherwise undef
sub removeOutputRule # (protocol, port)
{
    my ($self, $protocol, $port) = @_;

    checkProtocol($protocol, __("protocol"));
    checkPort($port, __("port"));
    
    my @rules = $self->all_dirs("rules/output");
    foreach (@rules) {
        ($self->get_string("$_/protocol") eq $protocol) or next;
        ($self->get_int("$_/port") eq $port) or next;
        $self->delete_dir($_);
        return 1;
    }
    return;
}

# Method: addOutputRule 
#
#       Removes an output rule
#
# Parameters:
#
#       protocol - string: protocol (tcp|udp)
#       port - string: port number
sub addOutputRule # (protocol, port) 
{
    my ($self, $protocol, $port) = @_;
    
    checkProtocol($protocol, __("protocol"));
    checkPort($port, __("port"));
    
    $self->removeOutputRule($protocol, $port);
    
    my $id = $self->get_unique_id("r","rules/output");
    
    $self->set_string("rules/output/$id/protocol", $protocol);
    $self->set_int("rules/output/$id/port", $port);
}

# Method: setInternalService
#
#   This method adds a rule to the "internal networks to eBox services"
#   table.
#
#   In case the service has already been configured with a custom
#   rule by the user the adding operation is aborted.
#
#   Modules configuring internal services running on eBox should use
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
#   This method adds a rule to the "external networks to eBox services"
#   table.
#
#   In case the service has already been configured with a custom
#   rule by the user the adding operation is aborted.
#
#   Modules configuring internal services running on eBox should use
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
#   introduced into the eBox log DB.
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
                                        'text' => __('Firewall'),
                                        'order' => 4);
    
    $folder->add(new EBox::Menu::Item('url' => 'Firewall/Filter',
                                      'text' => __('Packet Filter')));
    
    $folder->add(new EBox::Menu::Item('url' => 'Firewall/View/RedirectsTable',
                                      'text' => __('Redirects')));
    
    $root->add($folder);
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
        
    my $events = { 'drop' => __('DROP'), 'log' => __('LOG') };

    return [{
            'name' => __('Firewall'),
            'index' => 'firewall',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'firewall',
            'timecol' => 'timestamp',
            'filter' => ['fw_in', 'fw_out', 'fw_src', 
                         'fw_dst', 'fw_proto', 'fw_spt', 'fw_dpt'],
            'events' => $events,
            'eventcol' => 'event',
            'disabledByDefault' => 1,

            consolidate => $self->_consolidate(),
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


1;
