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

# Class:
#
#   EBox::Object::Model::ObjectTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   membembers beloging to an object
#
#
use strict;
use warnings;

package EBox::Objects::Model::DynamicMemberTable;

use EBox::Objects::Members;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::MACAddr;
use EBox::Types::IPAddr;
use EBox::Types::IPRange;

use EBox::Exceptions::External;

use Net::IP;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead = (
        new EBox::Types::Text(
            fieldName       => 'name',
            printableName   => __('Name'),
            unique          => 1,
            editable        => 0,
        ),
        new EBox::Types::IPAddr(
            fieldName       => 'ipaddr',
            printableName   => 'CIDR',
            editable        => 0,
        ),
        new EBox::Types::MACAddr(
            fieldName       => 'macaddr',
            printableName   => __('MAC address'),
            unique          => 1,
            editable        => 0,
            optional        => 1,
        ),
    );

    my $helpMessage = __('For the IP addresses you can use CIDR notation ' .
        '(address/netmask) or specify the first and last addresses of a ' .
        'range that will also include all the IP addresses between them.');

    my $dataTable = {
        tableName           => 'DynamicMemberTable',
        printableTableName  => __('Dynamic members'),
        automaticRemove     => 1,
        defaultController   => '/Objects/Controller/DynamicMemberTable',
        defaultActions      => [ 'delete', 'changeView' ],
        tableDescription    => \@tableHead,
        class               => 'dataTable',
        printableRowName    => __('dynamic member'),
        sortedBy            => 'name',
        help                => $helpMessage,
    };

    return $dataTable;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle> to show the name
#   of the domain
#
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    return $parentRow->printableValueByName('printableName');
}

1;
