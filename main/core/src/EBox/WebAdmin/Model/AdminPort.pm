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

# Class: EBox::WebAdmin::Model::AdminPort
#
#   This model is used to configure the interface port
#
package EBox::WebAdmin::Model::AdminPort;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use TryCatch::Lite;

use EBox::Gettext;
use EBox::Types::Port;

use constant DEFAULT_ADMIN_PORT => 443;

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Port(fieldName      => 'port',
                                           editable       => 1,
                                           defaultValue   => DEFAULT_ADMIN_PORT));

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

sub validateTypedRow
{
    my ($self, $action, $changedValues, $allValues) = @_;

    my $port = $changedValues->{port}->value();
    $self->parentModule()->checkAdminPort($port);
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $port = $row->valueByName('port');
    $self->parentModule()->updateAdminPortService($port);
}

1;
