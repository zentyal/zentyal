# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::IPsec::Composite::UserSettings
#
#
use strict;
use warnings;

package EBox::IPsec::Composite::UsersSettings;

use base 'EBox::Model::Composite';

use EBox::Gettext;

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
         layout          => 'top-bottom',
         name            => 'UsersSettings',
         compositeDomain => 'IPsec',
         printableName   => __('User settings'),
      };

      return $description;
}

sub usersEnabled
{
    my ($self) = @_;
    if ($self->componentByName('Users', 1)->validationGroup()) {
        return 1;
    } elsif ($self->componentByName('UsersFile', 1)->size() > 0) {
        return 1;
    }
    return 0;
}

1;
