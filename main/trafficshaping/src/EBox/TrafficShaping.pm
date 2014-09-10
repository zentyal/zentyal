# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::TrafficShaping
#
#      This Zentyal module is intended to manage traffic shaping rules
#      set by user per real interface. Each rule may represent a bunch
#      of iptables and tc commands to tell the kernel how to manage
#      the traffic flows.
#
#      Current state of developing is the following:
#
#      Shaping (guaranteed, limited and prioriting) traffic per
#      service (protocol/port union), source (IP, MAC, object) and
#      destination (IP, object) on *egress* traffic from every static
#      interface
#
package EBox::TrafficShaping;

use base qw(EBox::Module::Service EBox::NetworkObserver);

######################################
# Dependencies:
# Perl6::Junction package
######################################
use Perl6::Junction qw( any );

use EBox::Gettext;
use EBox::Global;
use EBox::Validate qw( checkProtocol checkPort );
use EBox::Model::Manager;

# Used exceptions
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
# Command wrappers
use EBox::TC;
use EBox::Iptables;

# Concrete builders
use EBox::TrafficShaping::TreeBuilder::Default;
use EBox::TrafficShaping::TreeBuilder::HTB;

# Dependencies
use TryCatch::Lite;
use List::Util;
use Perl6::Junction qw(none);

# Types
use EBox::Types::IPAddr;
use EBox::Types::MACAddr;

# We set rule identifiers among 0100 and FF00
use constant STEP_ID_VALUE => 256; # 0x100
use constant MIN_ID_VALUE  => 768; # 0x300
use constant MAX_ID_VALUE  => 65280; # 0xFF00
use constant MAX_RULE_NUM  => 256; # FF rules
use constant DEFAULT_CLASS_ID => 21;

use constant L7_MODULE => 'ip_conntrack_netlink';

use constant CONF_DIR => EBox::Config::conf() . 'trafficshaping/';
use constant UPSTART_DIR => '/etc/init/';

# Constructor for traffic shaping module
sub _create
  {
    my $class = shift;
    my $self = $class->SUPER::_create(name   => 'trafficshaping',
                                      printableName => __('Traffic Shaping'),
                                      @_);

    bless($self, $class);

    my $global = $self->global();
    $self->{network} = $global->modInstance('network');
    $self->{objects} = $global->modInstance('objects');

    return $self;
  }

sub startUp
{
    my ($self) = @_;

    # Create wrappers
    $self->{tc} = EBox::TC->new();
    $self->{ipTables} = EBox::Iptables->new();
    # Create tree builders
    $self->_createBuilders(regenConfig => 0);

    $self->{'started'} = 1;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
            'action' => __('Add iptables rules to mangle table'),
            'reason' => __('To mark packets with different priorities and rates'),
            'module' => 'trafficshaping'
    },
        {
            'action' => __('Add tc rules'),
            'reason' => __('To implement the traffic shaping rules'),
            'module' => 'trafficshaping'
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

    if (EBox::Util::Version::compare($version, '3.5.1') < 0) {
        $self->_removeL7Rules();
    }
}

# remove deprecated 
sub _removeL7Rules
{
    my ($self) = @_;
    my @rulesModels = ($self->model('ExternalRules'), $self->model('InternalRules'));
    foreach my $model (@rulesModels) {
        my $dir= $model->directory();
        foreach my $id (@{ $model->ids() } ) {
            my $rowKey    = "$dir/keys/$id";
            my $rowValues = $self->get_hash($rowKey);
            my $serviceType = delete $rowValues->{service_selected};
            if ($serviceType) {
                if (($serviceType eq 'service_l7Group') or ($serviceType eq 'service_l7Protocol')) {
                    $model->removeRow($id, 1);
                }  else {
                    # remove deprecated key
                    $self->set_hash($rowKey, $rowValues);
                }
            }
        }
    }
}

# Method: isRunning
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::isRunning>
#
sub isRunning
{
    my ($self) = @_;
    return $self->isEnabled();
}

# Method: _setConf
#
#      Writes the configuration files
#
# Overrides:
#
#      <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $ifaces_ref = $self->_configuredInterfaces();

    foreach my $iface (@{$ifaces_ref}) {
        if ( defined ( $self->{builders}->{$iface} ) ) {
            my $protocols = $self->{builders}->{$iface}->dumpProtocols();
            if (scalar keys %$protocols) {
                # Load kernel module
                $self->_loadL7Module();

                # Write l7 filter configuration
                my @params = ();
                push (@params, protocols => $protocols);
                my $confFile = $self->confDir() . "l7filter-$iface.conf";
                $self->writeConfFile($confFile, 'trafficshaping/l7filter.conf.mas', \@params);

                # Write l7 filter upstart
                @params = ();
                my $realIface = $self->{network}->realIface($iface);
                push (@params, iface => $iface);
                push (@params, config => $confFile);
                push (@params, mask => EBox::TrafficShaping::Filter::Fw->MARK_MASK);
                push (@params, queue => $self->ifaceUniqueId($realIface));
                $self->writeConfFile(UPSTART_DIR . "ebox.l7filter-$iface.conf", 'trafficshaping/l7filter.upstart.mas', \@params);
            }
        }
    }
}

