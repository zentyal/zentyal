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

# Class: EBox::TrafficShaping::Model::RuleTableBase
#
#   This class describes a model which contains rule to do traffic
#   shaping on a given interface. It serves as a model template which
#   has as many instances as interfaces have the machine managed by
#   Zentyal. It is a quite complicated model and it is highly coupled to
#   <EBox::TrafficShaping> module itself.
#

package EBox::TrafficShaping::Model::RuleTableBase;

use base 'EBox::Model::DataTable';

use integer;

use TryCatch::Lite;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::MACAddr;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Uses to validate
use EBox::Validate qw( checkProtocol checkPort );

# Constants
use constant LIMIT_RATE_KEY => 'limitRate';
use constant ALL_IFACES      => '_ALL';

# Constructor: new
#
#       Constructor for Traffic Shaping Table Model
#
# Parameters:
#
#       confmodule -
#       directory   -
#       interface   - the interface where the table is attached
#
# Returns :
#
#      A recently created <EBox::TrafficShaping::Model::RuleTable> object
#
sub new
{
    my $class = shift;
    my (%params) = @_;

    my $self = $class->SUPER::new(@_);
    $self->{ts} = $params{confmodule};

    bless($self, $class);

    return $self;
}

# Method: priority
#
#       Return select options for the priority field
#
# Returns:
#
#       Array ref containing hash ref with value, printable
#       value and selected status
#
sub priority
{
    my @options;

    foreach my $i (0 .. 7) {
        push (@options, {
                value => $i,
                printableValue => $i
                }
        );
    }

    return \@options;
}

# Method: validateTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::External> - throw if interface is not
#       external or the rule cannot be built
#
#       <EBox::Exceptions::InvalidData> - throw if parameter has
#       invalid data
#
sub validateTypedRow
{
    my ($self, $action, $changedParams, $params) = @_;
    if (($action ne 'add') and (exists $changedParams->{iface})) {
        throw EBox::Exceptions::External(
            __('Changing rules interface is not supported. Remove the rule and add another for the desired interface')
           );
    }

    if ( defined ( $params->{guaranteed_rate} )) {
        $self->_checkRate( $params->{guaranteed_rate},
                __('Guaranteed rate'));
    }
    if ( defined ( $params->{limited_rate} )) {
        $self->_checkRate( $params->{limited_rate},
                __('Limited rate'));
    }
    my $reactivated = 0;
    if (exists $changedParams->{enabled}) {
        # new rules are also marked as reactivated but we can live with it
        $reactivated = $changedParams->{enabled}->value();
    }

    my %targets;
    my $filterType = $params->{filterType}->value();
    if ($filterType eq 'fw') {
        # Check objects have members
        my $objMod = $self->global()->modInstance('objects');
        foreach my $target (qw(source destination)) {
            if ( defined ( $params->{$target} )) {
                if ( $params->{$target}->subtype()->isa('EBox::Types::Select') ) {
                    my $srcObjId = $params->{$target}->value();
                    unless ( @{$objMod->objectAddresses($srcObjId)} > 0 ) {
                        throw EBox::Exceptions::External(
                        __x('Object {object} has no members. Please add at ' .
                            'least one to add rules using this object',
                            object => $params->{$target}->printableValue()));
                    }
                }
            }
        }

        my $service = $params->{service_port};
        my $servMod = $self->global()->modInstance('services');
        # Check if service is any, any source or destination is given
        if ($service->value() eq 'any'
            and $params->{source}->subtype()->isa('EBox::Types::Union::Text')
            and $params->{destination}->subtype()->isa('EBox::Types::Union::Text')) {

            throw EBox::Exceptions::External(
                __('If service is any, some source or ' .
                       'destination should be provided'));


        }

        # Transform objects (Select type) to object identifier to satisfy
        # checkRule API
        foreach my $target (qw(source destination)) {
            if ( $params->{$target}->subtype()->isa('EBox::Types::Select') ) {
                $targets{$target} = $params->{$target}->value();
            } else {
                $targets{$target} = $params->{$target}->subtype();
            }
        }
    } elsif ($filterType eq 'u32') {
        my $ownId = $params->{id};
        my $ifaceValue = $params->{iface}->value();

        foreach my $id (@{$self->ids()}) {
            next if (defined $ownId and ($id eq $ownId));

            my $row = $self->row($id);
            if ($row->valueByName('filterType') ne 'u32') {
                next;
            }

            my $rowIface = $row->valueByName('iface');

            if ($ifaceValue eq ALL_IFACES or $ifaceValue eq $rowIface) {
                throw EBox::Exceptions::External(
                    __x("There is already an existing 'priorization of small packets' rule for '{iface}'",
                    iface => $rowIface)
                );
            }
            if ($rowIface eq ALL_IFACES) {
                throw EBox::Exceptions::External(
                    __("There is already an existing 'priorization of small packets' for all interfaces")
                );
            }
        }
    }

    # Check the memory structure works as well
    my @ifacesToCheck;
    my $ifaceValue = $params->{iface}->value();
    if ($ifaceValue eq ALL_IFACES) {
        @ifacesToCheck = @{ $self->allIfacesForRuleTable()  };
    } else {
        @ifacesToCheck = ($ifaceValue);
    }
    foreach my $ifCheck (@ifacesToCheck) {
        my @ruleArgs = ();
        push (@ruleArgs, interface      => $ifCheck);
        push (@ruleArgs, filterType     => $filterType);
        push (@ruleArgs, priority       => $params->{priority}->value());
        push (@ruleArgs, guaranteedRate => $params->{guaranteed_rate}->value());
        push (@ruleArgs, limitedRate    => $params->{limited_rate}->value());
        push (@ruleArgs, ruleId         => $params->{id}); # undef on addition
        push (@ruleArgs, enabled        => $params->{enabled});
        push (@ruleArgs, reactivated    => $reactivated);

        if ($filterType eq 'fw') {
            push (@ruleArgs, service        => $params->{service_port}->value());
            push (@ruleArgs, source         => $targets{source});
            push (@ruleArgs, destination    => $targets{destination});
        }

        $self->{ts}->checkRule(@ruleArgs);
    }
}

