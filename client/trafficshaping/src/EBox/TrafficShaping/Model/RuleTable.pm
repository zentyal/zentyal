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

# eBox types! wow
use EBox::Types::Int;
use EBox::Types::Select;

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

# Method: selectOptions
#
#	Return select options for a given select within the table
#
# Arguments:
#
# 	select - select's name
#
# Returns:
#
#	Array ref containing hash ref with value, printable
#	value and selected status
#
sub selectOptions
  {

    my ($self, $id) = @_;

    my @options;

    if ($id eq 'protocol') {
      @options = (
		  {
		   value          => 'tcp',
		   printableValue => 'TCP',
		  },
		  {
		   value          => 'udp',
		   printableValue => 'UDP',
		  }
		 );
    }

    return \@options;

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
		     new EBox::Types::Select(
					     fieldName     => 'protocol',
					     printableName => __('Protocol'),
					     class         => 'tcenter',
					     type          => 'select',
					     size          => 5,
					     unique        => 0, # not unique
					     editable      => 1, # editable
					     optional      => 0, # not optional
					    ),
		     new EBox::Types::Int(
					  fieldName     => 'port',
					  printableName => __('Port'),
					  class         => 'tcenter',
					  type          => 'int',
					  size          => 5, # Max: 5 digits
					  unique        => 0, # not unique
					  editable      => 1, # editable
					  optional      => 0, # not optional
					 ),
		     new EBox::Types::Int(
					  fieldName     => 'guaranteed_rate',
					  printableName => __('Guaranteed Rate'),
					  class         => 'tcenter',
					  type          => 'int',
					  size          => 3,
					  unique        => 0, # not unique
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
					  unique        => 0, # not unique
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
		     'order'              => 1,
		     'help'               => __('Adding a rule to the interface should be done following ' .
						'maximum rate allowed to that interface and the sum of the ' .
						'different guaranteed rates should be at much as the total ' .
						'rate allowed. No limited rate or zero means unlimited rate ' .
					        'in terms of bandwidth link'),
		     'rowUnique'          => 1,  # Set each row is unique
		     'printableRowName'   => __('Rule'), # Set the name printed when two rows are equal
		     };

    return $dataTable;

  }

# Method: validateRow
#
#       This method validates each row which is changed, updated ...
#
# Parameters:
#
#       params - hash ref with all the fields and their values from
#       the new rule
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

    my ($self, %ruleParams) = @_;

    # if ( $type eq 'add' ) {
    if (not defined($ruleParams{id}) ) {
      # Adding a new rule
      $self->{ts}->checkRule(interface      => $self->{interface},
			     protocol       => $ruleParams{protocol},
			     port           => $ruleParams{port},
			     guaranteedRate => $ruleParams{guaranteed_rate},
			     limitedRate    => $ruleParams{limited_rate},
			    );
    }
    # elsif ( $type eq 'update' ) {
    else {
      # Updating a rule
      $self->{ts}->checkRule(interface      => $self->{interface},
			     protocol       => $ruleParams{protocol},
			     port           => $ruleParams{port},
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

    my $protocol = $row_ref->{valueHash}->{'protocol'}->value();
    my $port = $row_ref->{valueHash}->{'port'}->value();
    my $guaranteedRate = $row_ref->{valueHash}->{'guaranteed_rate'}->value();
    my $limitedRate = $row_ref->{valueHash}->{'limited_rate'}->value();
#    my $enabled        = $row_ref->{valueHash}->{enabled}->value();

    # Get priority from order
    my $priority = $row_ref->{order};

    $self->{ts}->addRule(
			 interface      => $self->{interface},
			 protocol       => $protocol,
			 port           => $port,
			 guaranteedRate => $guaranteedRate,
			 limitedRate    => $limitedRate,
			 priority       => $priority,
			 enabled        => 'true',
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
			    ruleId         => $row_ref->{id},
			   );

  }

# Method: movedDownRowNotify
#
#        See <EBox::Model::DataTable::movedDownRowNotify>
#
sub movedDownRowNotify
  {

    my ($self, $row_ref) = @_;

    $self->_updatePriority($row_ref);

  }

# Method: movedUpRowNotify
#
#        See <EBox::Model::DataTable::movedUpRowNotify>
#
sub movedUpRowNotify
  {

    my ($self, $row_ref) = @_;

    $self->_updatePriority($row_ref);

  }

# Method: updatedRowNotify
#
#        See <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
  {

    my ($self, $row_ref) = @_;

    my $protocol = $row_ref->{valueHash}->{'protocol'}->value();
    my $port = $row_ref->{valueHash}->{'port'}->value();
    my $guaranteedRate = $row_ref->{valueHash}->{'guaranteed_rate'}->value();
    my $limitedRate = $row_ref->{valueHash}->{'limited_rate'}->value();
#    my $enabled        = $row_ref->{valueHash}->{enabled}->value();

    my $priority       = $row_ref->{order};
    my $ruleId         = $row_ref->{id};

    $self->{ts}->updateRule( interface      => $self->{interface},
			     ruleId         => $ruleId,
#			     protocol       => $protocol,
#			     port           => $port,
#			     guaranteedRate => $guaranteedRate,
#			     limitedRate    => $limitedRate,
			     priority       => $priority,
			   );

  }

####################################################
# Private methods
####################################################

# Update priority
sub _updatePriority
  {

    my ($self, $row_ref) = @_;

    my $ruleId   = $row_ref->{id};
    my $priority = $row_ref->{order};

    $self->{ts}->updateRule(interface => $self->{interface},
			    ruleId    => $ruleId,
			    priority  => $priority,
			   );

  }

1;
