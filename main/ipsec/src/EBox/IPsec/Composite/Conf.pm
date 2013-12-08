# Copyright (C) 2011-2012 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Conf Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Conf Public License for more details.
#
# You should have received a copy of the GNU Conf Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::IPsec::Composite::Conf
#
#

package EBox::IPsec::Composite::Conf;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;

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
        layout          => 'tabbed',
        name            => 'Conf',
        compositeDomain => 'IPsec',
    };

    return $description;
}

sub HTMLTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();

    if (not defined $parentRow) {
        return ([
                {
                    title => __('IPsec Connections'),
                    link  => '/VPN/IPsec',
                },
        ]);
    }

    my $vpn = $parentRow->elementByName('name')->printableValue();

    return ([
            {
                title => __('IPsec Connections'),
                link  => '/VPN/IPsec',
            },
            {
                title => $vpn,
                link => '',
            },
    ]);
}

1;
