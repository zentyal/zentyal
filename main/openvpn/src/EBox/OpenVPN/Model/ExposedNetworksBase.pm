# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::OpenVPN::Model::ExposedNetworksBase;
use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::Select;

# Group: Public methods

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub name
{
    __PACKAGE__->nameFromClass(),
}

sub _tableHead
{
    my ($self) = @_;
    my @tableHead =
    (
        new EBox::Types::Select(
                               fieldName     => 'object',
                               foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
                               foreignField  => 'name',
                               foreignNextPageField => 'members',

                               printableName => __('Advertised Network'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
    );
    return \@tableHead;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;
    return $self->parentRow()->printableValueByName('name');
}

# Method: networks
#
#  gets the networks contained in the table object members.
#
# Note:
#   object members of IPRange type are ignored
#
# Returns: a reference of a list of references to a lists containing the net
#          address and netmask pair
sub networks
{
    my ($self) = @_;
    my @nets;

    my $serverConfModel = $self->parentRow()->subModel('configuration');
    my $vpn = $serverConfModel->row()->elementByName('vpn')->printableValue();
    my $objMod = $self->global()->modInstance('objects');
    foreach my $rowID (@{$self->ids()}) {
        my $row = $self->row($rowID);
        my $objId = $row->valueByName('object');
        my $mbs   = $objMod->objectMembers($objId);

        foreach my $member (@{$mbs}) {
            # use only IP address member type
            if ($member->{type} ne 'ipaddr') {
                next;
            }

            my $network = EBox::NetWrappers::to_network_with_mask(
                $member->{ip},
                EBox::NetWrappers::mask_from_bits($member->{mask})
            );

            # Advertised network address == VPN network address
            if ($network eq $vpn) {
                next;
            }

            # Add the member to the list of advertised networks
            push(@nets,[$member->{ip},
                        EBox::NetWrappers::mask_from_bits($member->{mask})]
            );
        }
    }

    return \@nets;
}

1;
