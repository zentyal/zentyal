# Copyright (C) 2010-2012 eBox Technologies S.L.
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

package EBox::Squid::Model::DelayPools;

# Class: EBox::Squid::Model::DelayPools
#
#      Rules to set the configuration for the delay pools
#
use base 'EBox::Model::DataTable';

use strict;
use warnings;

use integer;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Types::Int;

use Math::BigInt;

# Group: Public methods

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
    if ( defined( $params->{enabled} ) and $params->{enabled}->value() ) {
        # Check the same object is not used in first delay pool table
        my $srcObjId = $allFields->{acl_object}->value();
        my $squidMod = $self->parentModule();
        my $delayPools = $squidMod->model('DelayPools');
        my $row = $delayPools->findRow('acl_object' => $srcObjId);
        if ( defined($row) and $row->valueByName('enabled') ) {
            throw EBox::Exceptions::External(
                __x('Object {object} has an enabled {row} in {table}. Delete it first '
                    . 'from there to add it here',
                    object => $allFields->{acl_object}->printableValue(),
                    row    => $delayPools->printableRowName(),
                    table  => $delayPools->printableName()));
        }
    }

    # Check the rate/size are set both if unlimited
    my @allParams = ( [qw(size rate)], [qw(rate size)], [qw(clt_rate clt_size)],
                      [qw(clt_size clt_rate)]);

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

    # Check the clt_rate is always lower than rate (network)
    if ( defined( $params->{rate} ) or defined( $params->{clt_rate} )) {
        my $netRate = $allFields->{rate}->value();
        $netRate = Math::BigInt->binf() if ($netRate == -1);
        my $cltRate = $allFields->{clt_rate}->value();
        $cltRate = Math::BigInt->binf() if ($cltRate == -1);
        if ( $cltRate > $netRate ) {
            throw EBox::Exceptions::External(__x('{clt_rate} is greater than {net_rate}',
                                                 clt_rate => $allFields->{clt_rate}->printableName(),
                                                 net_rate => $allFields->{rate}->printableName()));
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

    my @tableHead = (
        new EBox::Types::Select(
            fieldName     => 'acl_object',
            printableName => __('Network object'),
            foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
            foreignField  => 'name',
            foreignNextPageField => 'members',
            editable      => 1,
            unique        => 1,
        ),
        new EBox::Types::Boolean(
            fieldName      => 'global_enabled',
            printableName  => __('Enable global limit for the object'),
            editable       => 1,
            hiddenOnViewer => 1,
            defaultValue   => 0,
        ),
        new EBox::Types::Int(
            fieldName     => 'size',
            printableName => __('Maximum unlimited size'),
            help          => __('Maximum unthrottled download size for the whole network object.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('MB'),
            defaultValue  => 0,
            min           => 0,
            filter        => \&_unlimitedFilter,
        ),
        new EBox::Types::Int(
            fieldName     => 'rate',
            printableName => __('Maximum download rate'),
            help          => __('Limited download rate after maximum size is reached for the whole network object.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('KB/s'),
            defaultValue  => 0,
            min           => 0,
            filter        => \&_unlimitedFilter,
        ),
        new EBox::Types::Boolean(
            fieldName      => 'clt_enabled',
            printableName  => __('Enable per client limit'),
            editable       => 1,
            hiddenOnViewer => 1,
            defaultValue   => 0,
        ),
        new EBox::Types::Int(
            fieldName     => 'clt_size',
            printableName => __('Maximum unlimited size per client'),
            help          => __('Maximum unthrottled download size for each client.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('MB'),
            defaultValue  => 0,
            min           => 0,
            filter        => \&_unlimitedFilter,
        ),
        new EBox::Types::Int(
            fieldName     => 'clt_rate',
            printableName => __('Maximum download rate per client'),
            help          => __('Limited download rate after maximum size is reached for each client.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('KB/s'),
            defaultValue  => 0,
            min           => 0,
            filter        => \&_unlimitedFilter,
        ),
    );

    my $dataTable = {
        'tableName'          => 'DelayPools',
        'printableTableName' => __('Bandwidth Throttling Rules'),
        'defaultActions'     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        'modelDomain'        => 'Squid',
        'tableDescription'   => \@tableHead,
        'class'              => 'dataTable',
        # Priority field set the ordering through _order function
        'order'              => 1,
        'pageTitle'          => __('HTTP Proxy'),
        'help'               => __("Bandwith throttling allows you to control download rates for connections going though the HTTP proxy. The first rule to match is applied. If a connection doesn't match any rule, then no bandwidth throttling is applied."),
        'rowUnique'          => 1,
        'printableRowName'   => __('rule'),
        'automaticRemove'    => 1,
        'enableProperty'      => 1,
        'defaultEnabledValue' => 1,
        # XXX notifyForeignModelAction to normalize values on interface bw change
    };

    return $dataTable;
}

sub delayPools
{
    my ($self) = @_;

    my $objects = EBox::Global->modInstance('objects');

    my @pools;

    foreach my $pool (@{$self->enabledRows()}) {

        my $row = $self->row($pool);
        my $rate = $row->valueByName('rate');
        my $size = $row->valueByName('size');
        my $clt_rate = $row->valueByName('clt_rate');
        my $clt_size = $row->valueByName('clt_size');
        my $obj = $row->valueByName('acl_object');
        my $addresses = $objects->objectAddresses($obj);
        push (@pools, { id => $pool,
                        class => '2',
                        rate => $rate,
                        size => $size,
                        clt_rate => $clt_rate,
                        clt_size => $clt_size,
                        object => $obj,
                        addresses => $addresses });
    }

    return \@pools;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    $customizer->setOnChangeActions(
            {
              global_enabled =>
                {
                  'on' => { show => [ 'size', 'rate' ] },
                  'off' => { hide  => [ 'size', 'rate' ] },
                },
              clt_enabled =>
                {
                  'on' => { show => [ 'clt_size', 'clt_rate' ] },
                  'off' => { hide  => [ 'clt_size', 'clt_rate' ] },
                },
            });

    return $customizer;
}

# FIXME: this doesn't work properly, because it doesn't remove trailingText
# probably we need to create a subclassed type with a custom viewer...
sub _unlimitedFilter
{
    my ($type) = @_;

    my $value = $type->value();

    # this should be -1 instead of 0
    if ($value == 0) {
        return __('Unlimited');
    } else {
        return $type->printableValue();
    }
}

1;