# Method: committedLimitRate
#
#       Get the limit rate to use to build the tree at this moment
#
# Returns:
#
#       Int - the current state for limit rate for this interface at
#       traffic shaping module
#
sub committedLimitRate
{
    my ($self, $iface) = @_;

    return $self->_stateRate($iface);
}

# Group: Protected methods

# Method: _table
#
#       Describe the traffic shaping table
#
# Returns:
#
#       hash ref - table's description
#
sub _table
{
    my ($self) = @_;

    my @tableHead = (
        new EBox::Types::Select(
            fieldName => 'filterType',
            printableName => __('Filter type'),
            populate => \&_populateFilterType,
            editable => 1,
            help => __('Priorization of small control packages will affect small ACK, SYN, FIN and RST control packages'),
         ),
         new EBox::Types::Select(
                    fieldName => 'iface',
                    printableName => __('Interface'),
                    populate => $self->_populateIfacesSub(),
                    editable => 1,
                    help => __('Interface connected to this gateway')
         ),
        new EBox::Types::Select(
                    fieldName       => 'service_port',
                    printableName   => __('Service'),
                    foreignModel    => $self->modelGetter('services', 'ServiceTable'),
                    foreignField    => 'printableName',
                    foreignNextPageField => 'configuration',
                    editable        => 1,
                    cmpContext      => 'port',
                   ),
         new EBox::Types::Union(
             fieldName     => 'source',
             printableName => __('Source'),
             subtypes      =>
                [
                 new EBox::Types::Union::Text(
                     'fieldName' => 'source_any',
                     'printableName' => __('Any')),
                 new EBox::Types::IPAddr(
                     fieldName     => 'source_ipaddr',
                     printableName => __('Source IP'),
                     editable      => 1,
                     ),
# XXX: Disable MAC filter until we redesign the
#      way we add rules to iptables
#                 new EBox::Types::MACAddr(
#                     fieldName     => 'source_macaddr',
#                     printableName => __('Source MAC'),
#                     editable      => 1,
#                     ),
                 new EBox::Types::Select(
                     fieldName     => 'source_object',
                     printableName => __('Source object'),
                     editable      => 1,
                     foreignModel => $self->modelGetter('objects', 'ObjectTable'),
                     foreignField => 'name',
                     foreignNextPageField => 'members',
                     )
                 ],
             editable => 1,
             ),
         new EBox::Types::Union(
             fieldName     => 'destination',
             printableName => __('Destination'),
             subtypes      =>
                 [
                 new EBox::Types::Union::Text(
                     'fieldName' => 'destination_any',
                     'printableName' => __('Any')),
                 new EBox::Types::IPAddr(
                     fieldName     => 'destination_ipaddr',
                     printableName => __('Destination IP'),
                     editable      => 1,
                     ),
                 new EBox::Types::Select(
                     fieldName     => 'destination_object',
                     printableName => __('Destination object'),
                     type          => 'select',
                     foreignModel => $self->modelGetter('objects', 'ObjectTable'),
                     foreignField => 'name',
                     foreignNextPageField => 'members',
                     editable      => 1 ),
                 ],
              editable => 1,
              ),
         new EBox::Types::Select(
             fieldName     => 'priority',
             printableName => __('Priority'),
             editable      => 1,
             populate      => \&priority,
             defaultValue  => 7,
             help          => __('Lowest priotiry: 7 Highest priority: 0')
             ),
         new EBox::Types::Int(
             fieldName     => 'guaranteed_rate',
             printableName => __('Guaranteed Rate'),
             size          => 3,
             editable      => 1, # editable
             trailingText  => __('Kbit/s'),
             defaultValue  => 0,
             help          => __('Note that ' .
                 'The sum of all guaranteed ' .
                 'rates cannot exceed your ' .
                 'total bandwidth. 0 means unguaranteed rate.')
              ),
         new EBox::Types::Int(
                 fieldName     => 'limited_rate',
                 printableName => __('Limited Rate'),
                 class         => 'tcenter',
                 type          => 'int',
                 size          => 3,
                 editable      => 1, # editable
                 trailingText  => __('Kbit/s'),
                 defaultValue  => 0,
                 help          => __('Traffic will not exceed ' .
                     'this rate. 0 means unlimited rate.')
              ),
      );

    my $dataTable = {
        'tableName'          => $self->{tableName},
        'printableTableName' => $self->{printableTableName},
        'defaultActions'     =>
            [ 'add', 'del', 'editField', 'changeView', 'move' ],
        'modelDomain'        => 'TrafficShaping',
        'tableDescription'   => \@tableHead,
        'class'              => 'dataTable',
        # Priority field set the ordering through _order function
        'order'              => 1,
        'help'               => __('Note that if the interface is internal, ' .
                                   'the traffic flow comes from Internet to ' .
                                   'inside and the external is the other way '.
                                   'around'),
        'rowUnique'          => 1,  # Set each row is unique
        'printableRowName'   => __('rule'),
        'automaticRemove' => 1,    # Related to objects,
                                   # remove rules with an
                                   # object when that
                                   # object is being
                                   # deleted
        'enableProperty'      => 1, # The rules can be enabled or not
        'defaultEnabledValue' => 1, # The rule is enabled by default
    };

    return $dataTable;
}