# Method: _enforceServiceState
#
# Overrides:
#
#       <EBox::Module::Service::_enforceServiceState>
#
sub _enforceServiceState
{

    my ($self) = @_;

    # Clean up stuff
    $self->_stopService();
    return unless ($self->isEnabled());

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders(regenConfig => 1);

    # Called every time a Save Changes is done
    my $ifaces_ref = $self->_configuredInterfaces();

    # Build a tree for each interface
    $self->_createPostroutingChain();
    $self->_resetInterfacesChains();

    foreach my $iface (@{$ifaces_ref}) {
        if ( defined ( $self->{builders}->{$iface} ) ) {
            # Dump tc and iptables commands
            my $tcCommands_ref = $self->{builders}->{$iface}->dumpTcCommands();
            my $ipTablesCommands_ref = $self->{builders}->{$iface}->dumpIptablesCommands();
            # Execute tc commands
            $self->{tc}->reset($iface);            # First, deleting everything was there
            $self->{tc}->execute($tcCommands_ref); # Second, execute them!
            # Execute iptables commands
            $self->_executeIptablesCmds($ipTablesCommands_ref);
        }
    }

    # Start l7 daemons
    $self->_startService();
}

sub _resetInterfacesChains
{
    my ($self) = @_;

    my $interfaces;
    if (l7FilterEnabled()) {
        # due to app protocols we must reset all chains bz a rule with app protocol
        # requires ruels in all interfaces
         my $network = EBox::Global->modInstance('network');
        $interfaces = $self->_realIfaces();
    } else {
      $interfaces =  $self->_configuredInterfaces();
    }

    foreach my $iface (@{$interfaces  }) {
            $self->_resetChain($iface);
    }
}

# Method: _daemons
#
# Overrides:
#
#     <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;

    my @daemons = ();
    my $ifaces_ref = $self->_configuredInterfaces();

    # Return daemons for ifaces with configured l7 protocols
    foreach my $iface (@{$ifaces_ref}) {
        if ( defined ( $self->{builders}->{$iface} ) ) {
            my $protocols = $self->{builders}->{$iface}->dumpProtocols();
            if (scalar keys %$protocols) {
                push(@daemons, { name => "ebox.l7filter-$iface" });
            }
        }
    }
    return \@daemons;
}

# Method: _stopService
#
#     Call every time the module is stopped
#
# Overrides:
#
#     <EBox::Module::_stopService>
#
sub _stopService
{
    my ($self) = @_;

    $self->startUp() unless ($self->{'started'});

    # Stop l7 daemons
    $self->SUPER::_stopService($self);

    my $ifaces_ref = $self->_configuredInterfaces();

    $self->_deletePostroutingChain();
    foreach my $iface (@{$ifaces_ref}) {
        # Cleaning iptables
        $self->_deleteChains($iface);
        # Cleaning tc
        $self->{tc}->reset($iface);
    }
}

# Method: summary
#
sub summary
{
}

# Method: menu
#
#       Add Traffic Shaping module to Zentyal menu
#
# Parameters:
#
#       root - the <EBox::Menu::Root> where to leave our items
#
sub menu # (root)
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'TrafficShaping',
                                        'icon' => 'trafficshaping',
                                        'text' => $self->printableName(),
                                        'order' => 900);
    $folder->add(new EBox::Menu::Item('url'  => 'TrafficShaping/Composite/Rules',
                                      'text' => __('Rules')));
    $folder->add(new EBox::Menu::Item('url'  => 'TrafficShaping/View/InterfaceRate',
                                      'text' => __('Interface Rates')));

    $root->add($folder);
}

# Method: configDir
#
#       Returns config dir path for this module, if it does not exists it will be created
#
# Returns:
#
#       config dir path
#
sub confDir
{
    if ( not -d CONF_DIR ) {
        mkdir ( CONF_DIR, 0755 );
    }

    return CONF_DIR;
}

sub ifaceIsShapeable
{
    my ($self, $iface) = @_;
    my $method = $self->{network}->ifaceMethod($iface);
    if ($method eq 'notset') {
        return 0;
    } elsif ($method eq 'ppp') {
        return 0;
    } elsif ($method eq 'bundled') {
        return 0;
    }

    return 1;
}

# Method: checkRule
#
#       Check if the rule passed can be added or updated. The guaranteed rate
#       or the limited rate should be given.
#
# Parameters:
#
#       interface      - interface under the rule is given
#       filterType     - type of the filter used (fw or u32)
#
#       service - String the service identifier stored at
#       zentyal-services module containing the inet protocol and source
#       and destination port numbers *(Optional)*
#
#       source - the rule source. It could be an
#       <EBox::Types::IPAddr>, <EBox::Types::MACAddr>, an object
#       identifier (more info at <EBox::Objects>) or an
#       <EBox::Types::Union::Text> to indicate any source *(Optional)*
#
#       destination - the rule destination. It could be an
#       <EBox::Types::IPAddr>, an object identifier (more info at
#       <EBox::Objects>) or an <EBox::Types::Union::Text> to indicate
#       any destination *(Optional)*
#
#       priority       - Int the rule priority *(Optional)*
#                        Default value: Lowest priority
#       guaranteedRate - maximum guaranteed rate in Kilobits per second *(Optional)*
#       limitedRate    - maximum allowed rate in Kilobits per second *(Optional)*
#       ruleId         - the rule identifier. It's given if the rule is
#                        gonna be updated *(Optional)*
#
#       enabled        - Boolean indicating whether the rule is enabled or not
#
# Returns:
#
#       true - if the rule can be added (updated) without problems
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::InvalidData> - throw if parameter has invalid
#      data
#      <EBox::Exceptions::External> - throw if interface is not external
#       or the rule cannot be built
#
sub checkRule
{
    my ($self, %ruleParams) = @_;

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $ruleParams{interface} );
    throw EBox::Exceptions::MissingArgument( __('filterType') )
      unless defined( $ruleParams{filterType} );

    if (not $self->ifaceIsShapeable($ruleParams{interface})) {
        throw EBox::Exceptions::External(__x('Iface {if} cannot be traffic shaped',
                                             if => $ruleParams{interface})
                                        );
    }

    # Setting standard rates if not defined
    $ruleParams{guaranteedRate} = 0 unless defined ( $ruleParams{guaranteedRate} );
    $ruleParams{guaranteedRate} = 0 if $ruleParams{guaranteedRate} eq '';
    $ruleParams{limitedRate} = 0 unless defined ( $ruleParams{limitedRate} );
    $ruleParams{limitedRate} = 0 if $ruleParams{limitedRate} eq '';

    # Check rule availability
    my $nRules =  $self->model('InternalRules')->size();
    $nRules    += $self->model('ExternalRules')->size();
    if ($nRules >= MAX_RULE_NUM and (not defined ($ruleParams{ruleId}))) {
      throw EBox::Exceptions::External(
            __x('The maximum rule account {max} is reached, ' .
        'please delete at least one in order to to add a new one',
        max => MAX_RULE_NUM));
    }

    unless ( defined ( $ruleParams{priority} )) {
      # Set the priority the lowest
      $ruleParams{priority} = 7;
    }

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    my @createBuildersParams = (regenConfig => 0);
    if ($ruleParams{enabled}) {
        push @createBuildersParams, activeIface => $ruleParams{interface};
    }
    $self->_createBuilders(@createBuildersParams);

    if (defined ($ruleParams{ruleId}) and not $ruleParams{reactivated}) {
      # Try to update the rule
      $self->_updateRule( $ruleParams{interface}, $ruleParams{ruleId}, \%ruleParams, 'test' );
    } else {
      # Try to build the rule
      $self->_buildRule( $ruleParams{interface}, \%ruleParams, 'test');
    }

    # If it works correctly, the write to conf is done afterwards by
    # TrafficShapingModel

    return 1;
}

