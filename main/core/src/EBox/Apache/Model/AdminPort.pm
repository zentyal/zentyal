# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::Apache::Model::AdminPort
#
#   This model is used to configure the interface port
#
use strict;
use warnings;

package EBox::Apache::Model::AdminPort;
use base 'EBox::Model::DataForm';

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Port;

use constant APACHE_PORT => 443;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Port(fieldName      => 'port',
                                           editable       => 1,
                                           defaultValue   => APACHE_PORT));

    my $dataTable =
    {
        'tableName' => 'AdminPort',
        'printableTableName' => __('Administration interface TCP port'),
        'modelDomain' => 'Apache',
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