####################################################
# Group: Private methods
####################################################

# Remove every rulefor iface  from the model since no limit rate are possible
sub _removeRules
{
    my ($self, $iface) = @_;

    my @idsToRemove = @{ $self->findAll(iface => $iface)};
    foreach my $id (@idsToRemove) {
        $self->removeRow( $id, 1);
    }

    my $msg = '';
    if (@idsToRemove) {
        $msg = __x('Remove {num} rules at {modelName}',
               num => scalar @idsToRemove,
               modelName => $self->printableContextName());
    }
    return $msg;
}

# Normalize the current rates (guaranteed and limited)
sub _normalize
{
    my ($self, $iface, $oldLimitRate, $currentLimitRate) = @_;

    my ($limitNum, $guaranNum, $removeNum) = (0, 0, 0);

    if ( $oldLimitRate > $currentLimitRate ) {
        # The bandwidth has been decreased
        foreach my $id (@{  $self->ids() }) {
            my $row = $self->row($id);
            my $rowIface = $row->valueByName('iface');
            if (($iface ne $rowIface) and ($iface ne ALL_IFACES)) {
                    next;
            }

            my $guaranteedRate = $row->valueByName('guaranteed_rate');
            my $limitedRate = $row->valueByName('limited_rate');
            if ( $limitedRate > $currentLimitRate ) {
                $limitedRate = $currentLimitRate;
                $limitNum++;
            }
            # Normalize guaranteed rate
            if ( $guaranteedRate != 0 ) {
                $guaranteedRate = ( $guaranteedRate * $currentLimitRate )
                                  / $oldLimitRate;
                $guaranNum++;
            }
            try {
                $row->elementByName('guaranteed_rate')->setValue($guaranteedRate);
                $row->elementByName('limited-rate')->setValue($limitedRate);
                $row->store();
            } catch {
                # The updated rule is fucking everything up (min guaranteed
                # rate reached and more!)
                my ($exc) = @_;
                EBox::warn('Row ' . $id . " is being removed. Reason: $exc");
                $self->removeRow($id, 1);
                $removeNum++;
            }
        }
    }

    if ($limitNum > 0 or $guaranNum > 0) {
        return __x( 'Normalizing rates: {limitNum} rules have decreased its ' .
            'limit rate to {limitRate}, {guaranNum} rules have normalized ' .
            'its guaranteed rate to maintain ' .
            'the same proportion that it has previously and {removeNum} ' .
            'have been deleted because its guaranteed rate was lower than ' .
            'the minimum allowed',
            limitNum => $limitNum, limitRate => $currentLimitRate,
            guaranNum => $guaranNum, removeNum => $removeNum);
    }
}

