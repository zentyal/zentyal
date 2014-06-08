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

use strict;
use warnings;

package EBox::Samba::Composite::GPOUserConfiguration;

use base qw (EBox::Model::Composite);

use EBox::Gettext;

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#   <EBox::Model::Composite::_description>
#
sub _description
{
    my $description = {
        layout          => 'tabbed',
        name            => 'GPOUserConfiguration',
        compositeDomain => 'Samba',
        headTitle       => __('User Configuration'),
        help            => __('Here you can set the policies that apply to ' .
                              'users, regardless of which computer they log ' .
                              'on to.')
    };

    return $description;
}

1;
