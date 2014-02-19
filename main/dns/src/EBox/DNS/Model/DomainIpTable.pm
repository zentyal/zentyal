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
#   EBox::DNS::Model::DomainIpTable
#
use strict;
use warnings;

package EBox::DNS::Model::DomainIpTable;

use base 'EBox::DNS::Model::Record';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::HostIP;
use EBox::Types::Text;

# Group: Public methods

# Constructor: new
#
#   Create a new model instance
#
# Returns:
#
#   <EBox::DNS::Model::DomainIpTable> - the newly created model instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    return $self;
}

# Method: updatedRowNotify
#
#   Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#   <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $zoneRow = $oldRow->parentRow();
    my $zone = $zoneRow->printableValueByName('domain');
    my $oldIp = $oldRow->printableValueByName('ip');
    my $record = "$zone A $oldIp";
    $self->_addToDelete($zone, $record);
}

# Method: deletedRowNotify
#
#   Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#   <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $zoneRow = $row->parentRow();
    my $zone = $zoneRow->printableValueByName('domain');
    my $ip = $row->printableValueByName('ip');
    my $record = "$zone A $ip";
    $self->_addToDelete($zone, $record);
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead = (
        new EBox::Types::HostIP(
            fieldName => 'ip',
            printableName => __('IP Address'),
            size => '20',
            unique => 1,
            editable => 1,
        ),
        new EBox::Types::Text(
            fieldName => 'iface',
            printableName => __('Interface'),
            optional => 1,
            editable => 0,
            hidden => 1,
        ),
    );

    my $dataTable = { tableName => 'DomainIpTable',
                      printableTableName => __('IP address'),
                      automaticRemove => 1,
                      defaultController => '/Dns/Controller/DomainIpTable',
                      defaultActions => ['add', 'del', 'editField',  'changeView' ],
                      tableDescription => \@tableHead,
                      class => 'dataTable',
                      printableRowName => __('IP address'),
                      sortedBy => 'ip',
                      help => __('The domain name will be resolved to this list of IP addresses.') };

    return $dataTable;
}

1;
