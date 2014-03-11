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

# Class:
#
#   EBox::DNS::Model::HostIpTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains domains names and a reference
#   to a member <EBox::DNS::Model::AliasTable>
#
#
package EBox::DNS::Model::HostIpTable;

use base 'EBox::DNS::Model::Record';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::HostIP;
use EBox::Types::Text;
use EBox::Exceptions::External;

# Group: Public methods

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Check that there isn't a hostname with the same ip
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless (exists $changedFields->{ip});

    # Check there is no A RR in the same domain with the same ip
    my $ip = $changedFields->{ip};
    my $hostnameWithIPSub = sub {
        my ($ipsModel) = @_;
        foreach my $ipId (@{$ipsModel->ids()}) {
            my $row = $ipsModel->row($ipId);
            if ($row->elementByName('ip')->isEqualTo($ip)) {
                # return hostname with repeated IP
                return $ipsModel->parentRow()->valueByName('hostname');
            }
        }
        return undef;
   };

    my $hostnameWithIP = $self->executeOnBrothers($hostnameWithIPSub, subModelField => 'ipAddresses', returnFirst => 1);
    if ($hostnameWithIP) {
        throw EBox::Exceptions::External(
                  __x("The IP '{ip}' is already assigned to host '{name}' " .
                      "in the same domain",
                      name => $hostnameWithIP,
                      ip   => $ip->value())
                 );
    }
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

    my $zoneRow = $oldRow->parentRow->parentRow();
    my $zone = $zoneRow->printableValueByName('domain');
    my $oldIp = $oldRow->printableValueByName('ip');
    my $newIp = $row->printableValueByName('ip');
    return unless ($oldIp ne $newIp);

    my $host = $oldRow->parentRow->printableValueByName('hostname');
    my $record = "$host.$zone A $oldIp";
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

    my $zoneRow = $row->parentRow->parentRow();
    my $zone = $zoneRow->printableValueByName('domain');
    my $ip = $row->printableValueByName('ip');
    my $host = $row->parentRow->printableValueByName('hostname');
    my $record = "$host.$zone A $ip";
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
            printableName => __('IP'),
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

    my $dataTable = { tableName => 'HostIpTable',
                      printableTableName => __('IP'),
                      automaticRemove => 1,
                      defaultController => '/Dns/Controller/HostIpTable',
                      defaultActions => ['add', 'del', 'editField',  'changeView'],
                      tableDescription => \@tableHead,
                      class => 'dataTable',
                      help => __('The host name will be resolved to this list of IP addresses.'),
                      printableRowName => __('IP') };

    return $dataTable;
}

1;
