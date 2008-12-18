# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::OpenVPN::Model::InterfaceTable;


use strict;
use warnings;

use EBox::Types::Text;
use EBox::Types::Int;

use constant IFACE_TYPE_DEFAULT => 'tap';
use constant IFACE_NUMBER_DEFAULT => -1;

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
}

sub initializeInterfaces
{
    my ($self) = @_;

    foreach my $row ( @{ $self->rows() }) {
        my $interfaceNumber = $row->elementByName('interfaceNumber');
        next if $interfaceNumber->value() != -1;

        my $interfaceType = $row->elementByName('interfaceType');
        $interfaceType->setValue('tap');


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
    return $lastNumber + 1;
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
                                   my $number = $_->elementByName('interfaceNumber')->value();
                                   ($number >= 0) ? $number : ()
                               }  @{ $ifaceTable->rows() };

        push @numbers, @tableNumbers;
    }

    @numbers = sort @numbers;

    return \@numbers;
}




1;
