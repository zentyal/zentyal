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

package EBox::OpenVPN::Model::InterfaceTable;

use EBox::Types::Text;
use EBox::Types::Int;
use EBox::Global;
use EBox::Exceptions::Internal;

use constant IFACE_TYPE_DEFAULT => 'tap';
use constant IFACE_NUMBER_DEFAULT => -1;
use constant MAX_IFACE_NUMBER => 99;

sub new
{
    throw EBox::Exceptions::Internal('Cannot be instantiated');
}

sub interfaceFields
{
    my @fields = (
                  new EBox::Types::Text
                  (
                   'fieldName' => 'interfaceType',
                   'printableName'  => 'interfaceType',
                   'hidden'    => 1,
                   'editable'  => 0,
                   'optional'     => 1,
                  ),
                  new EBox::Types::Int
                  (
                   'fieldName' => 'interfaceNumber',
                   'printableName' => 'interfaceNumber',
                   'hidden' => 1,
                   'editable' => 0,
                   'min'      => -1,
                   'optional'     => 1,
                   # no unique bz it will not be until we call updateInterfaces
                  ),
                 );
    return @fields;
}

sub addedRowNotify
{
    my ($self, $row) = @_;

    $row->elementByName('interfaceType')->setValue(IFACE_TYPE_DEFAULT);
    $row->elementByName('interfaceNumber')->setValue(IFACE_NUMBER_DEFAULT);
    $row->store();
    # store() will call updatedRowNotify and refresh the iface cache
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to set logs or apache module as changed
        return;
    }

    # change on service, ifaceType or ifaceNumber can produce a new iface or a
    # existent iface change
    my $openvpn = EBox::Global->getInstance()->modInstance('openvpn');
    $openvpn->refreshIfaceInfoCache();
}

sub initializeInterfaces
{
    my ($self) = @_;

    foreach my $id ( @{ $self->ids() }) {
        my $row = $self->row($id);
        my $interfaceNumber = $row->elementByName('interfaceNumber');
        next if $interfaceNumber->value() != -1;

        my $interfaceType = $row->elementByName('interfaceType');
        if (not $interfaceType->value()) {
            $interfaceType->setValue(IFACE_TYPE_DEFAULT);
        }

        my $number = $self->_nextInterfaceNumber();
        $interfaceNumber->setValue($number);

        $row->store();
    }

}

sub _nextInterfaceNumber
{
    my ($self) = @_;

    # get the ordererd assigned number list
    my @numbers = @{  $self->_usedIfaceNumbers() };

    my $lastNumber = -1;
    # search for holes in the numbers
    foreach my $number (@numbers) {
        my $expectedNumber = $lastNumber + 1;
        if ($number != $expectedNumber) {
            return $expectedNumber;
        }

        $lastNumber = $number;
    }

    # no holes founds we use last number +1
    my $newNumber =  $lastNumber + 1;
    if ($newNumber > MAX_IFACE_NUMBER) {
        throw EBox::Exceptions::Internal('Maximum number of tap or tun interfaces reached');
    }
    return $newNumber;
}

sub _usedIfaceNumbers
{
    my ($self) = @_;
    my $openvpn = EBox::Global->modInstance('openvpn');

    my @interfaceTables = grep {
        $_->isa('EBox::OpenVPN::Model::InterfaceTable')
    } @{ $openvpn->models() };

    my @numbers;
    foreach my $ifaceTable (@interfaceTables) {
        my @tableNumbers =  map {
            my $row = $ifaceTable->row($_);
            my $number = $row->elementByName('interfaceNumber')->value();
            ($number >= 0) ? $number : ()
        }  @{ $ifaceTable->ids() };

        push(@numbers, @tableNumbers);
    }

    @numbers = sort {$a <=> $b} @numbers;

    return \@numbers;
}

1;
