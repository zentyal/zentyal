# Copyright (C) 2009 eBox technologies S.L.
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

# Class: EBox::UsersAndGroups::Composite::SlaveInfo

package EBox::UsersAndGroups::Composite::SlaveInfo;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the configure logs composite
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

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
                'Slaves',
                'PendingSync',
                'ForceSync',
            ],
         layout          => 'top-bottom',
         name            => 'SlaveInfo',
         compositeDomain => 'Users',
        };

      return $description;

  }

sub pageTitle
{
    return __('Slave status');
}

sub menuFolder
{
    return 'UsersAndGroups';
}

1;
