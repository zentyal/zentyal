# Copyright (C) 2009-2010 eBox Technologies S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::UserCornerWebServer::Model::settings;
#
#   TODO: Document class
#

package EBox::UserCornerWebServer::Model::Settings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub pageTitle
{
    return __('User Corner');
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Port(
            'fieldName' => 'port',
            'printableName' => __('Port'),
            'editable' => 1,
            'defaultValue' => 8888
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Settings',
        'printableTableName' => __('General configuration'),
        'modelDomain' => 'UserCorner',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

# Method: validateTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::ValidateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::DataExists> - if the port number is already
#       in use by any ebox module
#
sub validateTypedRow
{

    my ($self, $action, $changedFields) = @_;

    if ( exists $changedFields->{port} and $action eq 'update') {
        my $portNumber = $changedFields->{port}->value();

        my $gl = EBox::Global->getInstance();
        my $firewall = $gl->modInstance('firewall');

        unless ( $firewall->availablePort('tcp', $portNumber) ) {
            throw EBox::Exceptions::DataExists(
                                               'data'  => __('listening port'),
                                               'value' => $portNumber,
                                              );
        }

        my $services = $gl->modInstance('services');
        if (not $services->serviceExists(name => 'usercorner')) {
            $services->addService('name' => 'usercorner',
                    'protocol' => 'tcp',
                    'sourcePort' => 'any',
                    'destinationPort' => $portNumber,
                    'translationDomain' => 'ebox-usersandgroups',
                    'internal' => 1,
                    'readOnly' => 1
                    );
            my $firewall = $gl->modInstance('firewall');
            $firewall->setInternalService('usercorner', 'accept');
        } else {
            $services->updateDestPort('usercorner/0', $portNumber);
        }
    }
}

# Method: precondition
#
#   Overrides  <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my $users = EBox::Global->modInstance('users');

    return $users->editableMode();
}

# Method: preconditionFailMsg
#
#   Overrides  <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    return __('User Corner is not supported on slave servers.');
}

1;
