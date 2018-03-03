# Copyright (C) 2010-2013 Zentyal S.L.
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

# Class: EBox::Squid::Model::DelayPools
#
#      Rules to set the configuration for the delay pools
#
package EBox::Squid::Model::DelayPools;

use base 'EBox::Model::DataTable';

use integer;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Squid::Types::UnlimitedInt;
use EBox::Exceptions::External;

use Math::BigInt;

# Method: validateRow
#
# Overrides:
#
#       <EBox::Model::DataTable::validateRow>
#
sub validateRow
{
    my ($self, $action, %params) = @_;

    if ($params{acl_object} and ($params{acl_object} ne '_addNew')) {
        # check objects have members
        my $srcObjId = $params{acl_object};
        my $objects = EBox::Global->modInstance('network');
        unless (@{$objects->objectAddresses($srcObjId)} > 0) {
            throw EBox::Exceptions::External(
                    __x('Object {object} has no members. Please add at ' .
                        'least one to use this object.',
                        object => $params{acl_object}));
        }
    }

    if ($params{global_enabled}) {
        unless ($params{size} and $params{rate}) {
            throw EBox::Exceptions::External(__('If global limit is enabled you need to specifiy its size and rate values'));
        }
    }

    if ($params{clt_enabled}) {
        unless ($params{clt_size} and $params{clt_rate}) {
            throw EBox::Exceptions::External(__('If per-client limit is enabled you need to specifiy its size and rate values'));
        }
    }

    # Check the clt_rate is always lower than rate (network)
    if ($params{global_enabled} and $params{clt_enabled}) {
        my $netRate = defined ($params{rate}) ? $params{rate} : Math::BigInt->binf();
        my $cltRate = defined ($params{clt_rate}) ? $params{clt_rate} : Math::BigInt->binf();
        if ($cltRate > $netRate) {
            throw EBox::Exceptions::External(__x('Per-client rate ({clt_rate} KB/s) cannot be greater than global rate ({net_rate} KB/s)',
                                                 clt_rate => $cltRate,
                                                 net_rate => $netRate));
        }
    }
}

sub addedRowNotify
{
    my ($self, $row) = @_;
    $self->_setUndefinedValues($row);
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow) = @_;
    if ($row->isEqualTo($oldRow)) {
        return;
    }

    $self->_setUndefinedValues($row);
}

sub _setUndefinedValues
{
    my ($self, $row) = @_;

    my $toStore;
    unless ($row->valueByName('global_enabled')) {
        if ($row->valueByName('size') or $row->valueByName('rate')) {
            $row->elementByName('size')->setValue(undef);
            $row->elementByName('rate')->setValue(undef);
            $toStore = 1;
        }
    }

    unless ($row->valueByName('clt_enabled')) {
        if ($row->valueByName('clt_size') or $row->valueByName('clt_rate')) {
            $row->elementByName('clt_size')->setValue(undef);
            $row->elementByName('clt_rate')->setValue(undef);
            $toStore = 1;
        }
    }

    if ($toStore) {
        $row->store();
    }
}

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
            foreignModel  => $self->modelGetter('network', 'ObjectTable'),
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
        new EBox::Squid::Types::UnlimitedInt(
            fieldName     => 'size',
            printableName => __('Maximum unlimited size'),
            help          => __('Maximum unthrottled download size for the whole network object.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('MB'),
            min           => 0,
        ),
        new EBox::Squid::Types::UnlimitedInt(
            fieldName     => 'rate',
            printableName => __('Maximum download rate'),
            help          => __('Limited download rate after maximum size is reached for the whole network object.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('KB/s'),
        ),
        new EBox::Types::Boolean(
            fieldName      => 'clt_enabled',
            printableName  => __('Enable per client limit'),
            editable       => 1,
            hiddenOnViewer => 1,
            defaultValue   => 0,
        ),
        new EBox::Squid::Types::UnlimitedInt(
            fieldName     => 'clt_size',
            printableName => __('Maximum unlimited size per client'),
            help          => __('Maximum unthrottled download size for each client.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('MB'),
        ),
        new EBox::Squid::Types::UnlimitedInt(
            fieldName     => 'clt_rate',
            printableName => __('Maximum download rate per client'),
            help          => __('Limited download rate after maximum size is reached for each client.'),
            size          => 3,
            editable      => 1,
            trailingText  => __('KB/s'),
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

    my $objects = EBox::Global->modInstance('network');

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
                        rate => defined ($rate) ? $rate : -1,
                        size => defined ($size) ? $size : -1,
                        clt_rate => defined ($clt_rate) ? $clt_rate : -1,
                        clt_size => defined ($clt_size) ? $clt_size : -1,
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
                  'on' => { enable => [ 'size', 'rate' ] },
                  'off' => { disable  => [ 'size', 'rate' ] },
                },
              clt_enabled =>
                {
                  'on' => { enable => [ 'clt_size', 'clt_rate' ] },
                  'off' => { disable  => [ 'clt_size', 'clt_rate' ] },
                },
            });

    return $customizer;
}

1;
