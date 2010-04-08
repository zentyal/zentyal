# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Squid::Model::DelayPools1;

# Class: EBox::Squid::Model::DelayPools1
#
#      Form to set the configuration for the delay pools class 1.
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use integer;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Model::ModelManager;

# Group: Public methods

# Constructor: new
#
#      Create the new DelayPools1 model.
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
# Returns:
#
#      <EBox::Squid::Model::DelayPools1> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless( $self, $class );

    return $self;
}


# Method: validateTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - throw if parameter has
#       invalid data.
#
sub validateTypedRow
{
    my ($self, $action, $params, $allFields) = @_;

    if ( defined ( $params->{acl_object} ) ) {
        # check objects have members
        my $srcObjId = $params->{acl_object}->value();
        my $objects = EBox::Global->modInstance('objects');
        unless ( @{$objects->objectAddresses($srcObjId)} > 0 ) {
            throw EBox::Exceptions::External(
                    __x('Object {object} has no members. Please add at ' .
                        'least one to add rules using this object.',
                        object => $params->{acl_object}->printableValue()));
        }
    }

    # Check if the row to edit/add is enabled prior to check this
    if ( defined ( $params->{enabled} ) and $params->{enabled}->value() ) {
        # Check the same object is not used in second delay pool table
        my $srcObjId = $allFields->{acl_object}->value();
        my $squidMod = $self->parentModule();
        my $delayPools2 = $squidMod->model('DelayPools2');
        my $row = $delayPools2->findRow('acl_object' => $srcObjId);
        if ( defined($row) and $row->valueByName('enabled') ) {
            throw EBox::Exceptions::External(
                __x('Object {object} has an enabled {row} in {table}. Delete it first '
                    . 'from there to add it here',
                    object => $allFields->{acl_object}->printableValue(),
                    table  => $delayPools2->printableName(),
                    row    => $delayPools2->printableRowName()));
        }
    }

    # Check the rate/size are set both if unlimited
    my @allParams = ( [qw(size rate)], [qw(rate size)] );

    foreach my $paramNames (@allParams) {
        if ( defined( $params->{$paramNames->[0]} ) ) {
            # Check the size is unlimited and the rate is unlimited
            if ( $params->{$paramNames->[0]}->value() == -1
                 and $allFields->{$paramNames->[1]}->value() != -1) {
                throw EBox::Exceptions::External(__x('If {first} is set unlimited, '
                                                     . 'then {second} must be set to unlimited as well',
                                                     first => $params->{$paramNames->[0]}->printableName(),
                                                     second => $allFields->{$paramNames->[1]}->printableName()));
            }
        }
    }

}


# Group: Protected methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHead =
        (
         new EBox::Types::Select(
                 fieldName     => 'acl_object',
                 printableName => __('Network object'),
                 foreignModel  => \&_objectModel,
                 foreignField  => 'name',
                 editable      => 1,
                 unique        => 1,
             ),
         new EBox::Types::Int(
                 fieldName     => 'rate',
                 printableName => __('Network Rate'),
                 size          => 3,
                 editable      => 1,
                 trailingText  => __('Bytes/s'),
                 defaultValue  => 0,
                 min           => -1,
                 help => __('Maximum download bandwidth rate for this network. Use -1 to disable this option.')
             ),
         new EBox::Types::Int(
                 fieldName     => 'size',
                 printableName => __('Network Maximum Size'),
                 size          => 3,
                 editable      => 1,
                 trailingText  => __('Bytes'),
                 defaultValue  => 0,
                 min           => -1,
                 help => __('Maximum unthrottled download size for this network. Use -1 to disable this option.')
             ),
      );

    my $dataTable = {
        'tableName'          => 'DelayPools1',
        'printableTableName' => __x('Delay Pools Class 1'),
        'defaultActions'     => [ 'add', 'del', 'editField', 'changeView' ],
        'modelDomain'        => 'Squid',
        'tableDescription'   => \@tableHead,
        'class'              => 'dataTable',
        # Priority field set the ordering through _order function
        'order'              => 1,
        'help'               => __x('Once the request exceeds the {max} then the '.
                                   'HTTP Proxy will throttle the download bandwidth to '.
                                   'the given {rate}.',
                                    max  => $tableHead[2]->printableName(),
                                    rate => $tableHead[1]->printableName()),
        'rowUnique'          => 1,
        'printableRowName'   => __('pool'),
        'automaticRemove'    => 1,
        'enableProperty'      => 1,
        'defaultEnabledValue' => 1,
        # XXX notifyForeignModelAction to normalize values on interface bw change
    };

    return $dataTable;
}


# Get the object model from Objects module
sub _objectModel
{
    return EBox::Global->modInstance('objects')->{objectModel};
}


sub delayPools1
{
    my ($self) = @_;

    my $objects = EBox::Global->modInstance('objects');

    my @pools;

    foreach my $pool (@{$self->enabledRows()}) {

        my $row = $self->row($pool);
        my $rate = $row->valueByName('rate');
        my $size = $row->valueByName('size');
        my $obj = $row->valueByName('acl_object');
        my $addresses = $objects->objectAddresses($obj);
        push (@pools, { id => $pool,
                        class => '1',
                        rate => $rate,
                        size => $size,
                        object => $obj,
                        addresses => $addresses });

    }

    return \@pools;
}

1;
