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
# Class: EBox::DHCP::Composite::InterfaceConfiguration
#
#   This class is used to manage dhcp server configuration on a given
#   interface. It stores four models indexed by interface this
#   composite does
#
package EBox::DHCP::Composite::InterfaceConfiguration;
use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

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
       name            => 'InterfaceConfiguration',
       printableName   => __('DHCP Configuration'),
       compositeDomain => 'DHCP',
       help            => __('In order to serve IP addresses on an interface, '
                            . 'it is required to set at least a range or a '
                            . 'fixed address.'),
      };

    return $description;
}

sub HTMLTitle
{
    my ($self) = @_;

    return ([
             {
              title => 'DHCP',
              link  => '/DHCP/View/Interfaces',
             },
             {
              title => $self->parentRow()->valueByName('iface'),
              link => '',
             },
    ]);
}


sub hasAddresses
{
    my ($self) = @_;

    my $ranges = $self->componentByName('RangeTable');
    if ($ranges->size() > 0) {
        return 1;
    }

    my $fixedAddresses = $self->componentByName('FixedAddressTable');
    my $addr = $fixedAddresses->addresses(
        $self->interface(),
        $self->parentModule()->isReadOnly()
       );
    my $refAddr = ref $addr;
    if ($refAddr eq 'ARRAY') {
        return @{ $addr } > 0;
    } elsif ($refAddr eq 'HASH') {
        return keys %{ $addr } > 0;
    }

    return 0;
}

sub interface
{
    my ($self) = @_;
    return $self->parentRow()->valueByName('iface');
}



sub permanentMessage
{
    my ($self) = @_;
    if (not $self->parentRow()->valueByName('enabled')) {
        return __('This interface is not enabled. DHCP server will not serve addresses in this interface');
    }
    return undef;
}

1;
