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

sub _tableHead
{
    my ($self) = @_;
    my @tableHead =
    (
        new EBox::Types::Select(
                               fieldName     => 'object',
                               foreignModel  => $self->modelGetter('network', 'ObjectTable'),
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

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('name');
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
    my ($self, $abbreviatedMask) = @_;
    my @nets;

    my $objMod = $self->global()->modInstance('network');
    foreach my $rowID (@{$self->ids()}) {
        my $row = $self->row($rowID);
        my $objId = $row->valueByName('object');
        my $mbs   = $objMod->objectMembers($objId);
        foreach my $member (@{$mbs}) {
            # use only IP address member type
            if ($member->{type} ne 'ipaddr') {
                next;
            }

            # Add the member to the list of advertised networks
            my $mask;
            if ($abbreviatedMask) {
                $mask = $member->{mask};
            } else {
                $mask = EBox::NetWrappers::mask_from_bits($member->{mask});
            }

            push @nets, [$member->{ip}, $mask];
        }
    }

    return \@nets;
}

# Method: populateWithInternalNetworks
#
#   populates the model with objects for all the internal networks
#
#  Parameters:
#    onlyPrivateNets - if true, only add objects for networks with private
#                      addresses (default: false)
sub populateWithInternalNetworks
{
    my ($self, $onlyPrivateNets) = @_;
    my $global = $self->global();
    my $networkMod = $global->modInstance('network');
    my $objMod = $networkMod;

    my %objIdByName = map {
        ($_->{name} => $_->{id})
    } @{$objMod->objects() };
    foreach my $iface (@{$networkMod->InternalIfaces()}) {
        next unless ($networkMod->ifaceMethod($iface) eq 'static');
        for my $ifaceAddress (@{$networkMod->ifaceAddresses($iface)}) {
            my $netAddress = EBox::NetWrappers::ip_network(
                                $ifaceAddress->{address},
                                $ifaceAddress->{netmask},
                             );

            if ($onlyPrivateNets) {
                my @parts = split '\.', $netAddress, 4;
                unless ( ($parts[0] == 10) or
                         (($parts[0] == 172) and ($parts[1] >= 16) and ($parts[1] <= 32)) or
                         (($parts[0] == 192) and ($parts[1] == 168))
                       ) {
                    next;
                }
            }

            my $mask = EBox::NetWrappers::bits_from_mask($ifaceAddress->{netmask});
            my $objName = "openVPN-$iface-$netAddress-$mask";

            my $id = $objIdByName{$objName};
            # Add the object if if does not exist
            if ( not defined $id ) {
                $id = $objMod->addObject(
                    name     => $objName,
                    members  => [{
                                    name             => "$netAddress-$mask",
                                    address_selected => 'ipaddr',
                                    address          => 'ipaddr',
                                    ipaddr_ip        => $netAddress,
                                    ipaddr_mask      => $mask,
                                },],
                    readOnly => 1,
                );
                $objIdByName{$objName} = $id;
            }

            # Add the object to the list of advertised objects if it does not
            # already exists
            if (not $self->findId(object => $id)) {
                $self->add(object => $id);
            }
        }
    }
}

1;
