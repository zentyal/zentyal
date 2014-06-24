# Copyright (C) 2011-2013 Zentyal S.L.
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

# Class: EBox::IPsec::Composite::IPsecL2TPConf
#
#

use strict;
use warnings;

package EBox::IPsec::Composite::IPsecL2TPConf;

use base 'EBox::Model::Composite';

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
        name            => 'IPsecL2TPConf',
        compositeDomain => 'IPsec',
        printableName   => 'L2TP/IPSec Settings',
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

sub checkConfigurationIsComplete
{
    my ($self) = @_;
    $self->componentByName('SettingsL2TP', 1)->checkConfigurationIsComplete();

    if ($self->componentByName('RangeTable', 1)->size() == 0) {
        if (not $self->componentByName('UsersSettings', 1)->usersEnabled()) {
            throw EBox::Exceptions::External(__('No ranges or users defined for the connection'))
        }
    }
}

1;
