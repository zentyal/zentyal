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

package EBox::HA::Model::Nodes;

# Class: EBox::HA::Model::Nodes
#
#     Model to show the nodes from the cluster
#

use base 'EBox::Model::DataTable';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::HA::NodePromoter;
use EBox::HA::ClusterStatus;
use EBox::HA::NodeList;
use EBox::Types::Host;
use EBox::Types::HostIP;
use EBox::Types::MultiStateAction;
use EBox::Types::Port;
use EBox::Types::HTML;
use TryCatch::Lite;

# Group: Public methods

# Constructor: new
#
#    To store the list
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    $self->{list} = new EBox::HA::NodeList($self->parentModule());

    return $self;
}

# Method: size
#
#      To optimise the command calls
#
# Overrides:
#
#     <EBox::Model::DataTable::size>
#
sub size
{
    my ($self) = @_;

    return $self->{list}->size();
}

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

    # Calculate and cache the nodes status
    $self->{nodesStatus} = $self->{clusterStatus}->nodes();
    $self->{resourcesNum} = $self->{clusterStatus}->numberOfResources();

    my @names = map { $_->{name} } @{$self->{list}->list()};
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
    my ($self, $id)  = @_;

    my $node = $self->{list}->node($id);
    my $name = $node->{name};

    if (not defined ($self->{clusterStatus})) {
        $self->{clusterStatus} = new EBox::HA::ClusterStatus(ha => $self->parentModule());
    }

    my $row = new EBox::Model::Row(dir => $self->directory(), confmodule => $self->parentModule());
    $row->setId($id);
    $row->setModel($self);
    $row->setReadOnly(1);

    my $errors = $self->parentModule()->get_state()->{errors};

    my $okHTML = '<p style="color: green">' . __('OK') . '</p>';
    my $retry = __('Retry');
    my $js = "Zentyal.TableHelper.setLoading('retrybtn_$name'); Zentyal.HA.replicate('$name')";
    my $retryHTML = "<button id=\"retrybtn_$name\" onclick=\"$js\">$retry</button>";

    my $tableDesc = $self->table()->{tableDescription};
    foreach my $type (@{$tableDesc}) {
        my $element = $type->clone();
        if ($type->fieldName() eq 'status') {
            if ($self->{clusterStatus}->nodeByName($id)) {
                my %nodeInfo = %{ $self->{clusterStatus}->nodeByName($id) };
                $element->setValue($nodeInfo{online} ? __('On-line') : __('Off-line'));
            }
        } elsif ($type->fieldName() eq 'replication') {
            if ($errors->{$name}) {
                $element->setValue($retryHTML);
            } else {
                $element->setValue($okHTML);
            }
        } else {
            $element->setValue($node->{$element->fieldName()});
        }
        $row->addElement($element);
    }

    return $row;
}

# Method: printableModelName
#
#     Showing the dynamic cluster name
#
# Overrides:
#
#     <EBox::Model::DataTable.:printableModelName>
#
sub printableModelName
{
    my ($self) = @_;

    my $clusterName = $self->parentModule()->model('Cluster')->nameValue();
    return __x('Node list for {name} cluster', name => $clusterName);
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
            fieldName     => 'status',
            printableName => __('Status'),
        ),
        new EBox::Types::Host(
            fieldName     => 'name',
            printableName => __('Hostname'),
        ),
        new EBox::Types::HostIP(
            fieldName     => 'addr',
            printableName => __('IP address'),
        ),
        new EBox::Types::Port(
            fieldName     => 'port',
            printableName => __('Port'),
        ),
        new EBox::Types::HTML(
            fieldName     => 'replication',
            printableName => __('Replication'),
        ),
    );
    my $customActions = [
        new EBox::Types::MultiStateAction(
            acquirer  => \&_acquireActive,
            model     => $self,
            states    => {
                'active'  => {
                    name           => 'demote',
                    printableValue => __('Demote'),
                    handler        => \&_doDemote,
                    enabled        => \&_prodemoteContraints,
                },
                'passive' => {
                    name           => 'promote',
                    printableValue => __('Promote'),
                    handler        => \&_doPromote,
                    enabled        => \&_prodemoteContraints,
                }
               },
           ),
       ];

    my $dataTable =
    {
        tableName => 'Nodes',
        printableTableName => __('Node list for cluster'),
        defaultActions => [ 'changeView' ],
        customActions  => $customActions,
        modelDomain => 'HA',
        tableDescription => \@fields,
        noDataMsg => __('The cluster does not have any nodes.'),
        help => undef,
    };

    return $dataTable;
}

# Group: Subroutines handlers

# Knowing if I'm the active/passive
sub _acquireActive
{
    my ($self, $id) = @_;

    my $activeNode = $self->{clusterStatus}->activeNode();

    return ($activeNode eq $id ? 'active' : 'passive');
}

# The constraints to have promote/demote
#   * Any resource is configured
#   * More than node is online
#   * The node is online
sub _prodemoteContraints
{
    my ($self, $actionType, $id) = @_;

    return 0 unless ($self->{resourcesNum} > 0);
    my $nodesStatus = $self->{nodesStatus};
    return 0 unless (exists $nodesStatus->{$id});
    my $nOnline = grep { $_->{online} } values %{$nodesStatus};
    return 0 unless ($nOnline > 1);
    return $nodesStatus->{$id}->{online};
}

# Do promote by moving all resources to the given node
sub _doPromote
{
    my ($self, $actionType, $id, %params) = @_;

    try {
        EBox::HA::NodePromoter::promote($id);
        $self->setMessage(__x('Node {name} is now the active node', name => $id),
                          'note');
    } catch ($exc) {
        throw EBox::Exceptions::External("Couldn't promote: $exc");
    };
}

# Do demote by moving out all resources from the given node
sub _doDemote
{
    my ($self, $actionType, $id, %params) = @_;

    try {
        EBox::HA::NodePromoter::demote($id);
        $self->setMessage(__x('Node {name} is now a passive node', name => $id),
                          'note');
    } catch ($exc) {
        throw EBox::Exceptions::External("Couldn't promote: $exc");
    };
}

1;
