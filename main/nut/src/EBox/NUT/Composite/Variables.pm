# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::NUT::Composite::Variables;

use base qw ( EBox::Model::Composite );

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
        layout          => 'top-bottom',
        name            => 'Variables',
        pageTitle       => __('UPS settings and variables'),
        compositeDomain => 'NUT',
        help            => __('These are the settings and variables provided by the UPS. The settings are read-write while the variables are read-only.'),
    };

    return $description;
}

1;
