# Copyright (C) 2011-2013 Zentyal S.L.
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
#   <EBox::DNS::Model::Text>
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which contains the free based TXT records for a domain
#
use strict;
use warnings;

package EBox::DNS::Model::Text;

use base 'EBox::DNS::Model::Record';

use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Group: Public methods

# Constructor: new
#
#      Create a new Text model instance
#
# Returns:
#
#      <EBox::DNS::Model::Text> - the newly created model
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

    if ( exists $changedFields->{txt_data} ) {
        my $val = $changedFields->{txt_data}->value();
        # See RFC 4408 for details
        if ( length($val) >= 450 ) {
            throw EBox::Exceptions::External(
                __x('The {name} cannot be longer than {value} characters',
                    name  => $changedFields->{txt_data}->printableName(),
                    value => 450));
        }
    }

    if ($action eq 'update') {
        # Add toDelete the RRs for this TXT record
        my $oldRow  = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow();
        if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
            my $zone = $zoneRow->valueByName('domain');
            my $record   = $oldRow->printableValueByName('hostName');
            if ($record !~ m:\.:g) {
                $record = "$record.$zone";
            }
            $self->{toDelete} = "$record TXT";
        }
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
        my $hostname = $row->elementByName('hostName');
        my $record = '';
        if ($hostname->selectedType() eq 'domain') {
            $record = $zone;
        } else {
            $record = $hostname->printableValue('hostName');
            $record = "$record.$zone";
        }
        $self->_addToDelete("$record TXT");
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
              help          => __('If you select the Domain, then you are '
                                  . 'choosing the zone'),
              subtypes      =>
                [
                    new EBox::Types::Select(
                        fieldName     => 'ownerDomain',
                        printableName => __('This domain'),
                        foreignModel  => \&_hostnameModel,
                        foreignField  => 'hostname',
                        editable      => 1,
                       ),
                    new EBox::Types::Union::Text(
                        fieldName     => 'domain',
                        printableName => __('Domain'),
                       ),
                    new EBox::Types::Text(
                        fieldName     => 'custom',
                        printableName => __('Custom owner'),
                        editable      => 1,
                        ),
                   ],
             ),
          new EBox::Types::Text(
              fieldName        => 'txt_data',
              printableName    => __x('{txt} data', txt => 'TXT'),
              editable         => 1,
              help             => __('Any data could be provided'),
              allowUnsafeChars => 1,
             ),
      );

    my $dataTable =
        {
            tableName => 'Text',
            printableTableName => __x('{txt} records', txt => 'TXT'),
            automaticRemove => 1,
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'move', 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            class => 'dataTable',
            help => __('It manages the TXT records for this domain. They are useful to in SPF or DKIM antispam protocols'),
            printableRowName => __x('{txt} record', txt => 'TXT'),
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
        $dir =~ s:txt:hostnames:g;
        $model->setDirectory($dir);
        return $model;
    # }

}

1;
