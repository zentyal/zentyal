# Copyright (C) 2018 Zentyal S.L.
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

# Class: EBox::AntiVirus::Composite::General

use strict;
use warnings;

package EBox::AntiVirus::Composite::General;

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
    return {
        layout          => 'top-bottom',
        name            => 'General',
        pageTitle       => __('Antivirus'),
        compositeDomain => 'AntiVirus',
    };
}

1;
