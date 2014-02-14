#!/usr/bin/perl -w
#
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

use warnings;
use strict;

package EBox::HA::Server::Router::Test;

use base 'Test::Class';

use EBox::HA;
use Test::Deep;
use Test::Exception;
use Test::More;

sub test_use_ok : Test(startup => 1)
{
    use_ok('EBox::HA::Server::Router') or die;
}

sub test_route_exist : Test(4)
{
    ok(EBox::HA::Server::Router::routeExists('/cluster/configuration'), 'Simple route exists');
    ok(not (EBox::HA::Server::Router::routeExists('/foobar')), 'Simple route does not exist');
    ok(EBox::HA::Server::Router::routeExists('/cluster/nodes/foo'), 'Complex route exists');
    ok(not (EBox::HA::Server::Router::routeExists('/cluster/nodes/foo_la')), 'Complex route does not match');

}

sub test_route_conf : Test(3)
{
    throws_ok {
        EBox::HA::Server::Router::routeConf('/cluster')
    } 'EBox::Exceptions::DataNotFound', 'Route does not exist';

    my @conf = EBox::HA::Server::Router::routeConf('/cluster/configuration');
    cmp_deeply(\@conf,
              [{'GET' => \&EBox::HA::clusterConfiguration,
                'PUT' => \&EBox::HA::updateClusterConfiguration}, {}
              ], 'Simple route conf');
    @conf = EBox::HA::Server::Router::routeConf('/cluster/nodes/foo');
    cmp_deeply(\@conf,
              [{'DELETE' => \&EBox::HA::deleteNode}, {name => 'foo'}], 'Complex route conf');
}

1;


END {
    EBox::HA::Server::Router::Test->runtests();
}
