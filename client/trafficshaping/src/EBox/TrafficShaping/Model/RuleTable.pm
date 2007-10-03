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

package EBox::TrafficShaping::Model::RuleTable;

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;

use EBox::Model::ModelManager;

# eBox types! wow
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Service;
use EBox::Types::MACAddr;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Uses to validate
use EBox::Validate qw( checkProtocol checkPort );

# Its parent is the EBox::Model::DataTable
use base 'EBox::Model::DataTable';

# Constructor: new
#
#       Constructor for Traffic Shaping Table Model
#
# Parameters:
#
#       gconfmodule -
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

    $self->{interface} = $params{interface};
    $self->{ts} = $params{gconfmodule};

    bless($self, $class);

    return $self;

  }

# Method: priority 
#
#	Return select options for the priority field 
#
# Returns:
#
#	Array ref containing hash ref with value, printable
#	value and selected status
#
sub priority 
{

    my  @options;

    foreach my $i (qw(0 1 2 3 4 5 6 7)) {
        push (@options, {
                value => $i,
                printableValue => $i
                }
             );
    }

    return \@options;

}

# Method: warnOnChangeOnId
#
# Overrides:
#
#       <EBox::Model::DataTable::warnOnChangeOnId>
#
sub warnOnChangeOnId
  {

      my ($self, $modelName, $id, $changedData, $oldRow) = @_;

      if ( $modelName eq 'GatewayTable' ) {
          if ( exists $changedData->{interface} ) {
              my $oldGatewayIface = $oldRow->{plainValueHash}->{interface};
              if ( $oldGatewayIface eq $self->{interface} ) {
                  return __x('Changes on rule regarding to {iface} ' .
                             'will be done', iface => $self->{interface});
              } else {
                  if ( $self->isUsingId($modelName, $id) ) {
                      if ( exists $changedData->{upload} ) {
                          return __x('Changes on rule regarding to {iface} ' .
                                     'will be done', iface => $self->{interface});
                      }
                      if ( exists $changedData->{download} ) {
                          return __x('Changes on rule regarding to {iface} ' .
                                     'will be done', iface => $self->{interface});
                      }
                  }
              }
          }
      }

      return '';

  }

# Method: isUsingId
#
# Overrides:
#
#       <EBox::Model::DataTable::isUsingId>
#
sub isUsingId
  {

      my ($self, $modelName, $id) = @_;

      if ( $modelName eq 'GatewayTable' ) {
          my $manager = EBox::Model::ModelManager->instance();
          my $observableModel = $manager->model($modelName);

          my $gateway = $observableModel->row($id);
          my $gatewayIface = $gateway->{plainValueHash}->{interface};

          return $gatewayIface eq $self->{interface};
      }

      return 0;

  }

# Method: index
#
# Overrides:
#
#     <EBox::Model::DataTable::index>
#
sub index
{

    my ($self) = @_;

    return $self->{interface};

}

