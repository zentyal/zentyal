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

use EBox::Global;
use EBox::HA;

# Package: EBox::HA::Server::Router
#
#   Router in the middle of the PSGI app and the HA module
#

our $routes = {
    '/cluster/configuration' => { 'GET' => \&EBox::HA::clusterConfiguration },
    '/cluster/nodes'         => { 'GET'    => \&EBox::HA::nodes,
                                  'POST'   => \&EBox::HA::addNode,
                                  'DELETE' => \&EBox::HA::deleteNode },
    '/conf/replication' => { 'GET' => \&EBox::HA::confReplicationStatus,
                             'POST' => \&EBox::HA::replicateConf },
};

# Procedure: route
#
#     Route and call a method based on the routes variable
#
# Parameters:
#
#     sub - Code ref to the sub to call
#
#     params - <Hash::MultiValue> the merged POST/GET parameters
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

    my $haMod = EBox::Global->getInstance(1)->modInstance('ha');
    return $sub->($haMod, $params, $body, $uploads);
}

1;
