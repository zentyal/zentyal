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

package EBox::TrafficShaping::QDisc::Base;

use strict;
use warnings;

# Its parent class is NodeTS
use base 'EBox::TrafficShaping::Node';

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidType;

# Constructor: new
#
#       Constructor for base QDisc class. A queue discipline which can
#       contain 0 or more classes. It can a root qdisc as well.
#
# Parameters:
#
#       majorNumber - a major number which identify the qdisc
#       filters_ref - an array ref to <EBox::TrafficShaping::FwFilter> attached to this queue
#                discipline (Optional)
#       realQDisc - the <EBox::TrafficShaping::QueueDiscipline> real (Optional)
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::QDisc::Base> object
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - if any mandatory argument
#      is missing
#
sub new
  {

    my $class = shift;
    my %args =  @_ ;
    my $self = {};

    # Treating arguments
    throw EBox::Exceptions::MissingArgument('major number')
      unless defined( $args{majorNumber} );

    # Setting specific attributes
    $self->{filters} = $args{filters_ref};
    $self->{qdisc} = $args{realQDisc};

    bless($self, $class);

    # Set up the all things, a qdisc always has as minor number zero
    $self->SUPER::_init( $args{majorNumber}, 0 );

    return $self;

  }

# Method: attachFilter
#
#      Attach a new filter to the queue discipline. If the queue
#      discipline is HTB the filters should be attached to the root
#      qdisc.
#
# Parameters:
#
#      filter - a <EBox::TrafficShaping::Filter::Fw> to attach to qdisc
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - throw if parameter is not to
#      the correct class
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#
sub attachFilter
  {

    my ($self, $filter) = @_;

    # Treat the argument
    throw EBox::Exceptions::MissingArgurment( "filter" )
      unless defined( $filter );
    throw EBox::Exceptions::InvalidType( 'filter', 'EBox::TrafficShaping::Filter::Fw' )
      unless $filter->isa( 'EBox::TrafficShaping::Filter::Fw' );

    # Check if filter is already there
    my @filterWithout = grep { not $_->equals( $filter ) } @{$self->{filters}};

    push ( @filterWithout, $filter );

    $self->{filters} = \@filterWithout;

    return;

  }

# Method: deAttachFilter
#
#      De-attach a filter to the queue discipline
#
# Parameters:
#
#      filterId - the unique identifier related to the filter
#
# Exceptions:
#
#
#     <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#
sub deAttachFilter
  {

    my ($self, $filterId) = @_;

    throw EBox::Exceptions::MissingArgument
      unless ( defined($filterId) );

    my @newFilters = grep { $_->getIdentifier() != $filterId }
      @{$self->{filters}};

    $self->{filters} = \@newFilters;

    return;

  }

# Method: filters
#
#      Get the filters associated to the qdisc
#
# Returns:
#
#      array ref - containing <EBox::TrafficShaping::Filter::Fw>
#                  or undef if there's no
#
sub filters
  {

    my ($self) = @_;

    return $self->{filters};

  }

# Method: orderedFilters
#
#      Get the filters associated to the qdisc ordered by the iptables
#      priority
#
# Returns:
#
#      array ref - containing zero or more <EBox::TrafficShaping::Filter::Fw>
#
sub orderedFilters
  {

    my ($self) = @_;

    if ( defined ( $self->filters() )) {
      my @orderedFilters = sort {
	                         $a->attribute('matchPrio')
				   <=>
				 $b->attribute('matchPrio')
			        }
	@{$self->filters()};

      return \@orderedFilters;
    }
    else {
      return [];
    }

  }


# Method: setParent
#
#      Set the parent class which contains the parent
#
# Parameters:
#
#      parent - a <Tree> element
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - throw if parameter is not to
#      the correct class
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#
sub setParent
  {

    my ($self, $parent) = @_;

    # Check arguments
    throw MissingArgument('parent')
      unless defined ( $parent );
    throw InvalidType('parent', 'Tree')
      unless $parent->isa('Tree');

    $self->{parent} = $parent;

  }

# Method: getQueueDiscipline
#
#      Get the queue discipline attached to the qdisc
#
# Returns:
#
#      <EBox::TrafficShaping::QueueDiscipline> - the queue discipline
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - throw if parameter is not to
#      the correct class
#
#      EBox::Exceptions::MissingArgument - throw if parameter is not
#      passed
#

sub getQueueDiscipline
  {

    my ( $self ) = @_;

    return $self->{qdisc};

  }

# Method: dumpTcCommands
#
#         Dump all tc commands needed to create the qdisc in the Linux
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
    my $qDiscAttr = $self->{qdisc}->dumpTcAttr();

    my @tcCommands = ("qdisc add dev $iface parent "
                      . sprintf("0x%X:0x%X ", $parentId{major},$parentId{minor})
                      . sprintf("handle 0x%X: ", $selfId{major})
                      . "$qDiscAttr");
    # Now it's time for attached filters
    foreach my $filter (@{$self->{filters}}) {
      my $filterCommand = $filter->dumpTcCommand();
      # Append to tcCommands
      push(@tcCommands, $filterCommand);
    }

    return \@tcCommands;

  }

# Method: dumpIptablesCommands
#
#         Dump all iptables commands needed to create the rules to
#         filter in the Linux Netfilter structure
#
# Returns:
#
#         array ref - each element contain iptables arguments in order
#         to be executed
#
sub dumpIptablesCommands
  {

    my ( $self ) = @_;

    my @iptCommands;
    # Dump from each filter attached to the qdisc
    foreach my $filter (@{$self->orderedFilters()}) {
      # Add every iptables command created by each filter
      push(@iptCommands, @{$filter->dumpIptablesCommands});
    }

    return \@iptCommands;

  }

1;