######################
# Checker methods
######################

# Check rate
# Throw InvalidData if it's not a positive number
sub _checkRate # (rate, printableName)
{
    my ($self, $rate, $printableName) = @_;

    if ( $rate->value() < 0 ) {
        throw EBox::Exceptions::InvalidData(
                'data'  => $printableName,
                'value' => $rate->value(),
                );
    }

    return 1;
}

# Get the rate stored by state in order to work when interface rate changes
# are produced
sub _stateRate
{
    my ($self, $iface) = @_;
    $iface or throw EBox::Exceptions::MissingArgument('iface');

    return $self->{confmodule}->st_get_int(_stateRateKey($iface));
}

# Set the rate into GConf state in order to work when interface rate changes
# are produced
sub _setStateRate
{
    my ($self, $iface, $rate) = @_;
    $iface or throw EBox::Exceptions::MissingArgument('iface');

    $self->{confmodule}->st_set_int(_stateRateKey($iface), $rate);
}

sub _stateRateKey
{
    my ($iface) = @_;
    return 'state_rate/' . "$iface/" . LIMIT_RATE_KEY;
}

sub _serviceHelp
{
    return __('Port based protocols use the port number to match a service, ' .
              'while Application based protocols are slower but more ' .
              'effective as they check the content of any ' .
              'packet to match a service.');
}


sub _populateFilterType
{
    my @filters = ();

    push (@filters, {
        value => 'fw',
        printableValue => __('Based on Firewall'),
    });
    push (@filters, {
        value => 'u32',
        printableValue => __('Prioritize small control packets'),
    });

    return \@filters;
}

sub _populateIfacesSub
{
    my ($self) = @_;

    return sub {
        my @ifaces =   @{$self->allIfacesForRuleTable()};
        my @options = map { 'value' => $_, 'printableValue' => $_ }, @ifaces;
        push @options,  {
            value => ALL_IFACES,
            printableValue => __('All')
           };;
        return \@options;
    };
}

sub rulesForIface
{
    my ($self, $iface)= @_;

    my @rules = ();

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        $row->valueByName('enabled') or next;
        my $rowIface = $row->valueByName('iface');
        if (($rowIface ne $iface) and ($rowIface ne ALL_IFACES) ) {
            next;
        }
        my $filterType = $row->elementByName('filterType')->value();

        my $ruleRef = {
            ruleId      => $id,
            filterType  => $filterType,
            priority    => $row->valueByName('priority'),
            guaranteed_rate => $row->valueByName('guaranteed_rate'),
            limited_rate => $row->valueByName('limited_rate'),
            enabled     => $row->valueByName('enabled'),
        };

        if ($filterType eq 'fw') {
            $ruleRef->{service} = $row->elementByName('service_port');
            $ruleRef->{source} = $row->elementByName('source')->subtype();
            $ruleRef->{destination} = $row->elementByName('destination')->subtype();
        }

        push ( @rules, $ruleRef );
    }

    return \@rules;
}

# it seems that higher numbers are lowest priority
sub lowestPriority
{
    my ($self, $iface) = @_;
    my $lowest = 0;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        $row->valueByName('enabled') or next;
        my $rowIface = $row->valueByName('iface');
        if (($rowIface ne $iface) and ($rowIface ne ALL_IFACES) ) {
            next;
        }

        my $rowPriority = $row->valueByName('priority');
        if ($rowPriority > $lowest)  {
            $lowest = $rowPriority;
        }
    }

    return $lowest;
}

# this is for NetworkObserver so dont count the ALL ifaces rules here
sub explicitIfaceHasRules
{
    my ($self, $iface)= @_;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($row->valueByName('iface') eq $iface ) {
            return 1;
        }
    }

    return 0;
}

sub configuredInterfaces
{
    my ($self) = @_;
    my %ifaces;

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if (not $row->valueByName('enabled')) {
            next;
        }

        my $iface = $row->valueByName('iface');
        if ($iface eq ALL_IFACES) {
            return $self->allIfacesForRuleTable();
        }

        $ifaces{$iface} = 1;
    }

    return [keys %ifaces];
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
sub viewCustomizer
{
    my ($self) = @_;

    my $custom = $self->SUPER::viewCustomizer();

    my $filterTypeActions = {
        fw => {
            enable => ['service_port', 'source', 'destination'],
        },
        u32 => {
            disable => ['service_port', 'source', 'destination'],
        },
    };

    $custom->setOnChangeActions({filterType => $filterTypeActions});

    return $custom;
}

1;
