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
#   EBox::DNS::Model::HostnameTable
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the host names (A resource records) in a domain and a set of alias
#   described in <EBox::Network::Model::AliasTable>
#
use strict;
use warnings;

package EBox::DNS::Model::HostnameTable;

use base 'EBox::DNS::Model::Record';

use EBox::DNS::Types::Hostname;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Model::Manager;
use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::HostIP;
use EBox::Sudo;

use EBox::Model::Manager;

use Net::IP;

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
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if there is an alias with
#    the same name for other hostname within the same domain
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless (exists $changedFields->{hostname});

    my $newHostName = $changedFields->{hostname};
    my $domainModel = $newHostName->row->model();

    for my $id (@{$domainModel->ids()}) {
        my $row = $domainModel->row($id);
        # Check there is no CNAME RR in the domain with the same name
        for my $id (@{$row->subModel('alias')->ids()}) {
            my $subRow = $row->subModel('alias')->row($id);
            if ($newHostName->isEqualTo($subRow->elementByName('alias'))) {
                throw EBox::Exceptions::External(
                        __x('There is an alias with the same name "{name}" '
                            . 'for "{hostname}" in the same domain',
                            name     => $subRow->valueByName('alias'),
                            hostname => $row->valueByName('hostname')));
            }
        }
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

    my $zoneRow = $oldRow->parentRow();
    my $zone = $zoneRow->valueByName('domain');
    my $host = $oldRow->valueByName('hostname');

    # Delete the associated MX RR to the old host name
    my $mailExModel = $zoneRow->subModel('mailExchangers');
    for my $id(@{$mailExModel->ids()}) {
        my $mailRow = $mailExModel->row($id);
        my $hostname = $mailRow->elementByName('hostName');
        next unless ($hostname->selectedType() eq 'ownerDomain');
        if ($hostname->value() eq $row->id()) {
            my $preference = $mailRow->printableValueByName('preference');
            my $record = "$zone MX $preference $host.$zone";
            $self->_addToDelete($zone, $record);
        }
    }

    # Delete all aliases
    my $aliasModel = $oldRow->subModel('alias');
    foreach my $id (@{$aliasModel->ids()}) {
        my $aliasRow = $aliasModel->row($id);
        my $alias = $aliasRow->valueByName('alias');
        my $record = "$alias.$zone CNAME $host.$zone";
        $self->_addToDelete($zone, $record);
    }

    # Delete the host records
    my $record = "$host.$zone A";
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
    my $zone = $zoneRow->valueByName('domain');
    my $host = $row->valueByName('hostname');

    # Delete associated MX records
    my $mailExModel = $zoneRow->subModel('mailExchangers');
    foreach my $id (@{$mailExModel->ids()}) {
        my $mailRow = $mailExModel->row($id);
        my $hostname = $mailRow->elementByName('hostName');
        next unless ($hostname->selectedType() eq 'ownerDomain');
        if ($hostname->value() eq $row->id()) {
            my $preference = $mailRow->printableValueByName('preference');
            $mailExModel->removeRow($mailRow->id());

            my $record = "$zone MX $preference $host.$zone";
            $self->_addToDelete($zone, $record);
        }
    }

    # Delete associated TXT records
    my $txtModel = $zoneRow->subModel('txt');
    foreach my $id (@{$txtModel->ids()}) {
        my $txtRow = $txtModel->row($id);
        my $hostname = $txtRow->elementByName('hostName');
        next unless ($hostname->selectedType() eq 'ownerDomain');
        if ($hostname->value() eq $row->id()) {
            $txtModel->removeRow($txtRow->id());

            my $data = $txtRow->printableValueByName('txt_data');
            my $record = "$host.$zone TXT $data";
            $self->_addToDelete($zone, $record);
        }
    }

    # Delete all aliases
    my $aliasModel = $row->subModel('alias');
    foreach my $id (@{$aliasModel->ids()}) {
        my $aliasRow = $aliasModel->row($id);
        my $alias = $aliasRow->valueByName('alias');
        my $record = "$alias.$zone CNAME $host.$zone";
        $self->_addToDelete($zone, $record);
    }

    # Delete the host records
    my $record = "$host.$zone A";
    $self->_addToDelete($zone, $record);
}

# Method: removeRow
#
#     Override not to allow to remove the last NS record if this row
#     points to this record
#
# Overrides:
#
#     <EBox::Exceptions::DataTable::removeRow>
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    if ($force and $self->table->{automaticRemove}) {
        # Trying to remove the pointed elements first
        my $manager = EBox::Model::Manager->instance();
        $manager->removeRowsUsingId($self->contextName(), $id);
    }
    return $self->SUPER::removeRow($id, $force);
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
    my @tableHead =
        (
            new EBox::DNS::Types::Hostname
                            (
                                'fieldName' => 'hostname',
                                'printableName' => __('Host name'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1,
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'ipAddresses',
                                'printableName' => __('IP Address'),
                                'foreignModel' => 'HostIpTable',
                                'view' => '/DNS/View/HostIpTable',
                                'backView' => '/DNS/View/HostIpTable',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'foreignModel' => 'AliasTable',
                                'view' => '/DNS/View/AliasTable',
                                'backView' => '/DNS/View/AliasTable',
                                'size' => '1',
                             )
          );

    my $dataTable =
        {
            tableName => 'HostnameTable',
            printableTableName => __('Host names'),
            automaticRemove => 1,
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'move', 'editField',  'changeView' ],
            tableDescription => \@tableHead,
            class => 'dataTable',
            help => __('Automatic reverse resolution is done. If you '
                         . 'repeat an IP address in another domain, only '
                         . 'first match will be used by reverse resolution. '
                         . 'Dynamic zones may erase your manual reverse '
                         . 'resolution.'),
            printableRowName => __('host name'),
            order => 1,
            insertPosition => 'back',
            'HTTPUrlView'=> 'DNS/View/HostnameTable',
        };

    return $dataTable;
}

1;
