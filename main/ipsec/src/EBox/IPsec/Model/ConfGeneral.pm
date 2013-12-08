# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::IPsec::Model::ConfGeneral;

# Class: EBox::IPsec::Model::ConfGeneral
#
#   TODO: Document class
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::IPAddr;
use EBox::Types::Password;

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


sub valuesAsHash
{
    my ($self) = @_;
}


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
                                   unique => 1,
                                   editable => 1,
                                   help => __('Zentyal public IP address.'),
                                ),
         new EBox::Types::IPAddr(
                                   fieldName => 'left_subnet',
                                   printableName => __('Local Subnet'),
                                   unique => 1,
                                   editable => 1,
                                   help => __('Local subnet available through the tunnel.'),
                                ),
         new EBox::Types::Host(
                                   fieldName => 'right_ipaddr',
                                   printableName => __('Remote IP Address'),
                                   unique => 1,
                                   editable => 1,
                                   help => __('Remote endpoint public IP address.'),
                                ),
         new EBox::Types::IPAddr(
                                   fieldName => 'right_subnet',
                                   printableName => __('Remote Subnet'),
                                   unique => 1,
                                   editable => 1,
                                   help => __('Remote subnet available through the tunnel.'),
                                ),
         new EBox::Types::Password(
                                   fieldName => 'secret',
                                   printableName => __('PSK Shared Secret'),
                                   editable => 1,
                                   help => __('Remote subnet available through the tunnel.'),
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

1;
