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

package EBox::TrafficShaping::TreeBuilder::Default;

use strict;
use warnings;

# Its parent class is TreeBuilder::Abstract
use base 'EBox::TrafficShaping::TreeBuilder::Abstract';

use EBox::TrafficShaping::QDisc::Root;
use EBox::TrafficShaping::QueueDiscipline::PFIFO_FAST;
use EBox;

# Constructor: new
#
#       Constructor for TreeBuilder::Default abstract class. Default
#       classless builder with a qdisc root attached to a pfifo_fast
#       qdisc with 3 bands.
#
# Parameters:
#
#       interface - Interface to build the tree
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::TreeBuilder::Default> object
#
sub new
  {

    my $class = shift;
    my $self = {};
    my ($iface) = @_;

    bless($self, $class);

    # Set up the all things
    $self->SUPER::_init($iface);

    return $self;

  }

# Method: buildRoot
#
#         Implement <EBox::TrafficShaping::TreeBuilder::Abstract::buildRoot> method.
#
# Parameters:
#
#         defaultClass - default class where all unknown traffic is
#         sent (Ignored)
#
# Returns:
#
#         <Tree> - the tree built
#
sub buildRoot
  {

    my ($self, $defaultClass) = @_;

    my $qd = EBox::TrafficShaping::QueueDiscipline::PFIFO_FAST->new();

    # The default qdisc is a pfifo_fast with 3 priority bands with FIFO as qdisc
    my $qDiscRoot = EBox::TrafficShaping::QDisc::Root->new(
							 interface   => $self->getInterface(),
							 majorNumber => 1,
							 realQDisc   => $qd,
							);

    $self->{treeRoot} = Tree->new($qDiscRoot);

    return $self->{treeRoot};

  }

# Method: dumpTcCommands
#
#         Dump from the tree all tc commands without the path from the
#         built tree (Overrides the Abstract one)
#
# Returns:
#
#         array ref - each element contain tc arguments
#
# Exceptions:
#
#         <EBox::Exceptions::Internal> - throw if buildRoot has not been called before
#
sub dumpTcCommands
  {

    my ( $self ) = @_;

    throw Internal unless defined( $self->{treeRoot} );

    # As it is the default, only reset the system
    my @tcCommands;

    # Reset the qdisc attached to the interface
    my $iface = $self->{treeRoot}->root()->value()->getInterface();
    my $tcCommand = "qdisc del dev $iface root";

    push(@tcCommands, $tcCommand);

    return \@tcCommands;

  }

1;
