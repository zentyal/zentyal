# Copyright (C) 2006,2007 Warp Networks S.L.
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

# FIXME:  Get rid of unnecessary stuff already provided by the framework
# 
package EBox::TrafficShaping;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::NetworkObserver);

######################################
# Dependencies:
# Perl6::Junction package
######################################
use Perl6::Junction qw( any );

use EBox::Gettext;
use EBox::Summary::Module;

use EBox::Validate qw( checkProtocol checkPort );
use EBox::LogAdmin qw ( :all );

# Used exceptions
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
# Command wrappers
use EBox::TC;
use EBox::Iptables;

# Concrete builders
use EBox::TrafficShaping::TreeBuilder::Default;
use EBox::TrafficShaping::TreeBuilder::HTB;

# Rule model
use EBox::TrafficShaping::Model::RuleTable;
use EBox::TrafficShaping::Model::RuleMultiTable;

# To do try and catch
use Error qw( :try );

# Using the brand new eBox types
use EBox::Types::IPAddr;
use EBox::Types::MACAddr;

# We set rule identifiers among 256 and 512
use constant MIN_ID_VALUE => 256; # 0x100
use constant MAX_ID_VALUE => 65280; # 0xFF00

# Constructor for traffic shaping module
sub _create
  {
    my $class = shift;
    my $self = $class->SUPER::_create(name   => 'trafficshaping',
				      domain => 'ebox-trafficshaping',
				      title  => __('Traffic Shaping'),
				      @_);

    $self->{network} = EBox::Global->modInstance('network');
    $self->{objects} = EBox::Global->modInstance('objects');


#    $self->_setLogAdminActions();

#    my $global = EBox::Global->getInstance();
#    $self->{network} = $global->modInstance('network');

    bless($self, $class);

    return $self;
  }

# FIXME 
sub startUp
{
     my ($self) = @_;
    # Create rule models
    $self->_createRuleModels();

    # Create wrappers
    $self->{tc} = EBox::TC->new();
    $self->{ipTables} = EBox::Iptables->new();
    # Create tree builders
    $self->_createBuilders();

    $self->{'started'} = 1;
}

sub _regenConfig
  {

    my ($self) = @_;

    # FIXME

    $self->startUp() unless ($self->{'started'});

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # Called every time a Save Changes is done
    my $ifaces_ref = $self->all_dirs_base('/ebox/modules/trafficshaping');
    # Build a tree for each interface
    foreach my $iface (@{$ifaces_ref}) {
      if ( defined ( $self->{builders}->{$iface} ) ) {
	# Dump tc and iptables commands
	my $tcCommands_ref = $self->{builders}->{$iface}->dumpTcCommands();
	my $ipTablesCommands_ref = $self->{builders}->{$iface}->dumpIptablesCommands();
	# Execute tc commands
	$self->{tc}->reset($iface);            # First, deleting everything was there
	$self->{tc}->execute($tcCommands_ref); # Second, execute them!
	# Execute iptables commands
	$self->_resetChain($iface);
	$self->_executeIptablesCmds($ipTablesCommands_ref);
      }
    }
  }

# Method: _stopService
#
#     Call every time the module is stopped
#
sub _stopService
  {
    my $self = shift;

    $self->startUp();

    my $ifaces_ref = $self->all_dirs_base('/ebox/modules/trafficshaping');

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
#       Add Traffic Shaping module to eBox menu
#
# Parameters:
#
#       root - the <EBox::Menu::Root> where to leave our items
#
sub menu # (root)
  {

    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url'  => 'TrafficShaping/Index',
				    'text' => __('Traffic Shaping')));

  }
# Method: addRule
#
#       Add a custom rule. A guaranteed rate or a limited rate should
#       be given.
#
# Parameters:
#
#       interface      - interface to attach the rule
#       protocol       - inet protocol *(Optional)*
#       port           - port number *(Optional)*
#       source         - source. It could be an <EBox::Types::IPAddr>,
#                        <EBox::Types::MACAddr> or an object name (more info at
#                        <EBox::Objects>) *(Optional)*
#       destination    - destination. It could be an <EBox::Types::IPAddr>
#                        or an object name (more info at <EBox::Objects>) *(Optional)*
#       guaranteedRate - maximum guaranteed rate in Kilobits per second *(Optional)*
#       limitedRate    - maximum allowed rate in Kilobits per second *(Optional)*
#       priority       - rule priority (lower number, highest priority)
#                        Default: lowest priority *(Optional)*
#       enabled        - set if the rule added is enabled *(Optional)*
#                        Default: true
#
#       - (Named Parameters)
#
# Returns:
#
#       Nothing
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::InvalidData> - throw if parameter has invalid
#      data
#      <EBox::Exceptions::External> - throw if interface is not external
#       or the rule cannot be built
#      <EBox::Exceptions::DataExists> - throw if the data already exists
#       in the module
#
sub addRule
  {

    my ( $self, %ruleParams ) = @_;

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $ruleParams{interface} );

#    if ( ( not defined( $ruleParams{protocol} ) ) and
#	 ( not defined( $ruleParams{port} ) ) and
#	 ( not defined( $ruleParams{source} ) ) and
#	 ( not defined( $ruleParams{destination} ) )) {
#      throw EBox::Exceptions::MissingArgument( __('Any attribute should be provided') );
#    }

    if ( not defined ( $ruleParams{guaranteedRate} ) and
	 not defined ( $ruleParams{limitedRate} ) ) {
      throw EBox::Exceptions::MissingArgument( __('Guaranteed rate or limited rate') );
    }

    # Setting standard rates if not defined
    $ruleParams{guaranteedRate} = 0 unless defined ( $ruleParams{guaranteedRate} );
    $ruleParams{guaranteedRate} = 0 if $ruleParams{guaranteedRate} eq '';
    $ruleParams{limitedRate} = 0 unless defined ( $ruleParams{limitedRate} );
    $ruleParams{limitedRate} = 0 if $ruleParams{limitedRate} eq '';


    # Check interface to be external
    $self->_checkInterface( $ruleParams{interface} );
    # Check protocol, port number, source and destination by <EBox::Types>
    # Check rates
    $self->_checkRate( $ruleParams{guaranteedRate}, __('Guaranteed Rate') );
    $self->_checkRate( $ruleParams{limitedRate}, __('Limited Rate') );
    # Check priority
    if ( defined( $ruleParams{priority} )) {
      $self->_checkPriority($ruleParams{priority});
    }
    # Check existence enabled
    $ruleParams{enabled} = 1 unless defined( $ruleParams{enabled} );

    my $iface = delete ( $ruleParams{interface} );

    # Check if it already exists rule (Done at model)

    # Get the lowest priority if no priority is provided
    if (not defined( $ruleParams{priority} )) {
      $ruleParams{priority} = $self->getLowestPriority($iface) + 1;
    }

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # Update priorities to be coherent with the remainders
    $self->_correctPriorities($iface);

    # Add admin logging
