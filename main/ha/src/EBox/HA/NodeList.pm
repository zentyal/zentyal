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
sub set
{
    my ($self, %params) = @_;

    my $state = $self->{ha}->get_state();

    $state->{nodes}->{$params{name}} = { name => $params{name},
                                         addr => $params{addr},
                                         webAdminPort => $params{webAdminPort} };

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

    if (defined($state->{nodes}->{$name})) {
        delete $state->{nodes}->{$name};
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
    my $nElements = scalar(keys(%{$state->{nodes}}));

    if ($nElements > 0) {
        delete $state->{nodes};
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
#
sub list
{
    my ($self) = @_;

    my @nodeList = values(%{$self->{ha}->get_state()->{nodes}});
    return \@nodeList;
}

1;
