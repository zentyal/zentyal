# Copyright (C) 2014 Zentyal S.L.
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
#   EBox::DNS::Model::ReverseNameServers
#
use strict;
use warnings;

package EBox::DNS::Model::ReverseNameServers;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::DomainName;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Text;
use EBox::Exceptions::External;
use Data::Validate::Domain;

# Group: Public methods

# Constructor: new
#
#   Create a new NameServer model instance
#
# Returns:
#
#   <EBox::DNS::Model::NameServer> - the newly created model instance
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Check the given custom name is a Fully Qualified Domain Name (FQDN)
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{ns}) {
        my $host = $changedFields->{ns};
        my $value = $host->value();
        my $options = {
            domain_allow_underscore => 1,
            domain_allow_single_label => 0,
            domain_private_tld => qr /^[a-zA-Z]+$/,
        };
        my $validator = new Data::Validate::Domain(%{$options});
        unless ($validator->is_domain($value)) {
            throw EBox::Exceptions::External(
                __x('The host name {x} does not looks like a valid FQDN.',
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
#        $self->_addToDelete($self->{toDelete});
#        delete $self->{toDelete};
#    }
#}

# Method: deletedRowNotify
#
#   Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#   <EBox::Model::DataTable::deletedRowNotify>
#
#sub deletedRowNotify
#{
#    my ($self, $row) = @_;
#
#    my $zoneRow = $row->parentRow();
#    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
#        my $zone = $zoneRow->valueByName('rzone');
#        my $ns   = $row->printableValueByName('hostName');
#        if ( $ns !~ m:\.:g ) {
#            $ns = "$ns.$zone";
#        }
#        $self->_addToDelete("$zone NS $ns");
#    }
#}

# Method: removeRow
#
# 	Overrides not to allow delete a row if only one element is left
#
# Overrides:
#
#      <EBox::Model::DataTable::removeRow>
#
#sub removeRow
#{
#    my ($self, $id, $force) = @_;
#
#    # Check there is at least a row
#    my $ids = $self->ids();
#    if ( scalar(@{$ids}) == 1 ) {
#        # Last element to remove
#        throw EBox::Exceptions::External(__('Last name server cannot be removed'));
#    }
#
#    return $self->SUPER::removeRow($id, $force);
#
#}

# Method: pageTitle
#
# Overrides:
#
#     <EBox::Model::Component::pageTitle>
#
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    return $parentRow->printableValueByName('rzone');
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Text(
            fieldName     => 'ns',
            printableName => __('Name Server'),
            editable      => 1,
            unique        => 1,
        ),
    ];

    my $dataTable = {
        tableName           => 'ReverseNameServers',
        printableTableName  => __('Name servers'),
        automaticRemove     => 1,
        modelDomain         => 'DNS',
        defaultActions      => ['add', 'del', 'move', 'editField',  'changeView' ],
        tableDescription    => $tableDesc,
        class               => 'dataTable',
        help                => __('It manages the name server (NS) records for this zone'),
        printableRowName    => __('name server record'),
        order               => 1,
        insertPosition      => 'back',
        HTTPUrlView         => 'DNS/View/ReverseNameServers',
    };

    return $dataTable;
}

# Group: Private methods

# Add the RR to the deleted list
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
        my $name = $row->valueByName('ns');
        my $record = "\tIN\tNS\t$name.";
        push (@{$records}, $record);
    }

    return $records;
}

# Method: ids
#
# 	Overrided to push the primary name server for the zone, built on-the-fly
#   based on the value of the primaryNameServer field of the parent zone
#
# Overrides:
#
#   <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self) = @_;

    my $primaryId = 'primaryNS';
    my $ids = [$primaryId, @{$self->SUPER::ids()}];
    return $ids;
}

# Method: row
#
# 	Overrided to build the primary name server row, built on-the-fly
#   thanks to the fixed id 'primaryNS'
#
# Overrides:
#
#   <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id) = @_;

    if ($id eq 'primaryNS') {
        my $row = new EBox::Model::Row(dir => $self->directory(), confmodule => $self->parentModule());
        $row->setId($id);
        $row->setModel($self);
        $row->setReadOnly(1);
        my $tableDesc = $self->table->{tableDescription};
        foreach my $type (@{$tableDesc}) {
            my $element = $type->clone();
            if ($type->fieldName() eq 'ns') {
                my $primaryNS = $self->parentRow->valueByName('primaryNameServer');
                $element->setValue($primaryNS);
            }
            $row->addElement($element);
        }
        return $row;
    }
    return $self->SUPER::row($id);
}

1;