#    logAdminDeferred('trafficshaping',"addRule",
#		     "iface=$iface,protocol=$ruleParams{protocol},port=$ruleParams{port}," .
#		     "gRate=ruleParams{guaranteed_rate},lRate=$ruleParams{limited_rate}," .
#		     "priority=$ruleParams{priority},enabled=$ruleParams{enabled}");

#    return $ruleId;
    return undef;

  }

# Method: removeRule
#
#       Remove a custom rule. If the ruleId is given no more optional
#       are needed. The same in the order way around.
#
# Parameters:
#
#       interface      - interface under the rule is given
#       ruleId         - rule unique identifier *(Optional)*
#       protocol       - protocol *(Optional)*
#       port           - port number *(Optional)*
#       guaranteedRate - guaranteed rate in Kbit/s *(Optional)**
#       limitedRate    - limited rate in Kbit/s *(Optional)*
#
#       - Named parameters
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::DataNotFound> - throw if rule is not found
#      <EBox::Exceptions::External> - throw if interface is not external
#
sub removeRule
  {

    my ( $self, %args ) = @_;

    my $iface = delete $args{interface};
#    my $ruleId = delete $args {ruleId};

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $iface );

    # Check interface
    # $self->_checkInterface( $iface );

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # Destroy rule from builder
#   $self->_destroyRule( $iface, $ruleId, \%args);

    # Update priorities to be coherent with the remainders
    $self->_correctPriorities($iface);

    # Add admin logging
#    logAdminDeferred('trafficshaping',"removeRule",
#		     "iface=$iface,protocol=$entries{protocol},port=$entries{port}," .
#		     "gRate=$entries{guaranteed_rate},lRate=$entries{limited_rate}," .
#		     "priority=$entries{priority},$entries{enabled}");

  }

# Method: enableRule
#
#       Enable or disable a rule
#
# Parameters:
#
#       interface - interface under the rule is given
#       ruleId    - rule unique identifier
#       enabled   - set if rule is enabled or disabled
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::DataNotFound> - throw if rule is not found
#      <EBox::Exceptions::External> - throw if interface is not external
#
sub enableRule # (interface, ruleId, enabled)
  {

    my ( $self, $iface, $ruleId, $enabled ) = @_;

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $iface );
    throw EBox::Exceptions::MissingArgument( __('Identifier') )
      unless defined( $ruleId );
    throw EBox::Exceptions::MissingArgument( __('Enabled') )
      unless defined( $enabled );

    # Check interface and rule existence
    $self->_checkInterface( $iface );
    $self->_checkRuleExistence( $iface, $ruleId );

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # Update builder tree
#    $self->_enableRule($iface, $ruleId);

    # Admin log stuff
    my %entries = %{$self->_ruleParams( $iface, $ruleId )};

    if ( $enabled ) {
#      logAdminDeferred("trafficshaping","enableRule",
#		       "iface=$iface,protocol=$entries{protocol},port=$entries{port}," .
#		       "gRate=$entries{guaranteed_rate},lRate=$entries{limited_rate}," .
#		       "priority=$entries{priority}");
    }
    else {
#      logAdminDeferred("trafficshaping","disableRule",
#		       "iface=$iface,protocol=$entries{protocol},port=$entries{port}," .
#		       "gRate=$entries{guaranteed_rate},lRate=$entries{limited_rate}," .
#		       "priority=$entries{priority}");
    }

  }

# Method: updateRule
#
#       Update any component rule except enable/disable
#
# Parameters:
#
#       interface      - interface under the rule is given
#       ruleId         - rule unique identifier
#       - Named Parameters
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if any mandatory
#      parameter is not passed
#
#      <EBox::Exceptions::DataNotFound> - throw if rule is not found
#      <EBox::Exceptions::External> - throw if interface is not external
#
sub updateRule
  {

    my ($self, %args) = @_;

    my $iface          = delete $args{interface};
    my $ruleId         = $args{ruleId};

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $iface );
    throw EBox::Exceptions::MissingArgument( __('Identifier') )
      unless defined( $ruleId );

    # Check interface and rule existence
    $self->_checkInterface( $iface );
    $self->_checkRuleExistence( $iface, $ruleId );

    my $ruleParams_ref = $self->_ruleParams($iface, $ruleId);

    # Checking protocol and port done by model
#    if ( defined( $ruleParams_ref->{protocol} )) {
#      # Check protocol
#      checkProtocol( $ruleParams_ref->{protocol}, __('Protocol'));
#    }
#
#    if ( defined( $ruleParams_ref->{port} )) {
#      checkPort( $ruleParams_ref->{port}, __('Port'));
#    }

    if ( defined( $ruleParams_ref->{guaranteedRate} )) {
      $self->_checkRate( $ruleParams_ref->{guaranteedRate}, __('Guaranteed Rate'));
    }

    if ( defined( $ruleParams_ref->{limitedRate} )) {
      $self->_checkRate( $ruleParams_ref->{limitedRate}, __('Limited Rate'));
    }

    # Done at _correctPriorities
#    if ( defined( $priority )) {
#      $self->_checkPriority($priority);
#      # Set the new lowest priority
#      $self->_setNewLowestPriority($iface, $priority);
#    }

#    $ruleParams_ref->{priority} = $priority;

    # Setting standard rates if not defined
    $ruleParams_ref->{guaranteedRate} = 0 unless defined ( $ruleParams_ref->{guaranteedRate} );
    $ruleParams_ref->{guaranteedRate} = 0 if $ruleParams_ref->{guaranteedRate} eq '';
    $ruleParams_ref->{limitedRate} = 0 unless defined ( $ruleParams_ref->{limitedRate} );
    $ruleParams_ref->{limitedRate} = 0 if $ruleParams_ref->{limitedRate} eq '';

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # Already done by _createBuilders
#    $self->_updateRule( $iface, $ruleId, $ruleParams_ref );

    # Update priorities to be coherent with the remainders
    $self->_correctPriorities($iface);

    # Set logAdminAction only if any update is done
    if ( scalar(keys %args) > 2 ) {
      # Log update, only new data is available
#      $self->_logUpdate($ruleParams_ref);
    } # Only mandatory arguments are passed -> nothing to log

  }

