# Copyright (C) 2006 Warp Networks S.L.
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

# Constructor for traffic shaping module
sub _create
  {
    my $class = shift;
    my $self = $class->SUPER::_create(name   => 'trafficshaping',
				      domain => 'ebox-trafficshaping',
				      title  => __('Traffic Shaping'),
				      @_);

#    $self->_setLogAdminActions();

#    my $global = EBox::Global->getInstance();
#    $self->{network} = $global->modInstance('network');

    # Create rule models
    $self->_createRuleModels();

    # Create wrappers
    $self->{tc} = EBox::TC->new();
    $self->{ipTables} = EBox::Iptables->new();

    # Create tree builders
    $self->_createBuilders();

    bless($self, $class);

    return $self;
  }

sub _regenConfig
  {

    my ($self) = @_;

    # FIXME

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
#       protocol       - inet protocol
#       port           - port number
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
#       String - the unique identifier which identifies the added rule
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
    throw EBox::Exceptions::MissingArgument( __('Protocol') )
      unless defined( $ruleParams{protocol} );
    throw EBox::Exceptions::MissingArgument( __('Port') )
      unless defined( $ruleParams{port} );

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
    # Check protocol
    checkProtocol( $ruleParams{protocol}, __('Protocol'));
    # Check port number
    checkPort( $ruleParams{port}, __('Port'));
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

    # Check already exist rule (Done at model)
    # $self->_checkDuplicate($iface, \%ruleParams);

    # Get the lowest priority if no priority is provided
    if (not defined( $ruleParams{priority} )) {
      $ruleParams{priority} = $self->getLowestPriority($iface) + 1;
    }

    my $ruleId = $self->_getRuleId($iface, \%ruleParams);
    # Get only the number
    $ruleId = $self->_getNumber($ruleId);
    $ruleParams{identifier} = $ruleId;

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    # It can throw External exceptions if not possible to build the rule
#    my $classId = $self->_buildRule($iface, \%ruleParams, undef);

    # Store class identifier in GConf
#    $self->_setClassId($iface, $ruleId, $classId);

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
    my $ruleId = delete $args {ruleId};

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
    $self->_enableRule($iface, $ruleId);

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
#       priority       - rule priority (lower number, highest priority)
#                        *(Optional)*
#
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
    my $priority       = $args{priority};

    throw EBox::Exceptions::MissingArgument( __('Interface') )
      unless defined( $iface );
    throw EBox::Exceptions::MissingArgument( __('Identifier') )
      unless defined( $ruleId );

    # Check interface and rule existence
    $self->_checkInterface( $iface );
    $self->_checkRuleExistence( $iface, $ruleId );

    my $ruleParams_ref = $self->_ruleParams($iface, $ruleId);

    if ( defined( $ruleParams_ref->{protocol} )) {
      # Check protocol
      checkProtocol( $ruleParams_ref->{protocol}, __('Protocol'));
    }

    if ( defined( $ruleParams_ref->{port} )) {
      checkPort( $ruleParams_ref->{port}, __('Port'));
    }

    if ( defined( $ruleParams_ref->{guaranteedRate} )) {
      $self->_checkRate( $ruleParams_ref->{guaranteedRate}, __('Guaranteed Rate'));
    }

    if ( defined( $ruleParams_ref->{limitedRate} )) {
      $self->_checkRate( $ruleParams_ref->{limitedRate}, __('Limited Rate'));
    }

    if ( defined( $priority )) {
      $self->_checkPriority($priority);
      # Set the new lowest priority
      $self->_setNewLowestPriority($iface, $priority);
    }

    $ruleParams_ref->{priority} = $priority;

    # Setting standard rates if not defined
    $ruleParams_ref->{guaranteedRate} = 0 unless defined ( $ruleParams_ref->{guaranteedRate} );
    $ruleParams_ref->{guaranteedRate} = 0 if $ruleParams_ref->{guaranteedRate} eq '';
    $ruleParams_ref->{limitedRate} = 0 unless defined ( $ruleParams_ref->{limitedRate} );
    $ruleParams_ref->{limitedRate} = 0 if $ruleParams_ref->{limitedRate} eq '';

    # Create builders ( Disc -> Memory ) Mandatory every time an
    # access in memory is done
    $self->_createBuilders();

    $self->_updateRule( $iface, $ruleId, $ruleParams_ref );

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
#       protocol       - inet protocol
#       port           - port number
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
    throw EBox::Exceptions::MissingArgument( __('Protocol') )
      unless defined( $ruleParams{protocol} );
    throw EBox::Exceptions::MissingArgument( __('Port') )
      unless defined( $ruleParams{port} );

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
    # Check protocol
    checkProtocol( $ruleParams{protocol}, __('Protocol'));
    # Check port number
    checkPort( $ruleParams{port}, __('Port'));
    # Check rates
    $self->_checkRate( $ruleParams{guaranteedRate}, __('Guaranteed Rate') );
    $self->_checkRate( $ruleParams{limitedRate}, __('Limited Rate') );

    # The priority is set to maximal
    $ruleParams{priority} = 0;
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
#         - protocol        - inet protocol
#         - port            - port number
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

    my @rules;
    # If there's any
    if ( scalar(@dir) != 0 ) {
      # Change _dir to ruleId for readibility reasons
      foreach my $rule_ref (@dir) {
	$rule_ref->{ruleId} = delete ($rule_ref->{_dir});
	# FIXME: enabled and disable
	$rule_ref->{enabled} = 'enabled';
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
# Returns:
#
#      String - shaper chain's name
#
sub ShaperChain
  {

    my ($class) = @_;

    return 'EBOX-SHAPER-OUT';

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

    if ($external) {
      # If the interface is gonna be external, nothing related to
      # traffic shaping is done
      return undef;
    }
    else {
      # Check if any interface is being shaped
      return $self->_areRulesActive($iface);
    }

  }

# Method: freeIfaceExternal
#
#        See <EBox::NetworkObserver::freeIfaceExternal>.
#
sub changeIfaceExternalProperty # (iface, external)
  {

    my ($self, $iface, $external) = @_;

    my $dir = $self->_ruleDirectory($iface);

    if (not $external and $self->dir_exists($dir)) {
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

      # Set lowest priority to the number of rules minus one
      my $lowest = scalar(@{$dirs_ref});

      # Set lowest
      $self->setLowestPriority($iface, $lowest);
    }

  }

# Update priorities to all rules
sub _correctPriorities # (iface)
  {

    my ($self, $iface) = @_;

    my $order_ref = $self->{ruleModels}->{$iface}->order();
    my $builder = $self->{builders}->{$iface};

    if ($builder->isa('EBox::TrafficShaping::TreeBuilder::HTB') ) {
      # Starting with highest priority update priority
      my $priority = 0;
      foreach my $ruleId (@{$order_ref}) {
	#my $leafClassId = $self->_getClassIdFromRule($iface, $ruleId);
	my $leafClassId = $self->_getNumber($ruleId);
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
    my $network = $global->modInstance('network');

    my $extIfaces_ref = $network->ExternalIfaces();
    foreach my $iface (@{$extIfaces_ref}) {
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

# Check interface is external and has gateways associated
# Throw External exception if not, nothing otherwise
sub _checkInterface # (iface)
  {

    my ($self, $iface) = @_;

#    use Devel::StackTrace;
#    my $trace = Devel::StackTrace->new;
#    EBox::debug($trace->as_string());

    my $global = EBox::Global->getInstance();
    my $network = $global->modInstance('network');

    if (not $network->ifaceIsExternal( $iface )) {
      throw EBox::Exceptions::External(
				       __x('Traffic shaping can be only done in external interface and {iface} is not',
					   iface => $iface)
				      );
    }

    # Check it has gateways associated
    my $gateways_ref = $network->gateways();

    my @gatewaysIface = grep { $_->{interface} eq $iface } @{$gateways_ref};

    if ( scalar (@gatewaysIface) <= 0 ) {
      throw EBox::Exceptions::External(
				       __('Traffic shaping can be only done in external interfaces ' .
					   'which have gateways associated to')
				      );
    }

    return;

  }

# Check rule if exist
# Throw DataNotFound if not, nothing otherwise
sub _checkRuleExistence # (iface, ruleId)
  {

    my ($self, $iface, $ruleId) = @_;

    my $dir = $self->_ruleDirectory($iface, $ruleId);

    if (not $self->dir_exists("$dir") ) {
      throw EBox::Exceptions::DataNotFound(
					   data  => __('Traffic Shaping Rule'),
					   value => $iface . "/" . $ruleId,
					  );
    }

    return 1;

  }

# Check if the rule (the same parameters already exists)
# Throw DataExists if the rule with same params exists
sub _checkDuplicate # (iface, ruleParams_ref)
  {
    my ($self, $iface, $ruleParams_ref) = @_;

    my $builder = $self->{builders}->{$iface};

    if ($builder->isa('EBox::TrafficShaping::TreeBuilder::Default')) {
      return undef;
    }
    elsif ( $builder->isa('EBox::TrafficShaping::TreeBuilder::HTB')) {
#      my $classId = $builder->findLeafClassId(
#					   protocol       => $ruleParams_ref->{protocol},
#					   port           => $ruleParams_ref->{port},
#					   guaranteedRate => $ruleParams_ref->{guaranteedRate},
#					   limitedRate    => $ruleParams_ref->{limitedRate},
#					  );
      my $ruleId = $self->_getRuleId($iface, $ruleParams_ref);

      if ( defined ($ruleId) ) {
	throw EBox::Exceptions::DataExists( data => __('Rule'),
					    value => '');
      }
    }

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

    if ( $priority < 0 ) {
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

    my $dir = $self->ruleModel($iface)->directory();

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
      $linkRate = $self->_uploadRate($iface);
#     $linkRate = 1000;
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
    my $order_ref = $self->ruleModel($iface)->order();
    my %order;
    my $prio = 0;
    foreach my $ruleId (@{$order_ref}) {
      $order{$ruleId} = $prio;
      $prio++;
    }

    my $rules_ref = $self->array_from_dir($dir);

    foreach my $rule_ref (@{$rules_ref}) {
      # next if it's not an enabled rule
      # FIXME when enabled property will be on
      #      next unless ( $rule_ref->{enabled} );

      $rule_ref->{identifier} = $rule_ref->{_dir};
      # Transform from gconf to camelCase and set if they're null
      # since they're optional parameters
      $rule_ref->{guaranteedRate} = delete ($rule_ref->{guaranteed_rate});
      $rule_ref->{guaranteedRate} = 0 unless defined ($rule_ref->{guaranteedRate});
      $rule_ref->{limitedRate} = delete ($rule_ref->{limited_rate});
      $rule_ref->{limitedRate} = 0 unless defined ($rule_ref->{limitedRate});
      # Get priority from order
      $rule_ref->{priority} = $order{$rule_ref->{identifier}};

      $self->_buildANewRule( $iface, $rule_ref, undef );

    }

  }

# Create builders and they are stored in builders
sub _createBuilders
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $network = $global->modInstance('network');

    my @extIfaces = @{$network->ExternalIfaces()};

    foreach my $iface (@extIfaces) {
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
      $htbBuilder->buildRule(
			     protocol       => $rule_ref->{protocol},
			     port           => $rule_ref->{port},
			     guaranteedRate => $rule_ref->{guaranteedRate},
			     limitedRate    => $rule_ref->{limitedRate},
			     priority       => $rule_ref->{priority},
			     identifier     => $rule_ref->{identifier},
			     testing        => $test,
			    );
    }
    else {
      throw EBox::Exceptions::Internal('Tree builder which is not HTB ' .
				       'which actually builds the rules');
    }

}

# Set the class id inside the gconf interface
sub _setClassId
  {

    my ($self, $iface, $ruleId, $classId) = @_;

    my $dir = $self->_ruleDirectory($iface, $ruleId);

    # Set the class id in GConf to aftewards destroy them easily
    $self->set_int("$dir/classid/major", $classId->{major});
    $self->set_int("$dir/classid/minor", $classId->{minor});

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
      next unless $rule_ref->{protocol}        eq $inRule_ref->{protocol};
      next unless $rule_ref->{port}            == $inRule_ref->{port};
      next unless $rule_ref->{guaranteed_rate} == $inRule_ref->{guaranteedRate};
      next unless $rule_ref->{limited_rate}    == $inRule_ref->{limitedRate};
      $ruleId = $rule_ref->{_dir};
      last;
    }

    return $ruleId;

  }

# Get the class identifier from the rule identifier associated with
# Return a hash ref with minor and major as fields
sub _getClassIdFromRule # (iface, ruleId)
  {

    my ($self, $iface, $ruleId) = @_;

    my $ruleDir = $self->_ruleDirectory($iface, $ruleId);

    return $self->hash_from_dir("$ruleDir/classid");

  }

# Destroy a rule from the builder taking arguments from GConf
sub _destroyRule # (iface, ruleId, params_ref?)
  {

   my ($self, $iface, $ruleId, $params_ref) = @_;

   if ($self->{builders}->{$iface}->isa('EBox::TrafficShaping::TreeBuilder::Default')) {
     # Nothing to destroy
     return;
   }

#   my $classId_ref;
#   if ( not defined ( $params_ref ) ) {
#     $classId_ref = $self->_getClassIdFromRule($iface, $ruleId);
#   } else {
#     $classId_ref = $self->{builders}->{$iface}->findLeafClassId(
#								 protocol => $params_ref->{protocol},
#								 port     => $params_ref->{port},
#								 guaranteedRate => $params_ref->{guaranteedRate},
#								 limitedRate => $params_ref->{limitedRate},
#								);
#   }

   my $minorNumber = $self->_getNumber($ruleId);
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

#    my $leafClassId = $self->_getClassIdFromRule($iface, $ruleId);
    my $minorNumber = $self->_getNumber($ruleId);
    # Update the rule stating the same leaf class id (If test not do)
    $self->{builders}->{$iface}->updateRule(
					    identifier     => $minorNumber,
					    protocol       => $ruleParams_ref->{protocol},
					    port           => $ruleParams_ref->{port},
					    guaranteedRate => $ruleParams_ref->{guaranteedRate},
					    limitedRate    => $ruleParams_ref->{limitedRate},
					    priority       => $ruleParams_ref->{priority},
					    testing        => $test,
					   );

  }

###
# Get class identifier to delete/update and such
###
sub _getClassId # (iface, ruleParams_ref)
  {

    my ($self, $iface, $ruleParams_ref) = @_;

    my $htbBuilder = $self->{builders}->{$iface};

    my $leafClassId =
      $htbBuilder->findLeafClassId(
				   protocol       => $ruleParams_ref->{protocol},
				   port           => $ruleParams_ref->{port},
				   guaranteedRate => $ruleParams_ref->{guaranteed_rate},
				   limitedRate    => $ruleParams_ref->{limited_rate},
				   priority       => $ruleParams_ref->{priority},
				  );

    return $leafClassId;

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
sub _uploadRate # (iface)
  {

    my ($self, $iface) = @_;

    my $global = EBox::Global->getInstance();
    my $net = $global->modInstance('network');

    my $gateways_ref = $net->gateways();

    my $sumUpload = 0;
    foreach my $gateway_ref (@{$gateways_ref}) {
      if ($gateway_ref->{interface} eq $iface) {
	$sumUpload += $gateway_ref->{upload};
      }
    }

    return $sumUpload;

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
    $self->{actions}->{addRule} = __n("Added rule under interface: {iface} with protocol: " .
				      "{protocol} port: {port} guaranteed " .
				      "rate: {gRate} limited rate to: {lRate} ".
				      "priority: {priority} enabled: {enabled}");
    $self->{actions}->{removeRule} = __n("Removed rule under interface: {iface} with protocol: " .
					 "{protocol} port: {port} guaranteed " .
					 "rate: {gRate} limited rate to: {lRate} ".
					 "priority: {priority} enabled: {enabled}");
    $self->{actions}->{enableRule} = __n("Enabled rule under interface: {iface} with protocol: " .
					 "{protocol} port: {port} guaranteed " .
					 "rate: {gRate} limited rate to: {lRate} ".
					 "priority: {priority}");
    $self->{actions}->{disableRule} = __n("Disabled rule under interface: {iface} with protocol: " .
					 "{protocol} port: {port} guaranteed " .
					 "rate: {gRate} limited rate to: {lRate} ".
					 "priority: {priority}");

    $self->{actions}->{updateRule} = __n("Update rule under interface: {iface} for the following " .
					 "values:{values}");

  }

###################################
# Iptables related functions
###################################

# Delete TrafficShaping filter chain in Iptables Linux kernel struct
sub _deleteChain # (iface)
  {

    my ( $self, $iface ) = @_;

    my $shaperChain = $self->ShaperChain();
    try {
      $self->{ipTables}->pf( '-t mangle -D POSTROUTING -o ' .
			     $iface . ' -j ' . $shaperChain );
      $self->{ipTables}->pf( '-t mangle -F $shaperChain' );
      $self->{ipTables}->pf( '-t mangle -X $shaperChain' );
    } catch EBox::Exceptions::Sudo::Command with {
      my $exception = shift;
      if ($exception->exitValue() == 2 or
	  $exception->exitValue() == 1) {
	# The chain does not exist, ignore
	;
      }
      else {
	$exception->throw();
      }
      ;
    }

  }

sub _resetChain # (iface)
  {

    my ($self, $iface) = @_;

    # Delete any previous chain
    $self->_deleteChain($iface);

    my $shaperChain = $self->ShaperChain();

    # Add the chain
    try {
      $self->{ipTables}->pf( "-t mangle -N $shaperChain" );
      $self->{ipTables}->pf( "-t mangle -I POSTROUTING -o $iface" .
			     " -j $shaperChain" );
    } catch EBox::Exceptions::Sudo::Command with {
      my $exception = shift;
      if ($exception->exitValue() == 1) {
	# The chain already exists, do only the rule
	$self->{ipTables}->pf( "-t mangle -I POSTROUTING -o $iface" .
			       " -j $shaperChain" );
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