# Method: listRules
#
#       Send a list with all the rules within an interface
#
# Parameters:
#
#       interface - the interface name
#
# Returns
#
#       array ref - containing hash references which have the
#       following attributes:
#         - service - String the service identifier
#         - source  - the selected source. It can be one of the following:
#                     - <EBox::Types::IPAddr>
#                     - <EBox::Types::MACAddr>
#                     - String containing the source object
#         - destination - the selected destination. It can be one of the following:
#                     - <EBox::Types::IPAddr>
#                     - String containing the destination object
#         - guaranteed_rate - maximum guaranteed rate
#         - limited_rate    - maximum traffic rate
#         - priority        - priority (lower number, highest priority)
#         - enabled         - is this rule enabled?
#         - ruleId          - unique identifier for this rule
#
sub listRules
{
    my ($self, $iface) = @_;
    my $ruleModel = $self->ruleModel($iface);
    return $ruleModel->rulesForIface($iface);
}

# Method: getLowestPriority
#
#       Accessor to the lowest priority rule for an interface. If none
#       is found, the lowest priority is zero.
#
# Parameters:
#
#       interface - interface name
#       search    - search a new lowest priority (Optional)
#
# Returns:
#
#       Integer - the lowest priority (the highest number)
#
sub getLowestPriority # (interface, search?)
{
    my ($self, $iface, $search) = @_;

    if ( $search or
         not defined( $self->{lowestPriority} )) {
      $self->_setNewLowestPriority($iface);
    }

    return $self->{lowestPriority};
}

# Method: ruleModel
#
#       Return the model associated to the rules table
#
# Parameters:
#
#       interface - String interface attached to the rule table model
#
# Returns:
#
#       <EBox::TrafficShaping::Model::RuleTable> - if there is a model
#       associated with the given interface
#
#       undef - if there is no model associated with the given
#       interface
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#
sub ruleModel
{
    my ($self, $iface) = @_;
    my $network= $self->global()->modInstance('network');
    if ($network->ifaceIsExternal($iface)) {
        return $self->model('ExternalRules');
    } else {
        return $self->model('InternalRules');
    }
}

# Method:   interfaceRateModel
#
#   Returns a <EBox::TrafficShaping::Model::InterfaceRate> model
#
# Returns:
#
#       <EBox::TrafficShaping::Model::InterfaceRate>
#
sub interfaceRateModel
{
    my ($self) = @_;

    $self->{rateModel} = $self->model('InterfaceRate');

    return $self->{rateModel};
}

# Method: ShaperChain
#
#      Class method which returns the iptables chain used by Traffic
#      Shaping module
#
# Parameters:
#
#      iface - String with the interface where the traffic flows
#      where - from where it's shaper (Options: egress, ingress, forward)
#              *(Optional)* Default value: egress
#
# Returns:
#
#      String - shaper chain's name
#
sub ShaperChain
{
    my ($class, $iface, $where) = @_;

    $where = 'egress' unless defined ( $where );

    if ( $where eq 'egress' ) {
        return 'EBOX-SHAPER-OUT-' . $iface;
    } elsif ( $where eq 'ingress' ) {
        return 'EBOX-SHAPER-IN-' . $iface;
    }
}

# Method: MaxIdValue
#
#      Get the maximum identifier value allowed by the system
#
# Returns:
#
#      Int - the maximum allowed identifier
#
sub MaxIdValue
{
    return MAX_ID_VALUE;
}

###################################
# Network Observer Implementation
###################################

# Method: ifaceMethodChanged
#
# Implements:
#
#     <EBox::NetworkObserver::ifaceMethodChanged>
#
# Returns:
#
#     true - if there are rules on the model associated to the
#     given interface
#
#     false - otherwise
#
sub ifaceMethodChanged
{
    my ($self, $iface, $oldMethod, $newMethod) = @_;

    my @notUsedMethods = qw(notset trunk bundled);
    my $newUsed = grep { $_ ne $newMethod } @notUsedMethods;
    my $oldUsed = grep { $_ ne $oldMethod } @notUsedMethods;

    if ( (not $oldUsed) and $newUsed) {
        return 1 unless ( $self->{network}->ifaceIsExternal($iface));
    } elsif ( $oldUsed and (not $newUsed)) {
        return 1;
    } elsif ( $newMethod eq 'dhcp'
            and $oldMethod eq 'static' ) {
        return 1 if ( $self->{network}->ifaceIsExternal($iface));
    }
    return 0;
}