# Method: checkRule
#
#       Check if the rule passed can be added. The guaranteed rate or
#       the limited rate should be given.
#
# Parameters:
#
#       interface      - interface under the rule is given
#       service        - <EBox::Types::Service> the service containing
#                        the inet protocol and port number *(Optional)*
#       source         - source. It could be an <EBox::Types::IPAddr>,
#                        <EBox::Types::MACAddr> or an object name (more info at
#                        <EBox::Objects>) *(Optional)*
#       destination    - destination. It could be an <EBox::Types::IPAddr>
#                        or an object name (more info at <EBox::Objects>) *(Optional)*
#       priority       - Int the rule priority *(Optional)*
#                        Default value: Lowest priority
#       guaranteedRate - maximum guaranteed rate in Kilobits per second *(Optional)*
#       limitedRate    - maximum allowed rate in Kilobits per second *(Optional)*
#       ruleId         - the rule identifier. It's given if the rule is
#                        gonna be updated *(Optional)*
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

    # Check if the protocol is all, source or destination is given
    if ( $ruleParams{service} ) {
      if ( not $ruleParams{service}->isa('EBox::Types::Service') ) {
	throw EBox::Exceptions::InvalidType( 'service',
					     'EBox::Types::Service');
      }
      if ( ( $ruleParams{service}->protocol() eq EBox::Types::Service->AnyProtocol ) and
	   ( (not $ruleParams{source}) and (not $ruleParams{destination}) ) ) {
	throw EBox::Exceptions::External(__('If service is any, some source or destination should be provided'));
      }
    }

    my $guaranteedMissing = ( not defined ( $ruleParams{guaranteedRate} )) ||
      ( $ruleParams{guaranteedRate} eq '' );
    my $limitedMissing = ( not defined ( $ruleParams{limitedRate} )) ||
      ( $ruleParams{limitedRate} eq '' );
    if ( $guaranteedMissing and $limitedMissing ) {
      throw EBox::Exceptions::MissingArgument( __('Guaranteed rate or limited rate') );
    }

    # Setting standard rates if not defined
    $ruleParams{guaranteedRate} = 0 unless defined ( $ruleParams{guaranteedRate} );
    $ruleParams{guaranteedRate} = 0 if $ruleParams{guaranteedRate} eq '';
    $ruleParams{limitedRate} = 0 unless defined ( $ruleParams{limitedRate} );
    $ruleParams{limitedRate} = 0 if $ruleParams{limitedRate} eq '';

    # Check rule avalaibility
    if ( ($self->_nextMap(undef, 'test') == MAX_ID_VALUE) and
         (not defined ($ruleParams{ruleId}))) {
      throw EBox::Exceptions::External(__x('The maximum rule account {max} is reached, ' .
					   'please delete at least one in order to to add a new one',
					   max => MAX_ID_VALUE));
    }

    # Check interface to be external
    $self->_checkInterface( $ruleParams{interface} );
    # Check protocol and port number (Already done by model)
    # Check source and destination (Already done by model)
    # Check source object
    my $gl = EBox::Global->getInstance();
    my $objs = $self->{'objects'};
    if ( defined ( $ruleParams{source} ) ) {
      if ( not ref $ruleParams{source} ) {
	# Check source object is an existant object
	unless ( $objs->objectExists($ruleParams{source}) or
		 $ruleParams{source} eq '') {
	  throw EBox::Exceptions::DataNotFound(
					       data => __('Source object'),
					       value => $ruleParams{source}
					      );
	}
      }
    }
    # Check destination object
    if ( defined ( $ruleParams{destination} ) ) {
      if ( not ref $ruleParams{destination} ) {
	# Check source object is an existant object
	unless ( $objs->objectExists($ruleParams{destination}) or
		 $ruleParams{destination} eq '') {
	  throw EBox::Exceptions::DataNotFound(
					       data => __('Destination object'),
					       value => $ruleParams{destination}
					      );
	}
      }
    }

    # Check rates
    $self->_checkRate( $ruleParams{guaranteedRate}, __('Guaranteed Rate') );
    $self->_checkRate( $ruleParams{limitedRate}, __('Limited Rate') );

    if ( defined ( $ruleParams{priority} ) ) {
      $self->_checkPriority( $ruleParams{priority} );
    }
    else {
      # Set the priority the lowest
      $ruleParams{priority} = 7;
    }

    # Set the rule enabled
    $ruleParams{enabled} = 'enabled';

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    if ( defined( $ruleParams{id} )) {
      # Try to update the rule
      $self->_updateRule( $ruleParams{interface}, $ruleParams{id}, \%ruleParams, 'test' );
    }
    else {
      # Try to build the rule
      $self->_buildRule( $ruleParams{interface}, \%ruleParams, 'test');
    }

    # If it works correctly, the write to gconf is done afterwards by
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
#         - service - <EBox::Types::Service> inet protocol
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

    my $gconfDir = $self->_ruleDirectory($iface);
    my @dir = @{$self->array_from_dir($gconfDir)};

    my @order = @{$self->get_list($gconfDir . '/order')};
    my %order;
    for( my $i = 0; $i < scalar(@order); $i++) {
      my $ordElement = $order[$i];
      $order{$ordElement} = $i;
    }

    my @rules;
    # If there's any
    if ( scalar(@dir) != 0 ) {
      # Change _dir to ruleId for readibility reasons
      foreach my $rule_ref (@dir) {
	$rule_ref->{ruleId} = delete ($rule_ref->{_dir});
	$rule_ref->{service} = new EBox::Types::Service( fieldName => 'service');
	$rule_ref->{service}->setMemValue($rule_ref);

	if ( defined ( $rule_ref->{$rule_ref->{source_selected}} ) ) {
	  if ( $rule_ref->{source_selected} eq 'source_ipaddr' ) {
	    $rule_ref->{source} = new EBox::Types::IPAddr( fieldName => 'source_ipaddr' );
	    $rule_ref->{source}->setMemValue($rule_ref);
	  }
	  elsif ( $rule_ref->{source_selected} eq 'source_macaddr' ) {
	    $rule_ref->{source} = new EBox::Types::MACAddr( fieldName => 'source_macaddr' );
	    $rule_ref->{source}->setMemValue($rule_ref);
	  }
	  elsif ( $rule_ref->{source_selected} eq 'source_object' ) {
	    $rule_ref->{source} = delete ( $rule_ref->{source_object} );
	  }
	}

	if ( defined ( $rule_ref->{$rule_ref->{destination_selected}} )) {
	  if ( $rule_ref->{destination_selected} eq 'destination_ipaddr' ) {
	    $rule_ref->{destination} = new EBox::Types::IPAddr( fieldName => 'destination_ipaddr' );
	    $rule_ref->{destination}->setMemValue($rule_ref);
	  }
	  elsif ( $rule_ref->{destination_selected} eq 'destination_object' ) {
	    $rule_ref->{destination} = delete ( $rule_ref->{destination_object} );
	  }
	}
	# FIXME: enabled and disable
	$rule_ref->{enabled} = 'enabled';
	$rule_ref->{priority} = $order{$rule_ref->{ruleId}};
	push(@rules, $rule_ref);
      }
    }

    return \@rules;

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

