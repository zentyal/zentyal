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

# Class: EBox::HA::NodeList
#
#    This class is responsible to manage the storage of the nodes in the cluster
#
#    Each node has an IP address, web admin port and name.

package EBox::HA::NodeList;

use EBox::Exceptions::DataNotFound;
use TryCatch::Lite;

# Group: Public methods

# Constructor: new
#
# Parameters:
#
#      ha - <EBox::HA> module instance
#
sub new
{
    my ($class, $ha) = @_;

    my $self = { ha => $ha };
    bless($self, $class);
    return $self;
}

# Method: set
#
#    Add a new node or update the information if it already exists
#
# Named parameters:
#
#    name - String the name for the node
#
#    addr - String the IP address
#
#    webAdminPort - Int the webadmin listening port
#
#    localNode - Boolean to indicate if it is a local node *(Optional)*
#                Default value: False
#
sub set
{
    my ($self, %params) = @_;

    my $state = $self->{ha}->get_state();
    my $localNode = $params{localNode};
    $localNode = 0 unless ($localNode);

    $state->{cluster_conf}->{nodes}->{$params{name}} = { name => $params{name},
                                                         addr => $params{addr},
                                                         webAdminPort => $params{webAdminPort},
                                                         localNode => $localNode
                                                        };

    $self->{ha}->set_state($state);
}

# Method: remove
#
#    Remove a node
#
# Parameters:
#
#    name - String the name for the node
#
# Exceptions:
#
#    <EBox::Exceptions::DataNotFound> - raise when the node does not exist
#
sub remove
{
    my ($self, $name) = @_;

    my $state = $self->{ha}->get_state();

    if (defined($state->{cluster_conf}->{nodes}->{$name})) {
        delete $state->{cluster_conf}->{nodes}->{$name};
        $self->{ha}->set_state($state);
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'node', value => $name);
    }
}

# Method: empty
#
#      Empty the node list. That is, remove every node in the list
#
# Returns:
#
#      Int - the number of nodes removed from the list
#
sub empty
{
    my ($self) = @_;

    my $state = $self->{ha}->get_state();
    my $nElements = scalar(keys(%{$state->{cluster_conf}->{nodes}}));

    if ($nElements > 0) {
        delete $state->{cluster_conf}->{nodes};
        $self->{ha}->set_state($state);
    }

    return $nElements;
}

# Method: list
#
#    Return the node list
#
# Returns:
#
#    Array ref - with the nodes which are hash ref with these components
#
#       addr - String the IP address
#       name - String the node name
#       webAdminPort - Int the web admin port
#       localNode - Boolean local node flag
#
sub list
{
    my ($self) = @_;

    my @nodeList = values(%{$self->{ha}->get_state()->{cluster_conf}->{nodes}});
    return \@nodeList;
}

# Method: localNode
#
#    Return the local node data
#
# Returns:
#
#    Hash ref - with the configuration for the local node
#
#       addr - String the IP address
#       name - String the node name
#       webAdminPort - Int the web admin port
#       localNode - Boolean local node flag
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - thrown if there is no local node
#
sub localNode
{
    my ($self) = @_;

    my $list = $self->list();
    my @local = grep { $_->{localNode} } @{$list};
    if (@local > 0) {
        return $local[0];
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'node',
                                             value => 'localNode');
    }
}

1;
