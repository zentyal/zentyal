# Copyright (C) 2012-2014 Zentyal S.L.
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

# Class: EBox::WebAdmin::Model::AdminPort
#
#   This model is used to configure the interface port. It is just a
#   view of the model <EBox::HAProxy::Model::HAProxyServices> for
#   Webadmin service row.
#
use strict;
use warnings;

package EBox::WebAdmin::Model::AdminPort;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Port;
use TryCatch::Lite;

# Group: Public methods

# Method: validateTypedRow
#
#     Override to check if the selected port is already taken
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedValues, $allValues) = @_;

    my $webadminModro = EBox::Global->getInstance(1)->modInstance('webadmin');
    if (exists $changedValues->{port}) {
        my $actualPort = $webadminModro->listeningPort();
        my $port = $changedValues->{port}->value();
        if ($port != $actualPort) {
            my $haProxyModel = $self->parentModule()->global()->modInstance('haproxy')->model('HAProxyServices');
            my $default = 1;
            $haProxyModel->validateHTTPSPortChange($port, $webadminModro->serviceId, $default);
        }
    }
}

# Method: updatedRowNotify
#
#     Override to notify HAProxy the change in the port
#
# Overrides:
#
#     <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $port = $row->valueByName('port');
    my $oldPort = $oldRow->valueByName('port');
    if ($port != $oldPort) {
        my $haProxyMod = $self->parentModule()->global()->modInstance('haproxy');
        $haProxyMod->updateServicePorts('webadmin', [$port]);
        $self->setMessage(
            __('Take into account you have to manually change the URL once the save changes'
               . ' process is started to see web administration again.'),
            'warning');
    }
}

# Group: Protected methods

sub _table
{
    my ($self) = @_;

    my $webadminMod = $self->parentModule();

    my @tableHead = (
        new EBox::Types::Port(fieldName      => 'port',
                              editable       => 1,
                              defaultValue   => $webadminMod->defaultHTTPSPort(),
                              volatile       => 1,
                              acquirer       => \&_acquirePort,
                              storer         => \&_storePort)
    );

    my $dataTable =
    {
        'tableName' => 'AdminPort',
        'printableTableName' => __('Administration interface TCP port'),
        'modelDomain' => 'WebAdmin',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
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
    my $haProxySrv = $model->find(module => 'webadmin');
    if ($haProxySrv) {
        return $haProxySrv->valueByName('sslPort');
    }
    return undef;
}

# Set the port
sub _storePort
{
    my ($type, $hash) = @_;

    # store in the model as normal
    $type->_storeInHash($hash);

    my $haProxy = $type->model()->parentModule()->global()->modInstance('haproxy');
    my $model = $haProxy->model('HAProxyServices');
    my $haProxySrv = $model->find(module => 'webadmin');
    if ($haProxySrv) {
        $haProxySrv->elementByName('sslPort')->setValue({'sslPort_number' => $type->value()});
        $haProxySrv->store();
    } else {
        EBox::error('HA proxy service for webadmin does not exist');
    }
}

1;