# Method: ifaceExternalChanged
#
# Implements:
#
#    <EBox::NetworkObserver::ifaceExternalChanged>.
#
# Returns:
#
#    true - if there are rules on the model associated to the given
#    interface or the change provokes not enough interfaces to shape
#    the traffic
#
#    false - otherwise
#
sub ifaceExternalChanged # (iface, external)
{

    my ($self, $iface, $external) = @_;
    my $ruleModel = $self->ruleModel($iface);
    if ($ruleModel->explicitIfaceHasRules($iface)) {
        return 1;
    }

    my $netMod = $self->global()->modInstance('network');
    my $extIfaces = @{$netMod->ExternalIfaces()};
    my $intIfaces = @{$netMod->InternalIfaces()};
    if ($external) {
        $extIfaces += 1;
        $intIfaces -= 1;
    } else {
        $extIfaces -= 1;
        $intIfaces += 1;
    }

    if (($extIfaces == 0) or ($intIfaces == 0)) {
        return 1;
    }

    return 0;
}

# Method: changeIfaceExternalProperty
#
#    Remove every rule associated to the given interface
#
# Implements:
#
#    <EBox::NetworkObserver::changeIfaceExternalProperty>
#
sub changeIfaceExternalProperty # (iface, external)
{
    my ($self, $iface, $external) = @_;
    $self->_deleteIface($iface);
}

# Method: freeIface
#
#        See <EBox::NetworkObserver::freeIface>.
#
# Parameters:
#
#       iface - interface name
#
# Returns:
#
#       boolean -
#
sub freeIface # (iface)
{
    my ($self, $iface) = @_;
    $self->_deleteIface($iface);
}

###
# Workaround related to upload rate from an external interface
###

# Method: uploadRate
#
#    Get the upload rate from an interface in kilobits per second
#
# Parameters:
#
#    iface - String interface's name
#
# Returns:
#
#    Int - the upload rate in kilobits per second
#
#    0 - if the interface is an internal one
#
sub uploadRate # (iface)
{
    my ($self, $iface) = @_;

    my $rates = $self->interfaceRateModel();
    my $row = $rates->findRow(
        interface => $self->{network}->etherIface($iface)
    );

    return 0 unless defined($row);

    return $row->valueByName('upload');
}

# Method: totalDownloadRate
#
#        Get the total download rate from the external interfaces in
#        kilobits per second
#
# Returns:
#
#        Int - the download rate in kilobits per second
#
sub totalDownloadRate
{
    my ($self) = @_;
    my $rates = $self->interfaceRateModel();
    return $rates->totalDownloadRate();
}

# Method: enoughInterfaces
#
#      Return if there are enough interfaces to do traffic shaping
#
sub enoughInterfaces
{
    my ($self) = @_;

    my $netMod = $self->{network};

    my @extIfaces = @{$netMod->ExternalIfaces()};
    my @intIfaces = @{$netMod->InternalIfaces()};

    return (@extIfaces > 0) && (@intIfaces > 0);
}

###################################
# Group: Private Methods
###################################

###
# Priority helper methods
###

# Set the new lowest priority after one is out within an interface
# If priority is given, it just checks with the currently lowest
# priority
sub _setNewLowestPriority # (iface, priority?)
{
    my ($self, $iface, $priority) = @_;

    if (defined ($priority)) {
        # Check only with the currently lowest priority
        if ($priority > $self->getLowestPriority($iface)) {
            $self->_setLowestPriority($iface, $priority);
        }
    }
    else {
      my $ruleModel = $self->ruleModel($iface);
      my $lowest  = $ruleModel->lowestPriority($iface);
      $self->_setLowestPriority($iface, $lowest);
    }
}

# Method: _setLowestPriority
#
#       Mutator to the lowest priority.
#
# Parameters:
#
#       interface - interface name
#       priority  - the lowest priority
#
sub _setLowestPriority # (interface, priority)
{
    my ($self, $iface, $priority) = @_;

    $self->{lowestPriority} = $priority;
}

###
# Checker Functions
###

# Check interface existence and if it has gateways associated
# Throw External exception if not enough gateways to the external interface
# Throw DataNotFound if the interface doesn't exist
sub _checkInterface # (iface)
{
    my ($self, $iface) = @_;

    my $global = EBox::Global->getInstance();
    my $network = $self->{'network'};
    $iface = $network->etherIface($iface);

    # Now shaping can be done at internal interfaces to egress traffic

    # If the interface doesn't exist, launch an DataNotFound exception
    if ( not $network->ifaceExists( $iface )) {
        throw EBox::Exceptions::DataNotFound( data => __('Interface'),
                value => $iface
                );
    }

    if ($network->ifaceMethod($iface) eq 'notset') {
        throw EBox::Exceptions::External("Iface not configured $iface");
    }
}

# Check if there are rules are active within a given interface
# Returns true if any, false otherwise
sub _areRulesActive # (iface, countDisabled)
{
    my ($self, $iface, $countDisabled) = @_;
    my $rules = $self->listRules($iface);
    if ($countDisabled) {
        return scalar @{ $rules } > 0;
    } else {
        return scalar @{ $rules };
    }
}

