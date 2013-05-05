# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Network::Model::BalanceGateways;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Gettext;
use EBox::Types::Text;

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $network = $self->parentModule();
    my $gwModel = $network->model('GatewayTable');

    my %newGateways =
        map { $gwModel->row($_)->valueByName('name') => $_ } @{$gwModel->ids()};

    my %currentGateways =
        map { $self->row($_)->valueByName('name') => $_ } @{$currentRows};

    my $modified = 0;

    my @gwsToAdd = grep { not exists $currentGateways{$_} } keys %newGateways;
    my @gwsToDel = grep { not exists $newGateways{$_} } keys %currentGateways;

    foreach my $gw (@gwsToAdd) {
        $self->add(name => $gw);
        $modified = 1;
    }

    foreach my $gw (@gwsToDel) {
        $self->removeRow($currentGateways{$gw}, 1);
        $modified = 1;
    }

    return $modified;
}

# Method: _table
#
#
sub _table
{
    my @tableHeader = (
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Gateway'),
                             editable      => 0,
                            ),
    );

    my $dataTable = {
        tableName          => 'BalanceGateways',
        printableTableName => __('Gateways for Traffic Balance'),
        modelDomain        => 'Network',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        enableProperty     => 1,
        defaultEnabledValue => 1,
        class              => 'dataTable',
        printableRowName   => __('gateway'),
        help               => __('Here you can choose which gateways are used to balance the traffic'),
    };
}

1;