# Method: setLowestPriority
#
#       Mutator to the lowest priority.
#
# Parameters:
#
#       interface - interface name
#       priority  - the lowest priority
#
sub setLowestPriority # (interface, priority)
  {

    my ($self, $iface, $priority) = @_;

    $self->{lowestPriority} = $priority;
#    $self->set_int("$iface/user_rules/lowest_priority", $priority);

    return;

  }

# Method: ruleModel
#
#       Return the model associated to the rules table
#
# Parameters:
#
#       interface - String external interface attached to the rule table model
#
# Returns:
#
#       <EBox::TrafficShaping::Model::RuleTable>
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::External> - throw if interface is not external
#

sub ruleModel # (iface)
  {

    my ($self, $iface) = @_;

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $iface );

    if ( not defined ($self->{ruleModels}->{$iface})) {
      $self->_checkInterface($iface);
      # Create the rule model if it's not already created
      $self->{ruleModels}->{$iface} = new EBox::TrafficShaping::Model::RuleTable(
										 'gconfmodule' => $self,
										 'directory'   => "$iface/user_rules",
										 'tablename'   => 'rule',
										 'interface'   => $iface,
										);
    }

    return $self->{ruleModels}->{$iface};

  }

# Method: ruleMultiTableModel
#
#      Get the rule multi table model to be shown
#
# Returns:
#
#      <EBox::TrafficShaping::Model::RuleMultiTable> - the rule
#      multitable model
#
sub ruleMultiTableModel
  {

    my ($self) = @_;

    return $self->{ruleMultiTableModel};

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
    }
    elsif ( $where eq 'ingress' ) {
      return 'EBOX-SHAPER-IN-' . $iface;
    }
    elsif ( $where eq 'forward' ) {
      # For MAC addresses and internal interfaces
      return 'EBOX-SHAPER-FORWARD-' . $iface;
    }

  }

###################################
# Network Observer Implementation
###################################

# Method: ifaceExternalChanged
#
#        See <EBox::NetworkObserver::ifaceExternalChanged>.
#
sub ifaceExternalChanged # (iface, external)
  {

    my ($self, $iface, $external) = @_;

    # Check if any interface is being shaped
    return $self->_areRulesActive($iface);

  }

# Method: freeIfaceExternal
#
#        See <EBox::NetworkObserver::freeIfaceExternal>.
#
sub changeIfaceExternalProperty # (iface, external)
  {

    my ($self, $iface, $external) = @_;

    my $dir = $self->_ruleDirectory($iface);

    if ( $self->dir_exists($dir) ) {
      $self->_destroyIface($iface);
    }

    return undef;

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

    $self->_destroyIface($iface);

    return undef;

  }



###################################
# Private Methods
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

    if ( defined( $priority ) ){
      # Check only with the currently lowest priority
      if ( $priority > $self->getLowestPriority($iface) ){
	$self->setLowestPriority($iface, $priority);
      }
    }
    else {
      # Check all priority entries from within given interface
      my $ruleDir = $self->_ruleDirectory($iface);

      my $dirs_ref = $self->array_from_dir($ruleDir);

      # Search for the lowest at array
      my $lowest = 0;
      foreach my $rule_ref (@{$dirs_ref}) {
	$lowest = $rule_ref->{priority} if ( $rule_ref->{priority} > $lowest );
      }
      # Set lowest
      $self->setLowestPriority($iface, $lowest);
    }

  }

# Update priorities to all rules
# Taking data from GConf stored values
sub _correctPriorities # (iface)
  {

    my ($self, $iface) = @_;

    my $order_ref = $self->{ruleModels}->{$iface}->order();
    my $builder = $self->{builders}->{$iface};

    if ($builder->isa('EBox::TrafficShaping::TreeBuilder::HTB') ) {
      # Starting with highest priority update priority
      my $priority = 0;
      foreach my $ruleId (@{$order_ref}) {
	my $leafClassId = $self->_mapRuleToClassId($ruleId);
	$self->{builders}->{$iface}->updateRule(
						identifier  => $leafClassId,
						priority    => $priority,
					       );
	$priority++;
      }
      # Set the lowest priority
      $self->setLowestPriority($iface, $priority);
    }

  }

###
# Rule model helper methods
###

# set every external interface to have a model
sub _createRuleModels
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $network = $self->{'network'}; 

    my $ifaces_ref = $network->ifaces();
    foreach my $iface (@{$ifaces_ref}) {
      $self->{ruleModels}->{$iface} = new EBox::TrafficShaping::Model::RuleTable(
				    'gconfmodule' => $self,
				    'directory'   => "$iface/user_rules",
				    'tablename'   => 'rule',
				    'interface'   => $iface,
										);
    }

    $self->{ruleMultiTableModel} = new EBox::TrafficShaping::Model::RuleMultiTable();

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

#    use Devel::StackTrace;
#    my $trace = Devel::StackTrace->new;
#    EBox::debug($trace->as_string());

    my $global = EBox::Global->getInstance();
    my $network = $self->{'network'}; 

    # Now shaping can be done at internal interfaces to egress traffic
#    if (not $network->ifaceIsExternal( $iface )) {
#      throw EBox::Exceptions::External(
#				       __x('Traffic shaping can be only done in external interface and {iface} is not',
#					   iface => $iface)
#				      );
#    }

    # If the interface doesn't exist, launch an DataNotFound exception
    if ( not $network->ifaceExists( $iface )) {
      throw EBox::Exceptions::DataNotFound( data => __('Interface'),
					    value => $iface
					  );
    }

    # If it's an external interface, check the gateway
    if ( $network->ifaceIsExternal( $iface )) {
      # Check it has gateways associated
      my $gateways_ref = $network->gateways();

      my @gatewaysIface = grep { $_->{interface} eq $iface } @{$gateways_ref};

      if ( scalar (@gatewaysIface) <= 0 ) {
	throw EBox::Exceptions::External(
					 __('Traffic shaping can be only done in external interfaces ' .
					    'which have gateways associated to')
					);
      }
    }

    

    return;

  }