# Method: _table
#
#	Describe the traffic shaping table
#
# Returns:
#
# 	hash ref - table's description
#
sub _table
  {

    my @tableHead = (
		     new EBox::Types::Service(
					      fieldName     => 'service',
					      printableName => __('Service'),
					      editable      => 1, # editable
					      optional      => 1,
					     ),
		     new EBox::Types::Union(
					    fieldName     => 'source',
					    printableName => __('Source'),
					    optional      => 1,
					    subtypes      =>
					    [
						new EBox::Types::Union::Text(
						 	'fieldName' => 'source_any',
							'printableName' => __('Any')),
					     new EBox::Types::IPAddr(
								     fieldName     => 'source_ipaddr',
								     printableName => __('Source IP'),
								     editable      => 1,
								     optional      => 1),
					     new EBox::Types::MACAddr(
								      fieldName     => 'source_macaddr',
								      printableName => __('Source MAC'),
								      editable      => 1,
								      optional      => 1),
					     new EBox::Types::Select(
								     fieldName     => 'source_object',
								     printableName => __('Source object'),
								     editable      => 1,
                                     foreignModel => \&objectModel,
                                     foreignField => 'name'
                                     )
					     ],
					    editable => 1,
					   ),
		     new EBox::Types::Union(
					    fieldName     => 'destination',
					    printableName => __('Destination'),
					    optional      => 1,
					    subtypes      =>
					    [
						new EBox::Types::Union::Text(
						 	'fieldName' => 'source_any',
							'printableName' => __('Any')),
					     new EBox::Types::IPAddr(
								     fieldName     => 'destination_ipaddr',
								     printableName => __('Destination IP'),
								     editable      => 1,
								     optional      => 1),
					     new EBox::Types::Select(
								     fieldName     => 'destination_object',
								     printableName => __('Destination object'),
								     type          => 'select',
                                     foreignModel => \&objectModel,
                                     foreignField => 'name',
				     editable      => 1)
					     ],
					    editable => 1,
					   ),
		     new EBox::Types::Select(
					     fieldName     => 'priority',
					     printableName => __('Priority'),
					     editable      => 1,
                                             populate      => \&priority,
					    ),
		     new EBox::Types::Int(
					  fieldName     => 'guaranteed_rate',
					  printableName => __('Guaranteed Rate'),
					  size          => 3,
					  editable      => 1, # editable
					  trailingText  => __('Kbit/s'),
					  optional      => 1, # optional
					 ),
		     new EBox::Types::Int(
					  fieldName     => 'limited_rate',
					  printableName => __('Limited Rate'),
					  class         => 'tcenter',
					  type          => 'int',
					  size          => 3,
					  editable      => 1, # editable
					  trailingText  => __('Kbit/s'),
					  optional      => 1, # optional
					 ),
		    );

    my $dataTable = {
		     'tableName'          => 'tsTable',
		     'printableTableName' => __('Rules list'),
		     'actions' => {
				   'add'        => '/ebox/TrafficShaping/Controller/RuleTable',
				   'del'        => '/ebox/TrafficShaping/Controller/RuleTable',
				   'move'       => '/ebox/TrafficShaping/Controller/RuleTable',
				   'editField'  => '/ebox/TrafficShaping/Controller/RuleTable',
				   'changeView' => '/ebox/TrafficShaping/Controller/RuleTable',
				  },
		     'tableDescription'   => \@tableHead,
		     'class'              => 'dataTable',
		     # Priority field set the ordering through _order function
		     'order'              => 0,
		     'help'               => __('Adding a rule to the interface should be done following ' .
						'maximum rate allowed to that interface and the sum of the ' .
						'different guaranteed rates should be at much as the total ' .
						'rate allowed. No limited rate or zero means unlimited rate ' .
					        'in terms of bandwidth link. At least, one should be provided.' .
					        'In order to identify a rule, an attribute should be given.' .
					        'Highest priority: 0 lowest priority: 7'),
		     'rowUnique'          => 1,  # Set each row is unique
		     'printableRowName'   => __('rule'),
                     'notifyActions'      => [ 'GatewayTable' ],
		    };

    return $dataTable;

  }

# Method: _tailoredOrder
#
#        Overrides <EBox::Model::DataTable::_tailoredOrder>
#
#
sub _tailoredOrder # (rows)
  {

    my ($self, $rows_ref) = @_;

    # Order rules per priority
    my @orderedRows = sort { $a->{valueHash}->{priority}->value() <=> $b->{valueHash}->{priority}->value() }
      @{$rows_ref};

    return \@orderedRows;

  }

