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

package EBox::Samba::Composite::GPOComputerConfiguration;

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
        name            => 'GPOComputerConfiguration',
        headTitle       => __('Computer Configuration'),
        compositeDomain => 'Samba',
        help            => __('Here you can set policies that are applied to ' .
                              'computers, regardless of who logs on to the ' .
                              'computers.')
    };

    return $description;
}

1;
