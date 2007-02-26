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

package EBox::TrafficShaping::QDisc::Root;

use strict;
use warnings;

# Its parent class is QDisc
use base 'EBox::TrafficShaping::QDisc::Base';

use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

# Constructor: new
#
#       Constructor for QDisc::Root class. A root queue discipline
#       attached to an interface.
#
# Parameters:
#
#       interface  - interface where qdisc is attached
#       majorNumber - a major number which identify the qdisc
#       filters_ref - a array ref to <EBox::TrafficShaping::Filter::Fw> attached to this queue
#                discipline (Optional)
#       realQDisc - the <EBox::TrafficShaping::QueueDiscipline::Abstract> real (Optional)
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::QDisc::Root> object
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - if any mandatory
#      argument is missing
#
sub new
  {

    my $class = shift;

    my %args = ( @_ );

    # Check integrity of interface arg
    throw EBox::Exceptions::MissingArgument('interface')
      unless defined( $args{interface} );

    my $self = $class->SUPER::new(@_);

    # Now the particular ones
    # Store the interface name (See <EBox::Network> for details)
    $self->{interface} = $args{interface};

    bless($self, $class);

    return $self;

  }

# Method: getMajorNumber
#
#       Accessor to the identifier
#
# Returns:
#
#      A number which identifies the root qdisc
#
sub getMajorNumber
  {

    my ($self) = @_;

    return $self->{identifier}->{major};

  }

# Method: setParent
#
#      Root qdisc does NOT have a parent
#
# Parameters:
#
#      parent - a <Tree> element
#
# Exceptions:
#
#      EBox::Exceptions::Internal - the QDisc::Root should be called as setParent
#
sub setParent
  {

    my ($self, $parent) = @_;

    throw EBox::Exceptions::Internal( 'A root qdisc does NOT have parent');

  }

# Method: getInterface
#
#      Get the interface where the qdisc is attached
#
# Returns:
#
#      String - The interface where is attached to
#
sub getInterface
  {

    my ($self) = @_;

    return $self->{interface};

  }

# Method: dumpTcCommands
#
#         Dump all tc commands needed to create the root qdisc in the Linux
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

    my $iface = $self->getInterface();
    my %selfId = %{$self->getIdentifier()};
    my $qDiscAttr = $self->{qdisc}->dumpTcAttr();

    my @tcCommands = ("qdisc add dev $iface root handle $selfId{major}: $qDiscAttr");

    # Now it's time for attached filters
    foreach my $filter (@{$self->{filters}}) {
      my $filterCommand = $filter->dumpTcCommand();
      # Append to tcCommands
      push(@tcCommands, $filterCommand);
    }
    return \@tcCommands;

  }

1;
