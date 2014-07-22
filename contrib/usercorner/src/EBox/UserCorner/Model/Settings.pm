# Copyright (C) 2009-2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::UserCorner::Model::Settings;
#
#   Model to configure User Corner SSL listening port. It is just a
#   view of the model <EBox::HAProxy::Model::HAProxyServices> for
#   usercorner service row.
#

use strict;
use warnings;

package EBox::UserCorner::Model::Settings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;
use EBox::Exceptions::DataExists;

use parent 'EBox::Model::DataForm';

# Group: Public methods

# Method: pageTitle
#
#    Set a page title since it is alone in the page
#
# Overrides:
#
#    <EBox::Model::Component::pageTitle>
#
sub pageTitle
{
    return __('User Corner');
}

# Method: validateTypedRow
#
# Overrides:
#
# <EBox::Model::DataTable::ValidateTypedRow>
#
# Exceptions:
#
# <EBox::Exceptions::External> - if the port number is already
# in use by any other HA proxy service.
#
sub validateTypedRow
{
    my ($self, $action, $changedValues, $allValues) = @_;

    my $usercornerModro = EBox::Global->getInstance(1)->modInstance('usercorner');
    if (exists $changedValues->{port}) {
        my $actualPort = $usercornerModro->listeningHTTPSPort();
        my $port = $changedValues->{port}->value();
        if ($port != $actualPort) {
            my $haProxyModel = $self->parentModule()->global()->modInstance('haproxy')->model('HAProxyServices');
            my $default = 1;
            $haProxyModel->validateHTTPSPortChange($port, $usercornerModro->serviceId, $default);
        }
    }

}

# Method: updatedTypedRow
#
#     Override to notify HAProxy the change in the port
#
# Overrides:
#
#     <EBox::Model::DataTable::formSubmitted>
#
sub formSubmitted
{
    my ($self, $row, $oldRow, $force) = @_;

    my $port = $row->valueByName('port');
    my $oldPort;
    if ($oldRow) {
        $oldPort = $oldRow->valueByName('port');
    } else {
        $oldPort = $row->elementByName('port')->defaultValue();
    }
    if ($port != $oldPort) {
        my $haProxyMod = $self->parentModule()->global()->modInstance('haproxy');
        $haProxyMod->updateServicePorts('usercorner', [$port]);
    }

}

# Group: Protected methods

sub _table
{
    my ($self) = @_;

    my @tableHead =
    (
        new EBox::Types::Port(
            'fieldName'     => 'port',
            'printableName' => __('Port'),
            'editable'      => 1,
            'defaultValue'  => $self->parentModule()->defaultHTTPSPort(),
            'volatile'      => 1,
            'acquirer'      => \&_acquirePort,
            'storer'        => \&_storePort
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Settings',
        'printableTableName' => __('General configuration'),
        'modelDomain' => 'UserCorner',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('This module enables a HTTPS server to allow the users to change their own data like their password. Here you can choose the port where to accept HTTPS connections.'),
    };

    return $dataTable;
}

# Group: Subroutines

# Get the port
sub _acquirePort
{
    my ($type) = @_;

    my $haProxy = $type->model()->parentModule()->global()->modInstance('haproxy');
    my $model = $haProxy->model('HAProxyServices');
    my $haProxySrv = $model->find(module => 'usercorner');
    if ($haProxySrv) {
        return $haProxySrv->valueByName('sslPort');
    }
    return undef;
}

# Set the port
sub _storePort
{
    my ($type, $hash) = @_;

    my $haProxy = $type->model()->parentModule()->global()->modInstance('haproxy');
    my $model = $haProxy->model('HAProxyServices');
    my $haProxySrv = $model->find(module => 'usercorner');
    if ($haProxySrv) {
        $haProxySrv->elementByName('sslPort')->setValue({'sslPort_number' => $type->value()});
        $haProxySrv->store();
    } else {
        EBox::error('HA proxy service for usercorner does not exist');
    }
}


1;
