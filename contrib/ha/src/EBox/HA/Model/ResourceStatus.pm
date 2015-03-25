# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Model::ResourceStatus;

# Class: EBox::HA::Model::ResourceStatus
#
#     Model to show the state of the cluster's resources
#

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::HA::ClusterStatus;

# Group: Public methods

# Method: ids
#
#     Return the current list of resource names
#
# Overrides:
#
#     <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self)  = @_;

    $self->{clusterStatus} = new EBox::HA::ClusterStatus(ha => $self->parentModule());

    unless (defined($self->{clusterStatus}->resources())) {
        return [];
    }

    my @names = keys %{$self->{clusterStatus}->resources()};

    return \@names;
}

# Method: row
#
#     Return a node names
#
# Overrides:
#
#     <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $name)  = @_;

    if (not defined ($self->{clusterStatus})) {
        $self->{clusterStatus} = new EBox::HA::ClusterStatus(ha => $self->parentModule());
    }

    my %resource = %{ $self->{clusterStatus}->resourceByName($name) };

    my $row = new EBox::Model::Row(dir => $self->directory(), confmodule => $self->parentModule());
    $row->setId($name);
    $row->setModel($self);
    $row->setReadOnly(1);

    my $tableDesc = $self->table()->{tableDescription};
    foreach my $type (@{$tableDesc}) {
        my $element = $type->clone();

        # To parse each field we call the method _parseNode_{field} stored
        # as a string in $parseFunction. No if/switch, so this can grow bigger
        my $parseFunction = "_parseResource_" . $element->fieldName();
        $parseFunction = \&$parseFunction;
        $element->setValue($parseFunction->($self, %resource));

        $row->addElement($element);
    }

    return $row;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @fields = (
            new EBox::Types::Text(
                fieldName     => 'resource',
                printableName => __('Resource'),
                ),
            new EBox::Types::Text(
                fieldName     => 'started',
                printableName => __('Started at'),
                ),
            );

    my $dataTable =
    {
        tableName => 'Resource Status',
        defaultActions => [ 'changeView' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
        withoutActions => 1,
        showPaginationForm => 0,
        showFilterForm => 0,
        noDataMsg => __('The cluster does not have any resources defined.'),
        help => undef,
    };

    return $dataTable;
}

# Group: Private methods

sub _parseResource_resource
{
    my ($self, %resource) = @_;

    return $resource{'id'} ? $resource{'id'} : __('noname');
}

sub _parseResource_started
{
    my ($self, %resource) = @_;

    my $nodes = $resource{'nodes'};
    my @nodeNames = map { $self->{clusterStatus}->nodeByName($_)->{'name'} } @{$nodes};

    return join(', ', @nodeNames);
}

1;