sub _deleteIface
{
    my ($self, $iface) = @_;
    $self->model('InternalRules')->_removeRules($iface);
    $self->model('ExternalRules')->_removeRules($iface);
}

# Underlying stuff (Come to the mud)

# Method: _createTree
#
#       Creates a tree with the builder within an interface.
#
# Parameters:
#
#       interface - String interface's name to create the tree
#       type - String HTB, default or HFSC
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - throw if type is not one of
#      the supported
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#
#      <EBox::Exceptions::External> - throw if rate is not given for
#      every external interface
#
sub _createTree # (interface, type)
{
    my ($self, $iface, $type) = @_;

    # Check arguments
    throw EBox::Exceptions::MissingArgument('interface')
      unless defined ( $iface );
    throw EBox::Exceptions::MissingArgument('type')
      unless defined ( $type );

    throw EBox::Exceptions::InvalidData(data => __('type'))
      unless ( $type eq any( qw(default HTB HFSC) ) );

    # Create builder
    if ( $type eq "default" ) {
      $self->{builders}->{$iface} = EBox::TrafficShaping::TreeBuilder::Default->new($iface);
      # Build it
      $self->{builders}->{$iface}->buildRoot();
    }
    elsif ( $type eq "HTB" ) {
      $self->{builders}->{$iface} = EBox::TrafficShaping::TreeBuilder::HTB->new($iface, $self);
      # Build it

      # Check if interface is internal or external to set a maximum
      # rate The maximum rate for an internal interface is the sum of
      # the download rate associated to the external interfaces

      # Get the rate from Network
      my $linkRate;
      my $model = $self->ruleModel($iface);
      $linkRate = $model->committedLimitRate($iface);

      if ( not defined($linkRate) or $linkRate == 0) {
          throw EBox::Exceptions::External(__x("Interface {iface} should have a maximum " .
                         "bandwidth rate in order to do traffic shaping",
                         iface => $iface));
      }
      $self->{builders}->{$iface}->buildRoot(DEFAULT_CLASS_ID, $linkRate);
    }
    elsif ( $type eq "HFSC" ) {
      ;
    }
}

# Build the tree from conf variables stored.
# It assumes rules are correct
sub _buildGConfRules # (iface, regenConfig)
{
    my ($self, $iface, $regenConfig) = @_;

    my $model = $self->ruleModel($iface);

    foreach my $ruleRef (@{$model->rulesForIface($iface)}) {
        # transformations needed for the builder
        # get identifier for builder
        my $id = delete $ruleRef->{ruleId};
        $ruleRef->{identifier} = $self->_nextMap($id);
        if ($ruleRef->{filterType} eq 'fw') {
            # Source and destination
            foreach my $targetName (qw(source destination)) {
                my $target = delete $ruleRef->{$targetName};
                if ( $target->isa('EBox::Types::Union::Text')) {
                    $target = undef;
                } elsif ( $target->isa('EBox::Types::Select')) {
                    # An object
                    $target = $target->value();
                }
                $ruleRef->{$targetName}  = $target;
            }
        }
        # Rates
        # Transform from conf to camelCase and set if they're null
        # since they're optional parameters
        $ruleRef->{guaranteedRate} = delete $ruleRef->{'guaranteed_rate'};
        $ruleRef->{guaranteedRate} = 0 unless defined ($ruleRef->{guaranteedRate});
        $ruleRef->{limitedRate} = delete $ruleRef->{'limited_rate'};
        $ruleRef->{limitedRate} = 0 unless defined ($ruleRef->{limitedRate});

        # Take care of enabled value only if regenConfig is enabled
        if (not $regenConfig) {
            $ruleRef->{enabled} = 1;
        }
        $self->_buildANewRule( $iface, $ruleRef, undef );
    }
}

# Create builders and they are stored in builders
sub _createBuilders
{
    my ($self, %params) = @_;
    # Don't do anything if there aren't enough ifaces
    return unless ($self->enoughInterfaces());

    my $regenConfig = $params{regenConfig};

    my @ifaces = @{$self->_realIfaces()};
    foreach my $iface (@ifaces) {
        $self->{builders}->{$iface} = {};
        my $active;
        if ($params{activeIface} and ($params{activeIface} eq $iface)) {
            $active = 1;
        } else {
            $active = $self->_areRulesActive($iface, not $regenConfig);
        }
        if ( $active  ) {
            # If there's any rule, for now use an HTBTreeBuilder
            $self->_createTree($iface, "HTB", $regenConfig);

            # Build every rule and stores the identifier in conf to destroy
            # them afterwards
            $self->_buildGConfRules($iface, $regenConfig);
        }
        else {
            # For now, if no user_rules are given, use DefaultTreeBuilder
            $self->_createTree($iface, "default");
        }
    }

    # write configuration files
    $self->_setConf();
}

# Build a new rule to the tree
# If not rules has been set or they're not enabled no added is made
sub _buildRule # ($iface, $rule_ref, $test)
{
    my ( $self, $iface, $rule_ref, $test ) = @_;

    if ( $self->{builders}->{$iface}->isa('EBox::TrafficShaping::TreeBuilder::Default') ) {
      # Build a new HTB
      $self->_createTree($iface, "HTB");
    }

    # Actually build the rule in the builder or just test if it's possible
    $self->_buildANewRule($iface, $rule_ref, $test);
}

