# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::DHCP::Composite::AdvancedOptions
#
#   This class is used to manage advanced options from a dhcp
#   server. It stores two models, the former is the LeaseTime model
#   which stores the lease times configuration, and the latter the
#   thin client model that stores the thin client configuration
#
use strict;
use warnings;

package EBox::DHCP::Composite::AdvancedOptions;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Method: pageTitle
#
#   Overrides:
#
#       <EBox::Model::Composite::headTitle>
#
# Returns:
#
#   undef
#
sub pageTitle
{
    return undef;
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
    my ($self) = @_;

    my $description = {
        layout          => 'top-bottom',
        name            => 'AdvancedOptions',
        compositeDomain => 'DHCP',
        printableName   => __('Advanced options'),
    };

    return $description;
}

1;
