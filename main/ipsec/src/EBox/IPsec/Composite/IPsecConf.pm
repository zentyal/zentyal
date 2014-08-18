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

# Class: EBox::IPsec::Composite::IPsecConf
#
#

use strict;
use warnings;

package EBox::IPsec::Composite::IPsecConf;

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
        name            => 'IPsecConf',
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

sub checkConfigurationIsComplete
{
    my ($self) = @_;
    $self->componentByName('SettingsIPsec', 1)->checkConfigurationIsComplete();
}

1;