# Finally, adds from GConf rules to tree builder
# Throws Internal exception if not normal builder
# is asked to build the rule
sub _buildANewRule # ($iface, $rule_ref, $test?)
{
    my ($self, $iface, $rule_ref, $test) = @_;

    my $htbBuilder = $self->{builders}->{$iface};

    if ( $htbBuilder->isa('EBox::TrafficShaping::TreeBuilder::HTB')) {
        if ($rule_ref->{filterType} eq 'fw') {
            my $src = undef;
            my $srcObj = undef;
            my $objs = $self->{'objects'};
            if ( ( defined ( $rule_ref->{source} )
                   and $rule_ref->{source} ne '' ) and
                 ( $rule_ref->{source}->isa('EBox::Types::IPAddr') or
                   $rule_ref->{source}->isa('EBox::Types::MACAddr'))
               ) {
                $src = $rule_ref->{source};
                $srcObj = undef;
            } elsif ( ( not defined ( $rule_ref->{source} ))
                      or $rule_ref->{source}->isa('EBox::Types::Union::Text')) {
                $src = undef;
                $srcObj = undef;
            } else {
                # If an object is provided no source is needed to set a rule but
                # then attaching filters according to members of this object
                $src = undef;
                $srcObj =  $rule_ref->{source};
                return unless (@{$objs->objectAddresses($srcObj)});
            }

            # The same related to destination
            my $dst = undef;
            my $dstObj = undef;
            if ((defined ( $rule_ref->{destination} ) and
                   $rule_ref->{destination} ne '' ) and
                 ($rule_ref->{destination}->isa('EBox::Types::IPAddr'))) {
                $dst = $rule_ref->{destination};
                $dstObj = undef;
            } elsif (not defined ( $rule_ref->{destination})
                      or ($rule_ref->{destination}->isa('EBox::Types::Union::Text'))) {
                $dst = undef;
                $dstObj = undef;
            } else {
                # If an object is provided no source is needed to set a rule but
                # then attaching filters according to members of this object
                $dst = undef;
                $dstObj =  $rule_ref->{destination} ;
                return unless (@{$objs->objectAddresses($dstObj)});
            }

            # Set a filter with objects if src or dst are not objects
            my $service = undef;
            $service = $rule_ref->{service}; # unless ( $srcObj or $dstObj );

            # Only to dump enabled rules, however testing adding new rules
            # is done, no matter if the rule is enabled or not
            if ( $rule_ref->{enabled} or $test ) {
                $htbBuilder->buildRule(
                    filterType     => $rule_ref->{filterType},
                    service        => $service,
                    source         => $src,
                    destination    => $dst,
                    guaranteedRate => $rule_ref->{guaranteedRate},
                    limitedRate    => $rule_ref->{limitedRate},
                    priority       => $rule_ref->{priority},
                    identifier     => $rule_ref->{identifier},
                    testing        => $test,
                );
            }
            # If an object is provided, attach filters to every member to the
            # flow object id
            # Only if not testing
            if ( not $test ) {
                if ( $srcObj and not $dstObj) {
                    $self->_buildObjMembers( treeBuilder  => $htbBuilder,
                                         what         => 'source',
                                         objectName   => $rule_ref->{source},
                                         ruleRelated  => $rule_ref->{identifier},
                                         serviceAssoc => $rule_ref->{service},
                                         where        => $rule_ref->{destination},
                                         rulePriority => $rule_ref->{priority},
                                       );
                } elsif ( $dstObj and not $srcObj ) {
                    $self->_buildObjMembers(
                                        treeBuilder  => $htbBuilder,
                                        what         => 'destination',
                                        objectName   => $rule_ref->{destination},
                                        ruleRelated  => $rule_ref->{identifier},
                                        serviceAssoc => $rule_ref->{service},
                                        where        => $rule_ref->{source},
                                        rulePriority => $rule_ref->{priority},
                                       );
                } elsif ( $dstObj and $srcObj ) {
                    # We have to build whole station
                    $self->_buildObjToObj( treeBuilder  => $htbBuilder,
                                           srcObject    => $rule_ref->{source},
                                           dstObject    => $rule_ref->{destination},
                                           ruleRelated  => $rule_ref->{identifier},
                                           serviceAssoc => $rule_ref->{service},
                                           rulePriority => $rule_ref->{priority},
                                         );
                }
            }
        } elsif ($rule_ref->{filterType} eq 'u32') {
            if ($rule_ref->{enabled} or $test) {
                $htbBuilder->buildRule(
                    filterType     => $rule_ref->{filterType},
                    guaranteedRate => $rule_ref->{guaranteedRate},
                    limitedRate    => $rule_ref->{limitedRate},
                    priority       => $rule_ref->{priority},
                    identifier     => $rule_ref->{identifier},
                    testing        => $test,
                );
            }

            # Only if not testing, we attach the u32 filter to the flow object id
            if (not $test) {
                $htbBuilder->addFilter(
                    leafClassId => $rule_ref->{identifier},
                    filterType  => $rule_ref->{filterType},
                    priority    => $rule_ref->{priority},
                );
            }
        } else {
            throw EBox::Exceptions::Internal("Unknown filter type: $rule_ref->{filterType}");
        }
    } else {
        throw EBox::Exceptions::Internal('Tree builder which is not HTB ' .
                                         'which actually builds the rules');
    }
}

