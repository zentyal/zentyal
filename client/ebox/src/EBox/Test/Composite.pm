# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Test::Composite
#
#
#   This class is used as a composite example
#


package EBox::Test::Composite;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the test Composite
#
# Parameters:
#
#         runtimeIndex - Int the index used to parameterised the test
#         composite
#
# Returns:
#
#       <EBox::Model::Composite> - a test composite
#
sub new
  {

      my ($class, $runtimeIndex) = @_;

      my $self = $class->SUPER::new();

      $self->{runtimeIndex} = $runtimeIndex;

      return $self;

  }

# Method: index
#
# Overrides:
#
#      <EBox::Model::Composite::index>
#
sub index
{
    my ($self) = @_;

    return $self->{runtimeIndex};

}

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
  {

      my $description =
        {
         components      => [
                             'TestSubComposite',
                             'TestTable',
                            ],
         layout          => 'tabbed',
         name            => 'TestComposite',
         compositeDomain => 'Logs',
        };

      return $description;

  }

1;
