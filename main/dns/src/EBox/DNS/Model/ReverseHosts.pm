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
#   EBox::DNS::Model::ReverseHosts
#
use strict;
use warnings;

package EBox::DNS::Model::ReverseHosts;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Model::Manager;
use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::HostIP;
use EBox::Types::Composite;
use EBox::DNS::Types::Hostname;
use EBox::Sudo;

use EBox::Model::Manager;

use Net::IP;

use base 'EBox::Model::DataTable';

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
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

    return unless (exists $changedFields->{ip});

    my $newHostName = $changedFields->{hostname};
    my $domainModel = $newHostName->row()->model();

    if ($action eq 'update') {
        # Add toDelete the RRs for this hostname and its aliases
        my $oldRow  = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow();
        if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
            my @toDelete = ();
            my $oldIp = $oldRow->valueByName('ip');
            push (@toDelete, "$oldIp");
            $self->{toDelete} = \@toDelete;
        }
    }
}

# Method: updatedRowNotify
#
#   Override to add to the list of removed of RRs
#
# Overrides:
#
#   <EBox::Exceptions::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    # The field is added in validateTypedRow
    if (exists $self->{toDelete}) {
        foreach my $rr (@{$self->{toDelete}}) {
            $self->_addToDelete($rr);
        }
        delete $self->{toDelete};
    }
}

sub _getMappedNetwork
{
    my ($self, $group) = @_;

    my $parentRow = $self->parentRow();
    return undef unless defined $parentRow;

    my @value = $parentRow->valueByName('rzone');
    return $value[$group] . ".";
}

# Method: _table
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableHead = [
        new EBox::Types::Composite(
            fieldName       => 'ip',
            printableName   => __('IP Address'),
            editable        => 1,
            showTypeName    => 0,
            types           => [
                new EBox::Types::Text(
                    fieldName       => 'ipgroup1',
                    printableName   => '',
                    HTMLViewer      => '',
                    volatile        => 1,
                    size            => 3,
                    acquirer        => sub { $self->_getMappedNetwork(0) },
                ),
                new EBox::Types::Text(
                    fieldName       => 'ipgroup2',
                    printableName   => '',
                    volatile        => 1,
                    HTMLViewer      => '',
                    size            => 3,
                    acquirer        => sub { $self->_getMappedNetwork(1) },
                ),
                new EBox::Types::Text(
                    fieldName       => 'ipgroup3',
                    printableName   => '',
                    HTMLViewer      => '',
                    volatile        => 1,
                    size            => 3,
                    acquirer        => sub { $self->_getMappedNetwork(2) },
                ),
                new EBox::Types::Text(
                    fieldName       => 'group4',
                    printableName   => '',
                    hiddenOnViewer => 0,
                    editable        => 1,
                    size            => 3,
                    unique          => 1,
                ),
            ],
        ),
        new EBox::DNS::Types::Hostname(
            fieldName => 'hostname',
            printableName => __('Host name'),
            size => '20',
            unique => 0,
            editable => 1,
        ),
    ];

    my $helpMessage = __('Automatic reverse resolution is done. If you '
                        . 'repeat an IP address in another domain, only '
                        . 'first match will be used by reverse resolution. '
                        . 'Dynamic zones may erase your manual reverse '
                        . 'resolution.');

    my $dataTable = {
        tableName           => 'ReverseHosts',
        printableTableName  => __('IP to name mapping'),
        automaticRemove     => 1,
        modelDomain         => 'DNS',
        defaultActions      => ['add', 'del', 'move', 'editField',  'changeView' ],
        tableDescription    => $tableHead,
        class               => 'dataTable',
        help                => $helpMessage,
        printableRowName    => __('host map'),
        order               => 1,
        insertPosition      => 'back',
        HTTPUrlView         => 'DNS/View/ReverseHosts',
    };

    return $dataTable;
}

# Method: deletedRowNotify
#
# 	Overrides to remove mail exchangers referencing the deleted
# 	host name and add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    # Deleted RRs to account
    my $zoneRow = $row->parentRow();
    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
        my $ip= $row->valueByName('ip');
        $self->_addToDelete($ip);
    }
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
#
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    return $parentRow->printableValueByName('rzone');
}

sub _addToDelete
{
    my ($self, $domain) = @_;

    my $mod = $self->{confmodule};
    my $key = EBox::DNS::DELETED_RR_KEY();
    my @list = ();
    if ( $mod->st_entry_exists($key) ) {
        @list = @{$mod->st_get_list($key)};
        foreach my $elem (@list) {
            if ($elem eq $domain) {
                # domain already added, nothing to do
                return;
            }
        }
    }

    push (@list, $domain);
    $mod->st_set_list($key, 'string', \@list);
}

1;
