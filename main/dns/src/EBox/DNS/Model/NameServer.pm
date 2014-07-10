# Copyright (C) 2009-2013 Zentyal S.L.
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
#   <EBox::DNS::Model::NameServer>
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which contains the nameservers for a domain, that
#   is, its NS records . A member of <EBox::DNS::Model::DomainTable>
#
use strict;
use warnings;

package EBox::DNS::Model::NameServer;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::DomainName;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Exceptions::External;

# Group: Public methods

# Constructor: new
#
#      Create a new NameServer model instance
#
# Returns:
#
#      <EBox::DNS::Model::NameServer> - the newly created model
#      instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

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

    return unless exists $changedFields->{hostName};

    if ( $changedFields->{hostName}->selectedType() eq 'custom' ) {
        my $val = $changedFields->{hostName}->value();
        my @parts = split(/\./, $val);
        unless ( @parts > 2 ) {
            throw EBox::Exceptions::External(__x('The given host name '
                                                 . 'is not a fully qualified domain name (FQDN). '
                                                 . 'Do you mean ns.{name}?',
                                                 name => $val));
        }
        # Check the given custom nameserver is a CNAME record from the
        # same zone
        my $zoneRow = $self->parentRow();
        my $zone    = $zoneRow->valueByName('domain');
        my $customZone = join('.', @parts[1 .. $#parts]);
        if ( $zone eq $customZone ) {
            # Use ownerDomain to set the nameserver
            throw EBox::Exceptions::External(__('A custom host name cannot be set '
                                                . 'from the same domain. Use '
                                                . '"This domain" option instead'));
        }
    }

    if ($action eq 'update') {
        # Add toDelete the RRs for this nameserver
        my $oldRow = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow();
        if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
            my $zone = $zoneRow->valueByName('domain');
            my $ns   = $oldRow->printableValueByName('hostName');
            if ( $ns !~ m:\.:g ) {
                $ns = "$ns.$zone";
            }
            $self->{toDelete} = "$zone NS $ns";
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
        $self->_addToDelete($self->{toDelete});
        delete $self->{toDelete};
    }
}

# Method: deletedRowNotify
#
# 	Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $zoneRow = $row->parentRow();
    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
        my $zone = $zoneRow->valueByName('domain');
        my $ns   = $row->printableValueByName('hostName');
        if ( $ns !~ m:\.:g ) {
            $ns = "$ns.$zone";
        }
        $self->_addToDelete("$zone NS $ns");
    }
}

# Method: removeRow
#
# 	Overrides not to allow delete a row if only one element is left
#
# Overrides:
#
#      <EBox::Model::DataTable::removeRow>
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    # Check there is at least a row
    my $ids = $self->ids();
    if ( scalar(@{$ids}) == 1 ) {
        # Last element to remove
        throw EBox::Exceptions::External(__('Last name server cannot be removed'));
    }

    return $self->SUPER::removeRow($id, $force);

}

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

    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('domain');
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

    my @tableDesc =
      (
          new EBox::Types::Union(
                                 fieldName     => 'hostName',
                                 printableName => __('Host name'),
                                 editable      => 1,
                                 unique        => 1,
                                 help          => __('If you choose "Custom", '
                                                     . 'it should be a Fully Qualified Domain Name'),
                                 subtypes      =>
                                 [
                                  new EBox::Types::Select(
                                          fieldName     => 'ownerDomain',
                                          printableName => __('This domain'),
                                          foreignModel  => \&_hostnameModel,
                                          foreignField  => 'hostname',
                                          editable      => 1,
                                          unique        => 1,
                                                         ),
                                  new EBox::Types::DomainName(
                                          fieldName     => 'custom',
                                          printableName => __('Custom'),
                                          editable      => 1,
                                          unique        => 1,
                                         ),
                                 ],
                                ),
      );

    my $dataTable =
        {
            tableName => 'NameServer',
            printableTableName => __('Name servers'),
            automaticRemove => 1,
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'move', 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            class => 'dataTable',
            help => __('It manages the name server (NS) records for this domain'),
            printableRowName => __('name server record'),
            order => 1,
            insertPosition => 'back',
        };

    return $dataTable;
}

# Group: Private methods

# Get the hostname model from DNS module
sub _hostnameModel
{
    my ($type) = @_;

    # FIXME: We cannot use API until the bug in parent deep recursion is fixed
    # my $parentRow = $type->model()->parentRow();
    # if ( defined($parentRow) ) {
    #     return $parentRow->subModel('hostnames');
    # } else {
        # Bug in initialisation code of ModelManager
        my $model = EBox::Global->modInstance('dns')->model('HostnameTable');
        my $dir = $type->model()->directory();
        $dir =~ s:nameServers:hostnames:g;
        $model->setDirectory($dir);
        return $model;
    # }

}

# Add the RR to the deleted list
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
