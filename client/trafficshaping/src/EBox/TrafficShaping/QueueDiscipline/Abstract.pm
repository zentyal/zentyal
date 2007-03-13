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

package EBox::TrafficShaping::QueueDiscipline::Abstract;

use strict;
use warnings;

use EBox::Exceptions::NotImplemented;

#       QueueDiscipline::Abstract is an abstract class which contains the
#       attributes from an specific qdisc implemented by Linux Kernel. 

# Method: attribute
#
#         Accessor to a queue discipline attribute
#
# Parameters:
#
#         attrName - the attribute's name
#
# Returns:
#
#         - attrValue - the attribute's value if exists
#         - undef     - if the attribute does NOT exist
#
sub attribute # (name)
  {

    my ($self, $name) = @_;

    if ( defined( $self->{$name} )) {
      return $self->{$name};
    }
    else {
      return undef;
    }

  }

# Method: setAttribute
#
#         Mutator to a queue discipline attribute
#
# Parameters:
#
#         attrName  - the attribute's name
#         attrValue - the attribute's value
#
# Exceptions:
#
#         <EBox::Exceptions::Internal> - throw if the attribute
#         does NOT exist
#
sub setAttribute # (attrName, attrValue)
  {

    my ($self, $attrName, $attrValue) = @_;

    $self->{$attrName} = $attrValue;

  }


# Method: dumpTcAttr
#
#         Dump the options needed to pass the tc command
#
# Return:
#
#         String - options for the particular queue discipline
#
sub dumpTcAttr
  {
    throw EBox::Exceptions::NotImplemented();
  }

1;
