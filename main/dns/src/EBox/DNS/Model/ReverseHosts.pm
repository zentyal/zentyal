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
use EBox::Types::Composite;
use EBox::Types::Text;
use EBox::DNS::Types::Hostname;

use EBox::Model::Manager;

use Net::IP;
use Data::Validate::IP;
use Data::Validate::Domain;

use base 'EBox::Model::DataTable';

# Group: Public methods

sub new
{
    my $class = shift;

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
#    <EBox::Exceptions::External>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{name}) {
        my $name = $changedFields->{name};
        my $value = $name->value();
        my $suffix = $value->{suffix};
        my $prefix = $value->{prefix};
        my $fullNameOrg = "${prefix}${suffix}";
        my $fullName = $fullNameOrg;
        unless ($fullName =~ m/\.in-addr\.arpa$/) {
            throw EBox::Exceptions::External(
                __x('The name {x} does not looks like a PTR record.',
                    x => $fullNameOrg));
        }
        # Strip .in-addr.arpa once validated
        $fullName =~ s/\.in-addr\.arpa$//;
        # Reverse ip address
        $fullName = join ('.', reverse (split (/\./, $fullName)));
        my $validator = new Data::Validate::IP;
        unless (defined $validator->is_ipv4($fullName)) {
            throw EBox::Exceptions::External(
                __x('The name {x} does not looks like a PTR record.',
                    x => $fullNameOrg));
        }
    }

    if (exists $changedFields->{hostname}) {
        my $host = $changedFields->{hostname};
        my $value = $host->value();
        my $options = {
            domain_allow_underscore => 1,
            domain_allow_single_label => 0,
            domain_private_tld => qr /^[a-zA-Z]+$/,
        };
        my $validator = new Data::Validate::Domain(%{$options});
        unless ($validator->is_domain($value)) {
            throw EBox::Exceptions::External(
                __x('The host/domain {x} does not looks like a valid FQDN.',
                    x => $value));
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
#sub updatedRowNotify
#{
#    my ($self, $row, $oldRow, $force) = @_;
#
#    # The field is added in validateTypedRow
#    if (exists $self->{toDelete}) {
#        foreach my $rr (@{$self->{toDelete}}) {
#            $self->_addToDelete($rr);
#        }
#        delete $self->{toDelete};
#    }
#}

sub _getParentZone
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    return undef unless defined $parentRow;

    my $value = '.' . $parentRow->printableValueByName('rzone');
    return $value;
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
            fieldName       => 'name',
            HTMLViewer      => '/dns/ajax/viewer/ptrname.mas',
            printableName   => __('Name'),
            editable        => 1,
            showTypeName    => 0,
            types           => [
                new EBox::Types::Text(
                    fieldName       => 'prefix',
                    printableName   => '',
                    editable        => 1,
                    size            => 11,
                ),
                new EBox::Types::Text(
                    fieldName       => 'suffix',
                    printableName   => '',
                    size            => 3,
                    volatile        => 1,
                    acquirer        => sub { $self->_getParentZone() },
                    editable        => 0,
                ),
            ],
        ),
        new EBox::DNS::Types::Hostname(
            fieldName => 'hostname',
            printableName => __('Host/Domain'),
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
#sub deletedRowNotify
#{
#    my ($self, $row) = @_;
#
#    # Deleted RRs to account
#    my $zoneRow = $row->parentRow();
#    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
#        my $ip= $row->valueByName('ip');
#        $self->_addToDelete($ip);
#    }
#}

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

#sub _addToDelete
#{
#    my ($self, $domain) = @_;
#
#    my $mod = $self->{confmodule};
#    my $key = EBox::DNS::DELETED_RR_KEY();
#    my @list = ();
#    if ( $mod->st_entry_exists($key) ) {
#        @list = @{$mod->st_get_list($key)};
#        foreach my $elem (@list) {
#            if ($elem eq $domain) {
#                # domain already added, nothing to do
#                return;
#            }
#        }
#    }
#
#    push (@list, $domain);
#    $mod->st_set_list($key, 'string', \@list);
#}

sub records
{
    my ($self) = @_;

    my $records = [];
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $name = $row->valueByName('name');
        $name = $name->{prefix};
        my $host = $row->valueByName('hostname');
        my $record = "$name\tIN\tPTR\t$host.";
        push (@{$records}, $record);
    }

    return $records;
}

1;
