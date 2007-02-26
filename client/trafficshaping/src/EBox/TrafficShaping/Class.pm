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

package EBox::TrafficShaping::Class;

use strict;
use warnings;

# Its parent class is NodeTS
use base 'EBox::TrafficShaping::Node';

# Constructor: new
#
#       Constructor for Class class. A tc class in a classful qdisc
#       discipline. It must contain classful classes or a qdisc.
#
# Parameters:
#
#       minorNumber     - minor number which identifies the class itself
#       qdiscAttached   - the qdisc which contains
#                        It should an <EBox::TrafficShaping::QDisc> object *(Optional)*
#       parent          - a <Tree> object which stores the parent object
#       queueDiscipline - the <EBox::TrafficShaping::QueueDiscipline> associated to
#                         the class
#
#       - Named parameters
# Returns:
#
#      A recently created <EBox::TrafficShaping::Class> object
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - if any argument is missing
#     <EBox::Exceptions::InvalidType>     - if any argument has a mistaken type
#
sub new
  {

    my $class = shift;
    my %args = @_;

    # Treat missing arguments
    throw EBox::Exceptions::MissingArgument( 'minorNumber')
      unless defined( $args{minorNumber} );
    throw EBox::Exceptions::MissingArgument( 'parent' )
      unless defined( $args{parent} );
    throw EBox::Exceptions::MissingArgument( 'queueDiscipline' )
      unless defined( $args{queueDiscipline} );

    # Treat invalid type arguments
    if ( defined( $args{qdiscAttached} ) ) {
      # Since qdiscAttached is not a mandatory argument
      if ( not ( $args{qdiscAttached}->isa( 'EBox::TrafficShaping::QDisc::Base' ) and
		 not $args{qdiscAttached}->isa( 'EBox::TrafficShaping::RootQDisc' ))) {
	throw EBox::Exceptions::InvalidType( 'qdisc', 'EBox::TrafficShaping::QDisc::Base' );
      }
    }

    if ( not ( $args{queueDiscipline}->isa( 'EBox::TrafficShaping::QueueDiscipline::Abstract' ))) {
      throw EBox::Exceptions::InvalidType( 'queueDiscipline', 'EBox::TrafficShaping::QueueDiscipline::Abstract' );
    }

    throw EBox::Exceptions::InvalidType( 'parent', 'Tree' )
      unless $args{parent}->isa('Tree');

    my $majorNumber = $args{parent}->root()->value()->getMajorNumber();

    my $self = {};
    # Particular Attributes
    $self->{parent} = $args{parent};
    $self->{qdisc} = $args{qdiscAttached};
    $self->{queueDiscipline} = $args{queueDiscipline};

    bless($self, $class);

    # Set up common things
    $self->SUPER::_init($majorNumber, $args{minorNumber});

    return $self;

  }

# Method: getAttachedQDisc
#
#        Accessor to the attached qdisc
#
# Returns:
#
#        <EBox::TrafficShaping::QDisc> - the qdisc attached to the class
#
sub getAttachedQDisc
  {

    my ($self) = @_;

    return $self->{qdisc};

  }

# Method: getAssociatedQueueDiscipline
#
#        Accessor to the associated queue discipline
#
# Returns:
#
#        <EBox::TrafficShaping::QueueDiscipline> - the queue
#        discipline associated to the class. It should one of the
#        following:
#         - <EBox::TrafficShaping::HTB>
#         - <EBox::TrafficShaping::HFSC>
#
sub getAssociatedQueueDiscipline
  {

    my ($self) = @_;

    return $self->{queueDiscipline};

  }


# Method: dumpTcCommands
#
#         Dump all tc commands needed to create the class in the Linux
#         TC structure
#
# Returns:
#
#         array ref - each element contain tc arguments in order to be
#         executed
#
sub dumpTcCommands
  {

    my ( $self ) = @_;

    my $iface = $self->{parent}->root()->value()->getInterface();
    my %parentId = %{$self->{parent}->value()->getIdentifier()};
    my %selfId = %{$self->getIdentifier()};
    my $qDiscAttr = $self->{queueDiscipline}->dumpTcAttr();

    # If they have qdisc attached, show them
    my $qdiscTcCmds_ref = $self->{qdisc}->dumpTcCommands()
      if (defined ( $self->{qdisc} ));

    my @tcCommands = ("class add dev $iface " .
		      "parent $parentId{major}:$parentId{minor} " .
		      "classid $selfId{major}:$selfId{minor} $qDiscAttr");

    push (@tcCommands, @{$qdiscTcCmds_ref})
      if (defined ($qdiscTcCmds_ref) );

    return \@tcCommands;

  }

# Method: equals
#
#       Check equality between an object and this
#
# Parameters:
#
#       object - the object to compare
#
# Returns:
#
#       true - if the object is the same
#       false - otherwise
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidType> - if object is not the correct type
#
sub equals # (object)
  {

    my ($self, $object) = @_;

    if ( defined( $object->{minor} ) and defined( $object->{major} )) {
      # It's a class identifier
      return ( $self->getIdentifier()->{minor} == $object->{minor}
	       and
	       $self->getIdentifier()->{major} == $object->{major});
    }
    elsif ( $object->isa('EBox::TrafficShaping::Class') ) {
      return ( $object->getIdentifier() == $self->getIdentifier() );
    }
    else {
      throw EBox::Exceptions::InvalidType('object',
					  'EBox::TrafficShaping::Class');
    }

  }

1;
