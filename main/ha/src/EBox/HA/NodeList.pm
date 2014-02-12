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

use Clone::Fast;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::InvalidType;
use List::Util qw(max);
use Test::Deep qw(ignore eq_deeply);
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
#    port - Int the webadmin listening port
#
#    localNode - Boolean to indicate if it is a local node *(Optional)*
#                Default value: False
#
#    nodeid - Int the node identifier delivered to the cluster
#             membership service *(Optional)* If it is not set, then
#             the max of nodeid plus
#
sub set
{
    my ($self, %params) = @_;

    my $state = $self->{ha}->get_state();

    my $localNode = $params{localNode};
    $localNode = 0 unless ($localNode);
    my $nodeId = $params{nodeid};
    unless (defined($nodeId)) {
        if (exists($state->{cluster_conf}->{nodes}->{$params{name}})) {
            $nodeId = $state->{cluster_conf}->{nodes}->{$params{name}}->{nodeid};
        } else {
            $nodeId = max(map { $_->{nodeid} } @{$self->list()});
            $nodeId = 0 unless(defined($nodeId));
            $nodeId++;
        }
    }

    $state->{cluster_conf}->{nodes}->{$params{name}} = { name => $params{name},
                                                         addr => $params{addr},
                                                         port => $params{port},
                                                         localNode => $localNode,
                                                         nodeid => $nodeId
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
#       port - Int the web admin port
#       localNode - Boolean local node flag
#       nodeid - Int the node identifier
#
sub list
{
    my ($self) = @_;

    my @nodeList = values(%{$self->{ha}->get_state()->{cluster_conf}->{nodes}});
    return \@nodeList;
}

# Method: node
#
#    Return the required node
#
# Parameters:
#
#    name - String the node name
#
# Returns:
#
#    Hash ref - with the node
#
#       addr - String the IP address
#       name - String the node name
#       port - Int the web admin port
#       localNode - Boolean local node flag
#       nodeid - Int the node identifier
#
# Exceptions:
#
#    <EBox::Exceptions::DataNotFound> - thrown if the node is not in
#                                        the list
sub node
{
    my ($self, $name) = @_;

    my $nodes = $self->{ha}->get_state()->{cluster_conf}->{nodes};
    if (exists($nodes->{$name})) {
        return $nodes->{$name};
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'node', value => $name);
    }
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
#       port - Int the web admin port
#       localNode - Boolean local node flag
#       nodeid - Int the node identifier
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

# Method: diff
#
#     Get the difference between the object and a hash ref which is
#     the result of another object <EBox::HA::NodeList::list>
#
# Parameters:
#
#     other - Array ref the contents of <list> applies here
#
# Returns:
#
#     Tuple:
#
#     equal - Boolean indicating if they are both equal
#     Hash ref - containing the diff, if any, following keys:
#
#        new - nodes that are in the other and not in self
#        old - nodes that are in self and not in other
#        changed - nodes that are in both with different parameters
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidType> - thrown if the hash ref within
#     the array type are invalid
#
sub diff
{
    my ($self, $other) = @_;

    if (ref($other) ne 'ARRAY') {
        throw EBox::Exceptions::InvalidType('other', 'ARRAY ref');
    }

    my $state = $self->{ha}->get_state();

    my %other = map { $_->{name} => $_ } @{$other};
    my %mine = ();
    if (exists($state->{cluster_conf}->{nodes})) {
        %mine = %{Clone::Fast::clone($state->{cluster_conf}->{nodes})};
    }

    my $equal = Test::Deep::eq_deeply(\%mine, \%other);
    return (1, {}) if ($equal);

    my @new = ();
    my @old = ();
    my @changes = ();
    foreach my $otherNode (keys %other) {
        if (exists($mine{$otherNode})) {
            # Ignore localNode param
            $mine{$otherNode}->{localNode} = ignore();
            push(@changes, $otherNode) unless (Test::Deep::eq_deeply($other{$otherNode}, $mine{$otherNode}));
        } else {
            push(@new, $otherNode);
        }
    }
    foreach my $myNode (keys %mine) {
        push(@old, $myNode) unless (exists($other{$myNode}));
    }

    return (0, {new => \@new, old => \@old, changed => \@changes});

}

# Method: size
#
#    Return the list size (number of elements)
#
# Returns:
#
#    Int - the number of elements from the list
#
sub size
{
    my ($self) = @_;

    return scalar(keys(%{$self->{ha}->get_state()->{cluster_conf}->{nodes}}));
}

1;