# Check rule if exist
# Throw DataNotFound if not, nothing otherwise
sub _checkRuleExistence # (iface, ruleId)
  {

    my ($self, $iface, $ruleId) = @_;

    # In god we trust. Actually, this code is not necessary any longer
    
    return 1;
    my $dir = $self->_ruleDirectory($iface, $ruleId);

    if (not $self->dir_exists("$dir") ) {
      throw EBox::Exceptions::DataNotFound(
					   data  => __('Traffic Shaping Rule'),
					   value => $iface . "/" . $ruleId,
					  );
    }

    return 1;

  }

# Check rate
# Throw InvalidData if it's not a positive number
sub _checkRate # (rate, printableName)
  {

    my ($self, $rate, $printableName) = @_;

    if ( $rate < 0 ) {
      throw EBox::Exceptions::InvalidData(
					  'data'  => $printableName,
					  'value' => $rate,
					 );
    }

    return 1;

  }

# Check priority
# Throw InvalidData if it's not a positive number
sub _checkPriority # (priority)
  {

    my ($self, $priority) = @_;

    if ( ($priority < 0) or ($priority > 7) ) {
      throw EBox::Exceptions::InvalidData(
					  'data'  => __('Priority'),
					  'value' => $priority,
					 );
    }

    return 1;

  }

# Check if there are rules are active within a given interface
# Returns true if any, false otherwise
sub _areRulesActive # (iface)
  {
    my ($self, $iface) = @_;

    my $dir = $self->_ruleDirectory($iface);

    my $rules_ref = $self->array_from_dir($dir);

    if ( scalar(@{$rules_ref}) != 0 ) {
      # Check if there's any enabled TODO
#      foreach my $rule_ref (@{$rules_ref}) {
#	if ( $rule_ref->{enabled} ) {
#	  return 1;
#	}
#      }
      return 1;
     }
    # No rules are active
    return undef;

  }

###
# GConf related functions
###

# Given an interface and optionally a rule returns the directory
# within GConf
sub _ruleDirectory # (iface, ruleId?)
  {

    my ($self, $iface, $ruleId) = @_;

    my $dir = $self->ruleModel($iface)->directory() . '/keys';
    

    if ( defined ($ruleId) ) {
      return "$dir/$ruleId";
    }
    else {
      return $dir;
    }

  }

# Given a rule identifier and an interface, get its params
# in an hash ref
sub _ruleParams # (iface, ruleId)
  {

    my ($self, $iface, $ruleId) = @_;

    my $dir = $self->_ruleDirectory($iface, $ruleId);

    my $ruleParams_ref = $self->hash_from_dir($dir);

    # Transform gconf-like to camel case
    $ruleParams_ref->{guaranteedRate} = delete $ruleParams_ref->{guaranteed_rate};
    $ruleParams_ref->{limitedRate} = delete $ruleParams_ref->{limited_rate};

    return $ruleParams_ref;

  }


# Underlying stuff (Come to the mud)

# Method: _createTree
#
#       Creates a tree with the builder within an interface.
#
# Parameters:
#
#       interface - interface's name to create the tree
#       type - HTB, default or HFSC
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
      # Get the rate from Network
      my $linkRate;
#     FIXME
#     $linkRate = $self->{network}->ifaceUploadRate($iface)
      # Check if interface is internal or external to set a maximum rate
      # The maximum rate for an internal interface is the sum of the gateways associated
      # to the external interfaces

      my $global = EBox::Global->getInstance();
      my $network = $self->{'network'}; 
      if ( $network->ifaceIsExternal($iface) ) {
	$linkRate = $self->_uploadRate($iface);
      }
      else {
	$linkRate = $self->_totalDownloadRate();
      }

      if ( not defined($linkRate) or $linkRate == 0) {
	throw EBox::Exceptions::External(__x("Interface {iface} should have a maximum " .
					     "bandwidth rate in order to do traffic shaping",
					     iface => $iface));
      }
      $self->{builders}->{$iface}->buildRoot(21, $linkRate);
    }
    elsif ( $type eq "HFSC" ) {
      ;
    }

  }

# Build the tree from gconf variables stored.
# It assumes rules are correct
sub _buildGConfRules # (iface)
  {

    my ($self, $iface) = @_;

    my $dir = $self->_ruleDirectory($iface);

    # Set the priority
    my $rules_ref = $self->array_from_dir($dir);

    foreach my $rule_ref (@{$rules_ref}) {
      # next if it's not an enabled rule
      # FIXME when enabled property will be on
      #      next unless ( $rule_ref->{enabled} );

      # $rule_ref->{identifier} = $rule_ref->{_dir};
      $rule_ref->{identifier} = $self->_nextMap($rule_ref->{_dir});
      $rule_ref->{identifier} = $self->_getNumber($rule_ref->{identifier});
      # Get the port and protocol
      $rule_ref->{service} = new EBox::Types::Service(
						      protocol => delete ( $rule_ref->{service_protocol} ),
						      port     => delete ( $rule_ref->{service_port} ),
						     );

      # Get the source
      if ( defined ( $rule_ref->{source_selected} )) {
	my $sourceSelected = delete ( $rule_ref->{source_selected} );
	if ( $sourceSelected eq 'source_ipaddr' ) {
	  $rule_ref->{source} = new EBox::Types::IPAddr(
							ip   => delete ( $rule_ref->{source_ipaddr_ip} ),
							mask => delete ( $rule_ref->{source_ipaddr_mask} ),
						       );
	} elsif ( $sourceSelected eq 'source_macaddr' ) {
	  $rule_ref->{source} = new EBox::Types::MACAddr(
							 value => delete ( $rule_ref->{source_macaddr} )
							);
	} elsif ( $sourceSelected eq 'source_object' ) {
	  $rule_ref->{source} = delete ( $rule_ref->{source_object} );
	}
      }

      # Get the destination
      if ( defined ( $rule_ref->{destination_selected} )) {
	my $destinationSelected = delete ( $rule_ref->{destination_selected} );
	if ( $destinationSelected eq 'destination_ipaddr' ) {
	  $rule_ref->{destination} = new EBox::Types::IPAddr(
							     ip   => delete ( $rule_ref->{destination_ipaddr_ip} ),
							     mask => delete ( $rule_ref->{destination_ipaddr_mask} ),
							    );
	} elsif ( $destinationSelected eq 'destination_object' ) {
	  $rule_ref->{destination} = delete ( $rule_ref->{destination_object} );
	}
      }

      # Transform from gconf to camelCase and set if they're null
      # since they're optional parameters
      $rule_ref->{guaranteedRate} = delete ($rule_ref->{guaranteed_rate});
      $rule_ref->{guaranteedRate} = 0 unless defined ($rule_ref->{guaranteedRate});
      $rule_ref->{limitedRate} = delete ($rule_ref->{limited_rate});
      $rule_ref->{limitedRate} = 0 unless defined ($rule_ref->{limitedRate});
      # Get priority from priority field
#      $rule_ref->{priority} = $order{$rule_ref->{_dir}};

      $self->_buildANewRule( $iface, $rule_ref, undef );

    }

  }

