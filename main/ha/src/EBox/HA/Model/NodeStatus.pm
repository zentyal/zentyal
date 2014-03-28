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

package EBox::HA::Model::NodeStatus;

# Class: EBox::HA::Model::NodeStatus
#
#     Model to show the state of the cluster's nodes
#

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::HA::ClusterStatus;
use EBox::Types::Host;

# Group: Public methods

# Method: ids
#
#     Return the current list of node names
#
# Overrides:
#
#     <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self)  = @_;

    $self->{clusterStatus} = new EBox::HA::ClusterStatus(ha => $self->parentModule());

    unless (defined($self->{clusterStatus}->nodes())) {
        return [];
    }

    my @names = keys %{$self->{clusterStatus}->nodes()};

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

    my %node = %{ $self->{clusterStatus}->nodeByName($name) };

    my $row = new EBox::Model::Row(dir => $self->directory(), confmodule => $self->parentModule());
    $row->setId($name);
    $row->setModel($self);
    $row->setReadOnly(1);

    my $tableDesc = $self->table()->{tableDescription};
    foreach my $type (@{$tableDesc}) {
        my $element = $type->clone();

        # To parse each field we call the method _parseNode_{field} stored
        # as a string in $parseFunction. No if/switch, so this can grow bigger
        my $parseFunction = "_parseNode_" . $element->fieldName();
        $parseFunction = \&$parseFunction;
        $element->setValue($parseFunction->($self, %node));

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
            new EBox::Types::Host(
                fieldName     => 'name',
                printableName => __('Hostname'),
                ),
            new EBox::Types::Text(
                fieldName     => 'status',
                printableName => __('Status'),
                ),
            new EBox::Types::Text(
                fieldName     => 'floating',
                printableName => __('Floating IP'),
                ),
            );

    my $dataTable =
    {
        tableName => 'Node Status',
        defaultActions => [ 'changeView' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
        withoutActions => 1,
        showPaginationForm => 0,
        showFilterForm => 0,
        noDataMsg => __('The cluster does not have any nodes.'),
        help => undef,
    };

    return $dataTable;
}

# Group: Private methods

sub _parseNode_name
{
    my ($self, %node) = @_;

    return $node{'name'} ? $node{'name'} : __('noname');
}

sub _parseNode_status
{
    my ($self, %node) = @_;

    return $node{'online'} ? "On-line" : "Off-line";
}

sub _parseNode_floating
{
    my ($self, %node) = @_;

    my %resources = %{ $self->{clusterStatus}->resources() };
    my $result = "";

    foreach my $key (keys %resources) {
        my %resource = %{ $resources{$key} };

        if ($resource{'resource_agent'} eq 'ocf::heartbeat:IPaddr2') {
            foreach my $nodeId (@{$resource{'nodes'}}) {
                my $managingNode = $self->{clusterStatus}->nodeByName($nodeId);

                if ($node{'name'} eq $managingNode->{'name'}) {
                    $result = $result . " - " if ($result);
                    $result = $result . $resource{'id'} . " ";
                }
            }
        }
    }

    return $result;
}

1;