# Method: validateRow
#
#       Override <EBox::Model::DataTable::validateRow> method
#
# Exceptions:
#
#       <EBox::Exceptions::External> - throw if interface is not
#       external or the rule cannot be built
#
#       <EBox::Exceptions::InvalidData> - throw if parameter has
#       invalid data
#
#
sub validateRow
  {

    my ($self, $action, %ruleParams) = @_;

    # It's only necessary to check the rates and object names, remainder are checked by model
    if ( defined ( $ruleParams{source_selected} ) ) {
      if ( $ruleParams{source_selected} eq 'source_ipaddr' and
	   $ruleParams{source_ipaddr_ip} ne '' ) {
	$ruleParams{source} = new EBox::Types::IPAddr(
						      ip   => delete ( $ruleParams{source_ipaddr_ip} ),
						      mask => delete ( $ruleParams{source_ipaddr_mask} ),
						     );
      } elsif ( $ruleParams{source_selected} eq 'source_macaddr' and
	   $ruleParams{source_macaddr} ne '' ) {
	$ruleParams{source} = new EBox::Types::MACAddr(
						       value   => delete ( $ruleParams{source_macaddr} ),
						      );
      } elsif ( $ruleParams{source_selected} eq 'source_object' ) {
	$ruleParams{source} = delete ( $ruleParams{source_object} );
      }
    }

    if ( defined ( $ruleParams{destination_selected} ) ){
      if ( $ruleParams{destination_selected} eq 'destination_ipaddr' and
	   $ruleParams{destination_ipaddr_ip} ne '' ) {
	$ruleParams{destination} = new EBox::Types::IPAddr(
							   ip   => delete ( $ruleParams{destination_ipaddr_ip} ),
							   mask => delete ( $ruleParams{destination_ipaddr_mask} ),
							  );
      } elsif ( $ruleParams{destination_selected} eq 'destination_object' ) {
	$ruleParams{destination} = delete ( $ruleParams{destination_object} );
      }
    }

    $ruleParams{service} = EBox::Types::Service->new(
						     protocol => delete ( $ruleParams{service_protocol} ),
						     port     => delete ( $ruleParams{service_port} ),
						    );


    if ( $action eq 'add' ) {
#    if (not defined($ruleParams{id}) ) {
      # Adding a new rule
      $self->{ts}->checkRule(interface      => $self->{interface},
			     service        => $ruleParams{service},
			     source         => $ruleParams{source},
			     destination    => $ruleParams{destination},
			     priority       => $ruleParams{priority},
			     guaranteedRate => $ruleParams{guaranteed_rate},
			     limitedRate    => $ruleParams{limited_rate},
			    );
    }
    elsif ( $action eq 'update' ) {
#    else {
      # Updating a rule
      $self->{ts}->checkRule(interface      => $self->{interface},
			     service        => $ruleParams{service},
			     source         => $ruleParams{source},
			     destination    => $ruleParams{destination},
			     priority       => $ruleParams{priority},
			     guaranteedRate => $ruleParams{guaranteed_rate},
			     limitedRate    => $ruleParams{limited_rate},
			     ruleId         => $ruleParams{id},
			    );
    }

  }

# Method: addedRowNotify
#
#	Call whenever a row is added. We should add the rule
#       to the interface in dynamic structure
#
# Arguments:
#
#       row - hash ref with all the fields rows and their values
#
#
sub addedRowNotify
  {

    my ($self, $row_ref) = @_;

#    my $protocol = $row_ref->{valueHash}->{'service'}->protocol();
#    my $port = $row_ref->{valueHash}->{'service'}->port();
#
#    # Source
#    my $source = $row_ref->{valueHash}->{'source'}->subtype()->value();
#
#    # Destination
#    my $destination = $row_ref->{valueHash}->{'destination'}->subtype()->value();

    my $guaranteedRate = $row_ref->{valueHash}->{'guaranteed_rate'}->value();
    my $limitedRate = $row_ref->{valueHash}->{'limited_rate'}->value();
#    my $enabled        = $row_ref->{valueHash}->{enabled}->value();

    # Get priority from order
    my $priority = $row_ref->{priority};

    # Now addRule doesn't need any argument since it's already done by model

    $self->{ts}->addRule(
			 interface      => $self->{interface},
#			 protocol       => $protocol,
#			 source         => $source,
#			 destination    => $destination,
#			 port           => $port,
			 guaranteedRate => $guaranteedRate,
			 limitedRate    => $limitedRate,
#			 priority       => $priority,
			 enabled        => 'enabled',
			);

  }

# Method: deletedRowNotify
#
#        See <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
  {

    my ($self, $row_ref) = @_;

    $self->{ts}->removeRule(
			    interface      => $self->{interface},
			   );

  }

# Method: updatedRowNotify
#
#        See <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
  {

    my ($self, $row_ref) = @_;

    my $ruleId         = $row_ref->{id};

    $self->{ts}->updateRule( interface      => $self->{interface},
			     ruleId         => $ruleId,
			   );

  }

####################################################
# Private methods
####################################################

# Get the objects from Objects module
# Return an array ref with a hash
# ref within each element with the attributes value and printableValue
sub objects
{
	my $self = shift;

	my $objects = EBox::Global->modInstance('objects');

	my @options;
	foreach my $object (@{$objects->objects()}) {
		push (@options, { 
				 'value' => $object->{'id'},
				 'printableValue' => $object->{'name'}
				 });
	}

	return \@options;
}

sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}
    

1;
