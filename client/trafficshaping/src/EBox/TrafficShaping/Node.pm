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

package EBox::TrafficShaping::Node;

use strict;
use warnings;

use EBox::Exceptions::NotImplemented;

#       Node is an abstract class.  An abstract node which
#       comprises rules' tree. The product in a Builder pattern

# Method: _init
#
#       Initilization done by all subclasses in constructor
#
# Parameters:
#
#       majorNumber - major number which identifies the qdisc
#       minorNumber - minor number which identifies the specific element
#
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - if any mandatory param is needed
#
sub _init # (majorNumber, minorNumber)
  {

    my ($self, $majorNumber, $minorNumber) = @_;

    throw EBox::Exceptions::MissingArgument('majorNumber')
      unless defined( $majorNumber );
    throw EBox::Exceptions::MissingArgument('minorNumber')
      unless defined( $minorNumber );

    # Setting up the common attributes
    # Identifier contains two attributes: an unique major number
    # corresponding to a qdisc and a minor number.
    $self->{identifier} = {};
    $self->{identifier}->{major} = $majorNumber;
    $self->{identifier}->{minor} = $minorNumber;

  }

# Method: getIdentifier
#
#        Get the identifier for a node in tc structure
#
# Returns:
#
#        hash ref - containing the following attributes
#                   - major - the major number
#                   - minor - the minor number
#
sub getIdentifier
  {
    my ($self) = @_;

    return $self->{identifier};

  }

# Method: dumpTcCommands
#
#         Dump all tc commands needed to create the node in the Linux
#         TC structure
#
# Returns:
#
#         array ref - each element contain tc arguments in order to be
#         executed
#
#
sub dumpTcCommands
  {

    throw EBox::Exceptions::NotImplemented();

  }

1;
