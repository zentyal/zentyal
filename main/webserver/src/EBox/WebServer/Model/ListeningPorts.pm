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
use strict;
use warnings;
no warnings 'experimental::smartmatch';

# Class: EBox::WebServer::Model::ListeningPorts
#
#   Form to set the general configuration settings for the web server.
#
package EBox::WebServer::Model::ListeningPorts;
use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use EBox::Validate;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;

use TryCatch::Lite;


# Method: validateTypedRow
#
#     Override to check:
#
#     * if both ports are disabled
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedValues, $allValues) = @_;

    my $port = $allValues->{port}->value();
    if (exists $changedValues->{port}) {
        $port = $changedValues->{port}->value();
    }
    my $SSLPort = $allValues->{sslPort}->value();
    if (exists $changedValues->{sslPort}) {
        $SSLPort = $changedValues->{sslPort}->value();
    }

    if ($port ~~ 'port_disabled' and $SSLPort ~~ 'sslPort_disabled') {
        throw EBox::Exceptions::External(__('You must enable, at least, a listening port to make this module useful.'));
    }
}

# Method: row
#
#       Return the row reading data from HAProxy configuration.
#
# Overrides:
#
#       <EBox::Model::DataForm::row>
#
sub row
{
    my ($self, $id) = @_;

    my $webserverMod = $self->parentModule();
    my $haProxy = $webserverMod->global()->modInstance('haproxy');
    my $model = $haProxy->model('HAProxyServices');
    my $haProxySrv = $model->find(module => 'webserver');
    my @values = ();
    if ($haProxySrv) {
        if ($haProxySrv->elementByName('port')->selectedType() eq 'port_number') {
            push (@values, port => { port_number   => $haProxySrv->valueByName('port') });
        }
        if ($haProxySrv->elementByName('sslPort')->selectedType() eq 'sslPort_number') {
            push (@values, sslPort => { sslPort_number    => $haProxySrv->valueByName('sslPort') });
        }
    } else {
        push (@values, port => { port_number   => $webserverMod->defaultHTTPPort()});
    }

    my $row = $self->_setValueRow(@values);
    $row->setId('form');
    return $row;
}

# Method: setTypedRow
#
#       Set an existing row using types to fill the fields. The unique
#       row is set here. If there was no row, it is created.
#
# Overrides:
#
#       <EBox::Model::DataForm::setTypedRow>
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $force = delete $optParams{'force'};
    my $readOnly = delete $optParams{'readOnly'};

    my $global = $self->parentModule()->global();
    my $webserverMod = $self->parentModule();
    my $haproxyMod = $global->modInstance('haproxy');

    my $oldRow = $self->row($id);
    my $allHashElements = $oldRow->hashElements();
    $self->validateTypedRow('update', $paramsRef, $allHashElements);

    # replace old values with setted ones
    while (my ($name, $value) = each %{ $paramsRef } ) {
        $allHashElements->{$name} = $value;
    }

    # Save port settings in reverse proxy
    my $port = $allHashElements->{port};
    my $sslPort = $allHashElements->{sslPort};
    my @args = ();
    push (@args, modName        => $webserverMod->name());
    if ($port->selectedType() eq 'port_number') {
        push (@args, port           => $port->value());
        push (@args, enablePort     => 1);
    } else {
        push (@args, enablePort     => 0);
    }
    if ($sslPort->selectedType() eq 'sslPort_number') {
        push (@args, sslPort        => $sslPort->value());
        push (@args, enableSSLPort  => 1);
    } else {
        push (@args, enableSSLPort  => 0);
    }
    $haproxyMod->setHAProxyServicePorts(@args);
    $self->setMessage($self->message('update'));
}

# Method: _table
#
#       The table description which consists of three fields:
#
#       port        - <EBox::Types::Union>
#       sslPort     - <EBox::Types::Union>
#       enabledDir  - <EBox::Types::Boolean>
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $webserverMod = $self->parentModule();

    my @tableHeader = (
        new EBox::Types::Union(
            fieldName     => 'port',
            printableName => __('HTTP listening port'),
            subtypes => [
                new EBox::Types::Union::Text(
                    fieldName => 'port_disabled',
                    printableName => __('Disabled'),
                    optional => 1,
                ),
                new EBox::Types::Port(
                    fieldName     => 'port_number',
                    printableName => __('Enabled'),
                    editable      => 1,
                    defaultValue  => $webserverMod->defaultHTTPPort(),
                ),
            ],
        ),
        new EBox::Types::Union(
            fieldName     => 'sslPort',
            printableName => __('HTTPS listening port'),
            subtypes => [
                new EBox::Types::Union::Text(
                    fieldName => 'sslPort_disabled',
                    printableName => __('Disabled'),
                    optional => 1,
                ),
                new EBox::Types::Port(
                    fieldName     => 'sslPort_number',
                    printableName => __('Enabled'),
                    editable      => 1,
                    defaultValue  => $webserverMod->defaultHTTPSPort(),
                ),
            ],
        ),
    );

    my $dataTable = {
        tableName          => 'ListeningPorts',
        printableTableName => __('Listening Ports settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Listening Ports configuration'),
        messages           => {
                                update => __('Listening ports configuration settings updated.'),
                              },
        modelDomain        => 'WebServer',
    };

    return $dataTable;
}

1;