# Create builders and they are stored in builders
sub _createBuilders
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $network = $self->{'network'}; 

    my @ifaces = @{$network->ifaces()};

    foreach my $iface (@ifaces) {
      $self->{builders}->{$iface} = {};
      if ( $self->_areRulesActive($iface) ) {
	# If there's any rule, for now use an HTBTreeBuilder
	$self->_createTree($iface, "HTB");
	# Build every rule and stores the identifier in gconf to destroy
	# them afterwards
	$self->_buildGConfRules($iface);
      }
      else {
	# For now, if no user_rules are given, use DefaultTreeBuilder
	$self->_createTree($iface, "default");
      }
    }

  }

# Build a new rule to the tree
# If not rules has been set or they're not enabled no added is made
sub _buildRule # ($iface, $rule_ref, $test)
  {

    my ( $self, $iface, $rule_ref, $test ) = @_;

    if ( $self->{builders}->{$iface}->isa('EBox::TrafficShaping::TreeBuilder::Default') ) {
      if (not $rule_ref->{enabled} ) {
	return;
      }
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

    if ( $htbBuilder->isa('EBox::TrafficShaping::TreeBuilder::HTB')){
      my $src = undef;
      my $srcObj = undef;
      if ( ( defined ( $rule_ref->{source} )
	     and $rule_ref->{source} ne '' ) and
	   ( $rule_ref->{source}->isa('EBox::Types::IPAddr') or
	     $rule_ref->{source}->isa('EBox::Types::MACAddr'))
	 ) {
	$src = $rule_ref->{source};
	$srcObj = undef;
      }
      else {
	# If an object is provided no source is needed to set a rule but
	# then attaching filters according to members of this object
	$src = undef;
	$srcObj =  $rule_ref->{source};
      }

      # The same related to destination
      my $dst = undef;
      my $dstObj = undef;
      if ( ( defined ( $rule_ref->{destination} ) and
	     $rule_ref->{destination} ne '' ) and
	   ( $rule_ref->{destination}->isa('EBox::Types::IPAddr'))) {
	$dst = $rule_ref->{destination};
	$dstObj = undef;
      }
      else {
	# If an object is provided no source is needed to set a rule but
	# then attaching filters according to members of this object
	$dst = undef;
	$dstObj =  $rule_ref->{destination} ;
      }

      # Set a filter with objects if src or dst are not objects
      my $service = undef;
      $service = $rule_ref->{service} unless ( $srcObj or $dstObj );

      $htbBuilder->buildRule(
			     service        => $service,
			     source         => $src,
			     destination    => $dst,
			     guaranteedRate => $rule_ref->{guaranteedRate},
			     limitedRate    => $rule_ref->{limitedRate},
			     priority       => $rule_ref->{priority},
			     identifier     => $rule_ref->{identifier},
			     testing        => $test,
			    );
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
	}
	elsif ( $dstObj and not $srcObj ) {
	  $self->_buildObjMembers(
				  treeBuilder  => $htbBuilder,
				  what         => 'destination',
				  objectName   => $rule_ref->{destination},
				  ruleRelated  => $rule_ref->{identifier},
				  serviceAssoc => $rule_ref->{service},
				  where        => $rule_ref->{source},
				  rulePriority => $rule_ref->{priority},
				 );
	}
	elsif ( $dstObj and $srcObj ) {
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

    }
    else {
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

    unless ( $objectName ) {
      return;
    }

    # Get the object's members
    my $global = EBox::Global->getInstance();
    my $objs = $self->{'objects'}; 

    my $membs_ref = $objs->objectMembers($objectName);

    # Set a different filter identifier for each object's member
    my $filterId = $ruleRelated;
    foreach my $member_ref (@{$membs_ref}) {
      my $ip = new EBox::Types::IPAddr(
				       ip => $member_ref->{ip},
				       mask => $member_ref->{mask},
				      );
      my $srcAddr;
      my $dstAddr;
      if ( $what eq 'source' ) {
	$srcAddr = $ip;
	$dstAddr = $where;
      }
      elsif ( $what eq 'destination') {
	$srcAddr = $where;
	$dstAddr = $ip;
      }
      $treeBuilder->addFilter(
			      leafClassId => $ruleRelated,
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
#	my $mac = new EBox::Types::MACAddr(
#					   value => $member_ref->{mac},
#					  );
#	$filterValue->{srcAddr} = $mac;
#	$filterValue->{dstAddr} = $where;
#	$treeBuilder->addFilter( leafClassId => $ruleRelated,
#				 filterValue => $filterValue);
#	$filterId++;
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

    my $global = EBox::Global->getInstance();
    my $objs = $self->{'objects'}; 

    my $srcMembs_ref = $objs->objectMembers($args{srcObject});
    my $dstMembs_ref = $objs->objectMembers($args{dstObject});

    my $filterId = $args{ruleRelated};

    foreach my $srcMember_ref (@{$srcMembs_ref}) {
      my $srcAddr = new EBox::Types::IPAddr(
					    ip   => $srcMember_ref->{ip},
					    mask => $srcMember_ref->{mask},
					   );
      foreach my $dstMember_ref (@{$dstMembs_ref}) {
	my $dstAddr = new EBox::Types::IPAddr(
					      ip   => $dstMember_ref->{ip},
					      mask => $dstMember_ref->{mask},
					     );
	$args{treeBuilder}->addFilter(
				      leafClassId => $args{ruleRelated},
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


# Get a rule given all its parameters in GConf
# undef if not found
sub _getRuleId  # (iface, inRule_ref)
  {
    my ($self, $iface, $inRule_ref) = @_;

    my $dir = $self->_ruleDirectory($iface);

    my $rules_ref = $self->array_from_dir($dir);

    my $ruleId = undef;
    foreach my $rule_ref (@{$rules_ref}) {

      # Service
      if ( defined ( $rule_ref->{service_protocol} ) and
	   defined ( $inRule_ref->{protocol})) {
	next unless $rule_ref->{service_protocol} eq $inRule_ref->{protocol};
      }
      else {
	next;
      }
      if ( defined ( $rule_ref->{service_port} ) and
	   defined ( $inRule_ref->{port}) ) {
	next unless $rule_ref->{service_port} == $inRule_ref->{port};
      }
      else {
	next;
      }

      # Source
      if ( defined ( $rule_ref->{source_selected} ) ) {
	if ( defined ( $rule_ref->{source_ipaddr_ip} ) and
	     defined ( $inRule_ref->{source} ) and
	     $inRule_ref->{source}->isa('EBox::Types::IPAddr') ) {
	  next unless $rule_ref->{source_ipaddr_ip} eq $inRule_ref->{source}->ip() and
	    $rule_ref->{source_ipaddr_mask} eq $inRule_ref->{source}->mask();
	}
	if ( defined ( $rule_ref->{source_macaddr} ) and
	     defined ( $inRule_ref->{source} ) and
	     $inRule_ref->{source}->isa('EBox::Types::MACAddr') ) {
	  next unless $rule_ref->{source_macaddr} eq $inRule_ref->{source}->value();
	}
	if ( defined ( $rule_ref->{source_object} ) and
	     defined ( $inRule_ref->{source} ) ) {
	  next unless $rule_ref->{source_object} eq $inRule_ref->{source};
	}
      }

      # Destination
      if ( defined ( $rule_ref->{destination_selected} ) ) {
	if ( defined ( $rule_ref->{destination_ipaddr_ip} ) and
	     defined ( $inRule_ref->{destination} ) and
	     $inRule_ref->{destination}->isa('EBox::Types::IPAddr') ) {
	  next unless $rule_ref->{destination_ipaddr_ip} eq $inRule_ref->{destination}->ip() and
	    $rule_ref->{destination_ipaddr_mask} eq $inRule_ref->{destination}->mask();
	}
	if ( defined ( $rule_ref->{destination_object} ) and
	     defined ( $inRule_ref->{destination} ) ) {
	  next unless $rule_ref->{destination_object} eq $inRule_ref->{destination};
	}
      }

      # Guaranteed rate
      if ( defined ( $rule_ref->{guaranteed_rate} ) and
	   defined ( $inRule_ref->{guaranteedRate} )) {
	next unless $rule_ref->{guaranteed_rate} == $inRule_ref->{guaranteedRate};
      }
      else {
	next;
      }

      # Limited rate
      if ( defined ( $rule_ref->{limited_rate} ) and
	   defined ( $inRule_ref->{limitedRate} )) {
	next unless $rule_ref->{limited_rate}    == $inRule_ref->{limitedRate};
      }
      else {
	next;
      }

      # You found it!
      $ruleId = $rule_ref->{_dir};
      last;
    }

    return $ruleId;

  }

# Destroy a rule from the builder taking arguments from GConf
sub _destroyRule # (iface, ruleId, params_ref?)
  {

   my ($self, $iface, $ruleId, $params_ref) = @_;

   if ($self->{builders}->{$iface}->isa('EBox::TrafficShaping::TreeBuilder::Default')) {
     # Nothing to destroy
     return;
   }

   # my $minorNumber = $self->_getNumber($ruleId);
   my $minorNumber = $self->_mapRuleToClassId($ruleId);
   $self->{builders}->{$iface}->destroyRule($minorNumber);

   # If no more rules are active, build a default tree builder
   if (not $self->_areRulesActive($iface) ) {
     $self->_createTree($iface, "default");
   }

 }

# Enable a rule from the builder taking arguments from GConf
sub _enableRule # (iface, ruleId)
  {

    my ($self, $iface, $ruleId) = @_;

    my $rule_ref = $self->_ruleParams($iface, $ruleId);

    # TODO: Check enability

    if ( $rule_ref->{enabled} ) {
      $self->_buildRule($iface, $ruleId, $rule_ref);
    }
    else {
      $self->_destroyRule($iface, $ruleId);
    }

    return;

  }

# Update a rule from the builder taking arguments from GConf
sub _updateRule # (iface, ruleId, ruleParams_ref?, test?)
  {

    my ($self, $iface, $ruleId, $ruleParams_ref, $test) = @_;

    # my $minorNumber = $self->_getNumber($ruleId);
    my $minorNumber = $self->_mapRuleToClassId($ruleId);
    # Update the rule stating the same leaf class id (If test not do)
    $self->{builders}->{$iface}->updateRule(
					    identifier     => $minorNumber,
					    protocol       => $ruleParams_ref->{protocol},
					    port           => $ruleParams_ref->{port},
					    source         => $ruleParams_ref->{source},
					    destination    => $ruleParams_ref->{destination},
					    guaranteedRate => $ruleParams_ref->{guaranteedRate},
					    limitedRate    => $ruleParams_ref->{limitedRate},
					    priority       => $ruleParams_ref->{priority},
					    testing        => $test,
					   );

  }


###
# Naming convention helper functions
###

# Get the number from an identifier with the following pattern: letters+numbers+
sub _getNumber # (id)
  {

    my ($self, $id) = @_;

    my $tmpId = $id;

    $tmpId =~ s/.*?(\d+)/$1/;

    return $tmpId;

  }

# Set the identifiers to the correct intervals with this function
# (Ticket #481)
# Returns a Int among MIN_ID_VALUE and MAX_ID_VALUE
sub _nextMap # (ruleId?, test?)
  {

    my ($self, $ruleId, $test) = @_;

    if ( not defined ( $self->{nextIdentifier} ) ) {
      $self->{nextIdentifier} = MIN_ID_VALUE;
      $self->{classIdMap} = {};
    }

    my $retValue = $self->{nextIdentifier};

    if ( defined ( $ruleId ) and not $test ) {
      # We store at a hash the ruleId vs. class id
      $self->{classIdMap}->{$ruleId} = $retValue;
    }

    if ( $self->{nextIdentifier} < MAX_ID_VALUE and
        (not $test)) {
      # Sums min id value -> 0x100
      $self->{nextIdentifier} += MIN_ID_VALUE;
    }

    return $retValue;

  }

# Returns the class id mapped at a rule identifier
# Undef if no map has been created
sub _mapRuleToClassId # (ruleId)
  {

    my ($self, $ruleId) = @_;

    if ( defined ( $self->{classIdMap} )) {
      return $self->{classIdMap}->{$ruleId};
    }
    else {
      return undef;
    }

  }

# Changes from CamelCase to GConf
# Returns the same string with underscores instead of camel case
sub _CamelCase_to_underscore # (string)
  {

    my ( $str ) = @_;

    my $retValue = $str;
    # The change
    $retValue =~ s/(\p{IsLu}+)/_\L$1\E/g;

    return $retValue;

  }

###
# Workaround related to upload rate from an external interface
###

# Get the upload rate from an interface in kilobits per second
# FIXME: Change when the ticket #373
sub _uploadRate # (iface)
  {

    my ($self, $iface) = @_;

    my $global = EBox::Global->getInstance();
    my $net = $self->{'network'}; 

    my $gateways_ref = $net->gateways();

    my $sumUpload = 0;
    foreach my $gateway_ref (@{$gateways_ref}) {
      if ($gateway_ref->{interface} eq $iface) {
	$sumUpload += $gateway_ref->{upload};
      }
    }

    return $sumUpload;

  }

# Get the total download rate from the external interfaces in kilobits
# per second
# FIXME: Change when the ticket #373
sub _totalDownloadRate
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $net = $self->{'network'}; 

    my $gateways_ref = $net->gateways();

    my $sumDownload = 0;

    foreach my $gateway_ref (@{$gateways_ref}) {
      if ( $net->ifaceIsExternal($gateway_ref->{interface}) ) {
	  $sumDownload += $gateway_ref->{download};
      }
    }

    return $sumDownload;

  }

###
# Network observer helper functions
###

# Destroy an interface, called by Network
sub _destroyIface # (iface)
  {

    my ($self, $iface) = @_;

    # Take all rules from this interface
    my $rules_ref = $self->listRules($iface);

    if ( defined ($rules_ref) ) {
      foreach my $rule_ref (@{$rules_ref}) {
	# Remove each rule inside this interface
	$self->removeRule(
			  interface => $iface,
			  ruleId    => $rule_ref->{ruleId},
			 );
      }
    }

    # Remove model
    $self->{ruleModels}->{$iface} = undef;

  }

###
# Log Admin related functions
###

# Admin log related to update rule
# References to the old dir and new dir are passed
sub _logUpdate # (new_ref)
  {
    my ($self, $new_ref) = @_;

    # Strings to print to log
    my $newValues = q{};

    $newValues .= " " . __("Protocol") . " " . $new_ref->{protocol};
    $newValues .= " " . __("Port") . " " . $new_ref->{port};
    $newValues .= " " . __("Guaranteed Rate") . " " . $new_ref->{guaranteedRate};
    $newValues .= " " . __("Limited Rate") . " " . $new_ref->{limitedRate};
    $newValues .= " " . __("Priority") . " " . $new_ref->{priority};

#    logAdminDeferred("trafficshaping", "updateRule",
#		     "values=$newValues");

  }

# Set the actions to log
sub _setLogAdminActions
  {

    my ($self) = @_;

    $self->{actions} = {};
#    $self->{actions}->{addRule} = __n("Added rule under interface: {iface} with protocol: " .
#				      "{protocol} port: {port} guaranteed " .
#				      "rate: {gRate} limited rate to: {lRate} ".
#				      "priority: {priority} enabled: {enabled}");
#    $self->{actions}->{removeRule} = __n("Removed rule under interface: {iface} with protocol: " .
#					 "{protocol} port: {port} guaranteed " .
#					 "rate: {gRate} limited rate to: {lRate} ".
#					 "priority: {priority} enabled: {enabled}");
#    $self->{actions}->{enableRule} = __n("Enabled rule under interface: {iface} with protocol: " .
#					 "{protocol} port: {port} guaranteed " .
#					 "rate: {gRate} limited rate to: {lRate} ".
#					 "priority: {priority}");
#    $self->{actions}->{disableRule} = __n("Disabled rule under interface: {iface} with protocol: " .
#					 "{protocol} port: {port} guaranteed " .
#					 "rate: {gRate} limited rate to: {lRate} ".
#					 "priority: {priority}");
#
#    $self->{actions}->{updateRule} = __n("Update rule under interface: {iface} for the following " .
#					 "values:{values}");

  }

###################################
# Iptables related functions
###################################

# Delete TrafficShaping filter chain in Iptables Linux kernel struct
sub _deleteChains # (iface)
  {

    my ( $self, $iface ) = @_;

    my %types = (
		 'egress'  => [ 'POSTROUTING', '-o'],
 		 'ingress' => [ 'PREROUTING' , '-i'],
		 'forward' => [ 'FORWARD'    , '-o'],
		);

    foreach my $type (keys %types) {
      my $shaperChain = $self->ShaperChain($iface, $type);
      try {
	$self->{ipTables}->pf( '-t mangle -D ' . $types{$type}->[0] . ' ' . $types{$type}->[1] .
			       " $iface -j $shaperChain" );
	$self->{ipTables}->pf( "-t mangle -F $shaperChain" );
	$self->{ipTables}->pf( "-t mangle -X $shaperChain" );
      } catch EBox::Exceptions::Sudo::Command with {
	my $exception = shift;
	if ($exception->exitValue() == 2 or
	    $exception->exitValue() == 1) {
	  # The chain does not exist, ignore
	  ;
	} else {
	  $exception->throw();
	}
	;
      }
    }

  }

sub _resetChain # (iface)
  {

    my ($self, $iface) = @_;

    # Delete any previous chain
    $self->_deleteChains($iface);

    my %types = (
		 'egress'  => [ 'POSTROUTING', '-o'],
 		 'ingress' => [ 'PREROUTING' , '-i'],
		 'forward' => [ 'FORWARD'    , '-o'],
		);

    foreach my $type (keys %types) {
      my $shaperChain = $self->ShaperChain($iface, $type);

      # Add the chain
      try {
	$self->{ipTables}->pf( "-t mangle -N $shaperChain" );
	$self->{ipTables}->pf( '-t mangle -I ' . $types{$type}->[0] . ' ' . $types{$type}->[1] .
			       " $iface -j $shaperChain" );
      } catch EBox::Exceptions::Sudo::Command with {
	my $exception = shift;
	if ($exception->exitValue() == 1) {
	  # The chain already exists, do only the rule
	  $self->{ipTables}->pf( '-t mangle -I ' . $types{$type}->[0] . ' ' . $types{$type}->[1] .
				 " $iface -j $shaperChain" );
	}
      }
    }

  }

# Execute an array of iptables commands
sub _executeIptablesCmds # (iptablesCmds_ref)
  {

    my ($self, $iptablesCmds_ref) = @_;

    foreach my $ipTablesCmd (@{$iptablesCmds_ref}) {
      EBox::info("iptables $ipTablesCmd");
      $self->{ipTables}->pf($ipTablesCmd);
    }

  }

1;