# Build a necessary classify rule to each member from an object into a
# HTB tree
# It receives four parameters:
#  - treeBuilder - the HTB tree builder
#  - what - what is the object (source, destination)
#  - objectName - the object's name
#  - ruleRelated - the rule identifier assigned to the object
#  - serviceAssoc - the service associated if any
#  - where - the counterpart (<EBox::Types::IPAddr> or <EBox::Types::MACAddr>)
#  - rulePriority - the rule priority
sub _buildObjMembers
{
    my ($self, %args ) = @_;
    my $treeBuilder = $args{treeBuilder};
    my $what = $args{what};
    my $objectName = $args{objectName};
    my $ruleRelated = $args{ruleRelated};
    my $serviceAssoc = $args{serviceAssoc};
    my $where = $args{where};
    my $rulePriority = $args{rulePriority};

    unless ($objectName) {
        return;
    }

    # Get the object's addresses
    my $objs = $self->{'objects'};

    my $members_r = $objs->objectMembers($objectName);

    # Set a different filter identifier for each object's member
    my $filterId = $ruleRelated;
    foreach my $member (@{$members_r}) {
        my $addressObject = _addressFromObjectMember($member);

        my $srcAddr;
        my $dstAddr;
        if ( $what eq 'source' ) {
            $srcAddr = $addressObject;
            $dstAddr = $where;
        } elsif ( $what eq 'destination') {
            $srcAddr = $where;
            $dstAddr = $addressObject;
        }
        $treeBuilder->addFilter(
            leafClassId => $ruleRelated,
            filterType  => 'fw',
            priority    => $rulePriority,
            srcAddr     => $srcAddr,
            dstAddr     => $dstAddr,
            service     => $serviceAssoc,
            id          => $filterId,
        );
        $filterId++;
        # If there's a MAC address and what != source not to add since
        # it has no sense
        # TODO: Objects can be only set with an IP.
        #      if ( $member_ref->{mac} and ( $what eq 'source' )) {
        #       my $mac = new EBox::Types::MACAddr(
        #                                          value => $member_ref->{mac},
        #                                         );
        #       $filterValue->{srcAddr} = $mac;
        #       $filterValue->{dstAddr} = $where;
        #       $treeBuilder->addFilter( leafClassId => $ruleRelated,
        #                                filterValue => $filterValue);
        #       $filterId++;
        #      }
        # Just adding one could be a solution to have different filter identifiers
    }
}

# Build a n x m rules among each member of the both object with each other
# It receives four parameters:
#  - treeBuilder - the HTB tree builder
#  - srcObject - source object's name
#  - dstObject - destination object's name
#  - ruleRelated - the rule identifier assigned to the filters to add
#  - serviceAssoc - the service associated if any
#  - rulePriority - the rule priority
sub _buildObjToObj
{
    my ($self, %args) = @_;
    my $objs = $self->{'objects'};

    my $srcMembers_ref = $objs->objectMembers($args{srcObject});
    my $dstMembers_ref = $objs->objectMembers($args{dstObject});

    my $filterId = $args{ruleRelated};

    foreach my $srcMember (@{$srcMembers_ref}) {
        my $srcAddr = _addressFromObjectMember($srcMember);
        foreach my $dstMember (@{$dstMembers_ref}) {
            my $dstAddr = _addressFromObjectMember($dstMember);
            $args{treeBuilder}->addFilter(
                leafClassId => $args{ruleRelated},
                filterType  => 'fw',
                priority    => $args{rulePriority},
                srcAddr     => $srcAddr,
                dstAddr     => $dstAddr,
                service     => $args{serviceAssoc},
                id          => $filterId,
            );
            $filterId++;

        }
    }
}

sub _addressFromObjectMember
{
    my ($member) = @_;
    my $address;
    if ($member->{type} eq 'ipaddr') {
        my $ipAddr = $member->{'ipaddr'};
        $ipAddr =~ s:/.*$::g;
        $address = new EBox::Types::IPAddr(
            ip => $ipAddr,
            mask => $member->{mask},
            fieldName => 'ip'
           );
    } elsif ($member->{type} eq 'iprange') {
        $address = new EBox::Types::IPRange(
            begin => $member->{begin},
            end => $member->{end},
                fieldName => 'iprange'
               );
    } else {
        throw EBox::Exceptions::Internal("Unexpected member type: " . $member->{type})
    }

    return $address;
}

# Update a rule from the builder taking arguments from GConf
sub _updateRule # (iface, ruleId, ruleParams_ref?, test?)
{
    my ($self, $iface, $ruleId, $ruleParams_ref, $test) = @_;

    my $minorNumber = $self->_mapRuleToClassId($ruleId);
    # Update the rule stating the same leaf class id (If test not do)
    if ($ruleParams_ref->{filterType} eq 'fw') {
        $self->{builders}->{$iface}->updateRule(
            identifier     => $minorNumber,
            filterType     => $ruleParams_ref->{filterType},
            service        => $ruleParams_ref->{service},
            source         => $ruleParams_ref->{source},
            destination    => $ruleParams_ref->{destination},
            guaranteedRate => $ruleParams_ref->{guaranteedRate},
            limitedRate    => $ruleParams_ref->{limitedRate},
            priority       => $ruleParams_ref->{priority},
            testing        => $test,
        );
    } elsif ($ruleParams_ref->{filterType} eq 'u32') {
        $self->{builders}->{$iface}->updateRule(
            identifier     => $minorNumber,
            filterType     => $ruleParams_ref->{filterType},
            guaranteedRate => $ruleParams_ref->{guaranteedRate},
            limitedRate    => $ruleParams_ref->{limitedRate},
            priority       => $ruleParams_ref->{priority},
            testing        => $test,
        );
    } else {
        throw EBox::Exceptions::Internal("Unknown filter type: $ruleParams_ref->{filterType}");
    }
}

###
# Naming convention helper functions
###

# Set the identifiers to the correct intervals with this function
# (Ticket #481)
# Returns a Int among MIN_ID_VALUE and MAX_ID_VALUE
sub _nextMap # (ruleId?, test?)
{
    my ($self, $ruleId, $test) = @_;

    if (not defined ($self->{nextIdentifier})) {
        $self->{nextIdentifier} = MIN_ID_VALUE;
        $self->{classIdMap} = {};
    }

    my $retValue = $self->{nextIdentifier};

    if (defined ($ruleId) and not $test) {
        # We store at a hash the ruleId vs. class id
        $self->{classIdMap}->{$ruleId} = $retValue;
    }

    if ($self->{nextIdentifier} < MAX_ID_VALUE and (not $test)) {
        # Sums step value -> 0x100
        $self->{nextIdentifier} += STEP_ID_VALUE;
    }

    return $retValue;
}

