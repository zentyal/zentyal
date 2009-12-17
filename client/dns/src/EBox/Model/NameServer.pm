# Copyright (C) 2008 Warp Networks S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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
package EBox::DNS::Model::NameServer;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::Types::DomainName;
use EBox::Types::Select;
use EBox::Types::Union;

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

    if ( exists $changedFields->{hostName} ) {
        if ( $changedFields->{hostName}->selectedType() eq 'custom' ) {
            my $val = $changedFields->{hostName}->value();
            my @parts = split(/\./, $val);
            unless ( @parts > 2 ) {
                throw EBox::Exceptions::External(__x('The given host name '
                                                     . 'is not a fully qualified domain name (FQDN). '
                                                     . 'Do you mean ns.{name}?',
                                                     name => $val));
            }
        }
    }

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

    # FIXME: Change the directory
    my $model = EBox::Global->modInstance('dns')->model('HostnameTable');
    my $dir = $type->model()->directory();
    # Substitute mailExchangers name for hostnames to set the correct directory in hostname table
    $dir =~ s:nameServers:hostnames:g;
    $model->setDirectory($dir);
    return $model;
}


sub pageTitle
{
        my ($self) = @_;

        return $self->parentRow()->printableValueByName('domain');
}


1;
