#!/usr/bin/perl -w
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

package EBox::HA::Server::Router;

use EBox::Exceptions::DataNotFound;
use EBox::Global;
use EBox::HA;

# Package: EBox::HA::Server::Router
#
#   Router in the middle of the PSGI app and the HA module
#

# The URL dispatcher
my $routes = {
    qr{/cluster/auth$}          => { 'GET'    => sub { 1; } },
    qr{/cluster/configuration$} => { 'GET'    => \&EBox::HA::clusterConfiguration,
                                     'PUT'    => \&EBox::HA::updateClusterConfiguration },

    qr{/cluster/nodes$}         => { 'GET'    => \&EBox::HA::nodes,
                                     'POST'   => \&EBox::HA::addNode },

    qr{/cluster/nodes/(?<name>[a-zA-Z0-9\-\.]+)$}
                                => { 'DELETE' => \&EBox::HA::deleteNode },

    qr{/cluster/conf/replication$}
                                => { 'GET'    => \&EBox::HA::confReplicationStatus,
                                     'POST'   => \&EBox::HA::replicateConf },
    qr{/cluster/conf/ask/replication/(?<name>[a-zA-Z0-9\-\.]+)$}
                                => { 'POST'   => \&EBox::HA::askForReplicationNode },
};

# Function: routeExists
#
#     Return if a route exists
#
# Parameters:
#
#     route - String
#
sub routeExists
{
    my ($route) = @_;

    my @ret =  grep { $route =~ $_ } keys %{$routes};
    return scalar(@ret);
}

# Function: routeConf
#
#     Return if the configuration for the first matched route
#
# Parameters:
#
#     route - String
#
# Returns:
#
#     Array - the first element is a hash ref with supported methods
#             and the second one is the named parameters substitution
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the route does not exist
#
sub routeConf
{
    my ($route) = @_;

    my @routeKeys = grep { $route =~ $_ } keys %{$routes};
    if (scalar(@routeKeys) < 1) {
        throw EBox::Exceptions::DataNotFound(data => 'route', value => $route);
    }
    my $routeKey = $routeKeys[0];
    $route =~ $routeKey;
    # Catch named captures
    my %namedParams = %+;
    return ($routes->{$routeKey}, \%namedParams);
}

# Procedure: route
#
#     Route and call a method based on the routes variable
#
# Parameters:
#
#     sub - Code ref to the sub to call
#
#     params - <Hash::MultiValue> the merged POST/GET parameters and named parameters from path
#
#     body - the decoded data if a JSON is posted
#
#     uploads - <Hash::MultiValue> the uploads which are <Plack::Request::Upload> objects
#
# Returns:
#
#     the result of the cluster configuration
#
sub route
{
    my ($sub, $params, $body, $uploads) = @_;

    my $haMod = EBox::Global->getInstance()->modInstance('ha');
    return $sub->($haMod, $params, $body, $uploads);
}

1;