# Returns the class id mapped at a rule identifier
# Undef if no map has been created
sub _mapRuleToClassId # (ruleId)
{
    my ($self, $ruleId) = @_;

    if (defined ( $self->{classIdMap})) {
        return $self->{classIdMap}->{$ruleId};
    }
    else {
        return undef;
    }
}

###################################
# Iptables related functions
###################################

# Delete TrafficShaping filter chain in Iptables Linux kernel struct
sub _deleteChains # (iface)
{
    my ( $self, $iface ) = @_;

    my @cmds;
    my $iptablesCmd = '/sbin/iptables';
    push (@cmds, "$iptablesCmd -t mangle -F EBOX-SHAPER-$iface");
    push (@cmds, "$iptablesCmd -t mangle -X EBOX-SHAPER-$iface");
    push (@cmds, "$iptablesCmd -t mangle -F EBOX-L7SHAPER-$iface");
    push (@cmds, "$iptablesCmd -t mangle -X EBOX-L7SHAPER-$iface");
    EBox::Sudo::silentRoot(@cmds);
}

sub _deletePostroutingChain # (iface)
{
    my ($self) = @_;

    my @cmds;
    my $iptablesCmd = '/sbin/iptables';
    push (@cmds, "$iptablesCmd -t mangle -D POSTROUTING -j EBOX-SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -D FORWARD -j EBOX-L7SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -F EBOX-SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -F EBOX-L7SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -X EBOX-SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -X EBOX-L7SHAPER");
    EBox::Sudo::silentRoot(@cmds);
}

sub _createPostroutingChain # (iface)
{
    my ($self) = @_;

    my @cmds;
    my $iptablesCmd = '/sbin/iptables';
    my $chain = "EBOX-SHAPER";
    push (@cmds, "$iptablesCmd -t mangle -N EBOX-SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -N EBOX-L7SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -A POSTROUTING -j EBOX-SHAPER");
    push (@cmds, "$iptablesCmd -t mangle -I FORWARD -j EBOX-L7SHAPER");
    EBox::Sudo::silentRoot(@cmds);
}

sub _resetChain # (iface)
{
    my ($self, $iface) = @_;

    # Delete any previous chain
    $self->_deleteChains($iface);

    my $chain = "EBOX-SHAPER-$iface";
    my $chainl7 = "EBOX-L7SHAPER-$iface";

    my @cmds;
    my $iptablesCmd = '/sbin/iptables';

    push (@cmds, "$iptablesCmd -t mangle -N $chain");
    push (@cmds, "$iptablesCmd -t mangle -N $chainl7");
    push (@cmds, "$iptablesCmd -t mangle -I EBOX-SHAPER -o $iface -j $chain");
    push (@cmds, "$iptablesCmd -t mangle -I EBOX-L7SHAPER -o $iface -j $chainl7");
    EBox::Sudo::silentRoot(@cmds);
}

# Execute an array of iptables commands
sub _executeIptablesCmds # (iptablesCmds_ref)
{
    my ($self, $iptablesCmds_ref) = @_;

    my @cmds = map { "/sbin/iptables $_" } @{$iptablesCmds_ref};
    EBox::Sudo::root(@cmds);
}

# Fetch configured interfaces in this module
sub _configuredInterfaces
{
    my ($self) = @_;

    # FIXME: interfaces external with rates should be also returned or not
    my @ifaces;
    push @ifaces, @{ $self->model('ExternalRules')->configuredInterfaces()  };
    push @ifaces ,@{ $self->model('InternalRules')->configuredInterfaces()  };

    # exclude interfaces that cannot be shaped
    @ifaces = grep {
        $self->ifaceIsShapeable($_)
    } @ifaces;

    return \@ifaces;
}

# For all those ppp ifaces fetch its ethernet iface
sub _realIfaces
{
    my ($self) = @_;
    my $network = $self->{'network'};
    my @ifaces = grep {
        my $method = $network->ifaceMethod($_);
        ($method ne 'notset') and ($method ne 'trunk') and ($method ne 'bundled')
    }  @{$network->ifaces()};
    @ifaces =  map {
        $network->realIface($_)
    } @ifaces;

    return \@ifaces;
}

# Load L7 userspace kernel module
sub _loadL7Module
{
    EBox::Sudo::root('modprobe ' . L7_MODULE . ' || true');
}

# Method: l7FilterEnabled
#
#   return wether l7 (application layer) filtering is available or not. This
#   will require an appropatie kernel, iptables and the module l7-protocols
#
#   Returns:
#      boolean - whether l7 fitler is available or not
sub l7FilterEnabled
{
    return 0 unless (EBox::Global->getInstance()->modExists('l7-protocols'));
}

# Method: ifaceUniqueId
#
#   Gets an unique id for the interface
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   integer - Unique id for the interface
#             undef if iface does not exists
#
sub ifaceUniqueId
{
    my ($self, $iface) = @_;

    my $network = EBox::Global->modInstance('network');
    my $id = 0;
    foreach my $if ( @{$network->ifaces()} ) {
        if ( $iface eq $if ) {
            return $id;
        }
        $id++;
    }

    return undef;
}

# Method: regenGatewaysFailover
#
# Overrides:
#
#    <EBox::NetworkObserver::regenGatewaysFailover>
#
sub regenGatewaysFailover
{
    my ($self) = @_;

    $self->restartService();
}

1;
