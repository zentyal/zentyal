# Copyright (C) 2011-2012 Zentyal S.L.
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

package EBox::IPsec::Model::ConfGeneral;
use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::IPAddr;
use EBox::Types::Password;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::NetWrappers;
# Group: Public methods

# Constructor: new
#
#       Create the new ConfGeneral model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::IPsec::Model::ConfGeneral> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);
    return $self;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
        (
         new EBox::Types::Host(
                                   fieldName => 'left_ipaddr',
                                   printableName => __('Local IP Address'),
                                   editable => 1,
                                   help => __('Zentyal public IP address.'),
                                ),
         new EBox::Types::IPAddr(
                                   fieldName => 'left_subnet',
                                   printableName => __('Local Subnet'),
                                   editable => 1,
                                   help => __('Local subnet available through the tunnel.'),
                                ),
         new EBox::Types::Union(
                              fieldName => 'right',
                              printableName => __('Remote Address'),
                              editable => 1,
                              subtypes => [
                                  new EBox::Types::Host(
                                      fieldName => 'right_ipaddr',
                                      printableName => __('IP Address'),
                                      editable => 1,
                                      help => __('Remote endpoint public IP address.'),
                                     ),
                                  new EBox::Types::Union::Text(
                                              fieldName => 'right_any',
                                              printableName => __('Any address'),
                                             ),
                                 ]
                             ),

         new EBox::Types::IPAddr(
                                   fieldName => 'right_subnet',
                                   printableName => __('Remote Subnet'),
                                   editable => 1,
                                   help => __('Remote subnet available through the tunnel.'),
                                ),
         new EBox::Types::Password(
                                   fieldName => 'secret',
                                   printableName => __('PSK Shared Secret'),
                                   editable => 1,
                                   help => __('Pre-shared key for the IPsec connection.'),
                                ),
        );

    my $dataTable =
    {
        tableName => 'ConfGeneral',
        disableAutocomplete => 1,
        printableTableName => __('General'),
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        modelDomain => 'IPsec',
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $changed_r, $all_r) = @_;
    my $networkMod = $self->global()->modInstance('network');
    my $rightIP = undef;
    if ($all_r->{right}->selectedType() eq 'right_ipaddr') {
        $rightIP = $all_r->{right}->value();
        if ($rightIP eq $all_r->{left_ipaddr}->value()) {
            throw EBox::Exceptions::External("Local and remote subnets could not be the same");
        }

    }
    if ($all_r->{left_subnet}->printableValue() eq $all_r->{right_subnet}->printableValue()) {
        throw EBox::Exceptions::External("Local and remote subnets could not be the same");
    }


    my %localNets;
    foreach my $iface ( @{ $networkMod->allIfaces() }) {
        foreach my $addr_hash (@{ $networkMod->ifaceAddresses($iface) }) {
            my $addr = $addr_hash->{address};
            my $netmask = $addr_hash->{netmask};
            if ((defined $rightIP) and ($addr eq $rightIP)) {
                my $ifname = exists $addr_hash->{name} ? $addr_hash->{name} : $iface;
                throw EBox::Exceptions::InvalidData(
                    data => $all_r->{right}->printableName(),
                    value => $rightIP,
                    advice => __x('Must be the external IP to connect and it was the addresss of local interface {if}',
                                      if => $ifname
                                 ),
                   );
            }

            my $net = EBox::NetWrappers::ip_network($addr, $netmask);
            $localNets{$net} = 1;
         }
     }


    my %localRoutes = map {
        my ($net) = split '/', $_->{network}, 2;
        ($net => 1)
    } @{ $networkMod->routes()  };

    my $externalSubnet = $all_r->{right_subnet}->ip();
    if ($localNets{$externalSubnet}) {
        throw EBox::Exceptions::InvalidData(
            data => => $all_r->{right_subnet}->printableName(),
            value => $externalSubnet,
            advice => __('This is a local network, thus already accessible through local interfaces')
           );
    } elsif ($localRoutes{$externalSubnet}) {
        throw EBox::Exceptions::InvalidData(
            data => $all_r->{right_subnet}->printableName(),
            value => $externalSubnet,
            advice => __('This network is already reachable through a static route')
           );
    }
}

1;
