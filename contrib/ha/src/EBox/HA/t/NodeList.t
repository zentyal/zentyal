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

package EBox::HA::NodeList::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::HA;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use Test::Deep;
use Test::Exception;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub nodelist_use_ok : Test(startup => 1)
{
    use_ok('EBox::HA::NodeList') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    my $ha = EBox::HA->_create(redis => $redis);
    $self->{nodeList} = new EBox::HA::NodeList($ha);
}

sub test_isa_ok  : Test
{
    my ($self) = @_;
    isa_ok($self->{nodeList}, 'EBox::HA::NodeList');
}

sub test_set : Test(9)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    cmp_deeply($nl->list(), [], 'list is empty');
    lives_ok {
        $nl->set(addr => '10.1.1.1', name => 'a', port => 443);
    } 'Add a new node';
    cmp_deeply($nl->list(),
               [{addr => '10.1.1.1', name => 'a', port => 443, localNode => 0, nodeid => 1}],
               'list has this member');
    lives_ok {
        $nl->set(addr => '10.1.1.3', name => 'b', port => 443);
    } 'Adding another node';
    cmp_deeply($nl->list(),
               bag(
        {addr => '10.1.1.1', name => 'a', port => 443, localNode => 0, nodeid => 1 },
        {addr => '10.1.1.3', name => 'b', port => 443, localNode => 0, nodeid => 2 }
       ),
               'list has this member');
    lives_ok {
        $nl->set(addr => '10.1.1.2', name => 'a', port => 443, localNode => 1);
    } 'Update a node';
    cmp_deeply($nl->list(),
               bag(
      {addr => '10.1.1.2', name => 'a', port => 443, localNode => 1, nodeid => 1 },
      {addr => '10.1.1.3', name => 'b', port => 443, localNode => 0, nodeid => 2 }
     ),
               'list has an updated member');
    lives_ok {
        $nl->set(addr => '10.1.1.5', name => 'c', port => 443, nodeid => 23);
    } 'Set a node with id';
    cmp_deeply($nl->list(),
               bag(
      {addr => '10.1.1.2', name => 'a', port => 443, localNode => 1, nodeid => 1 },
      {addr => '10.1.1.3', name => 'b', port => 443, localNode => 0, nodeid => 2 },
      {addr => '10.1.1.5', name => 'c', port => 443, localNode => 0, nodeid => 23}
     ),
               'list has a new member with custom nodeid');
}

sub test_remove : Test(6)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    cmp_deeply($nl->list(), [], 'list is empty');
    throws_ok {
        $nl->remove('a');
    } 'EBox::Exceptions::DataNotFound', 'Remove a non-existing node';
    lives_ok {
        $nl->set(addr => '10.1.1.2', name => 'a', port => 443);
    } 'Add a new node';
    lives_ok {
       $nl->remove('a');
    } 'Remove a valid node';
    throws_ok {
        $nl->remove('a');
    } 'EBox::Exceptions::DataNotFound', 'Remove an already removed node';
    cmp_deeply($nl->list(), [], 'list is empty again');
}

sub test_empty : Test(3)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    cmp_ok($nl->empty(), '==', 0);
    $nl->set(addr => '10.1.1.2', name => 'a', port => 443);
    cmp_ok($nl->empty(), '==', 1);
    cmp_deeply($nl->list(), [], 'list is empty');
}

sub test_node : Test(2)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    throws_ok {
        $nl->node('foobar');
    } 'EBox::Exceptions::DataNotFound', 'Node not found in empty list';
    $nl->set(addr => '10.1.1.2', name => 'a', port => 443);
    cmp_deeply($nl->node('a'),
               {addr => '10.1.1.2', name => 'a', port => 443, localNode => 0,
                nodeid => 1}, 'Node found');
    $nl->empty();

}

sub test_local_node : Test(3)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    throws_ok {
        $nl->localNode()
    } 'EBox::Exceptions::DataNotFound', 'Not local node in an empty list';
    $nl->set(addr => '10.1.1.2', name => 'a', port => 443);
    throws_ok {
        $nl->localNode()
    } 'EBox::Exceptions::DataNotFound', 'Not local node in a non-empty list';
    $nl->set(addr => '10.1.1.4', name => 'ab', port => 443, localNode => 1);
    cmp_deeply($nl->localNode(),
               { addr => '10.1.1.4', name => 'ab', port => 443, localNode => 1,
                 nodeid => 2 });
    $nl->empty()
}

sub test_diff : Test(7)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    $nl->empty();

    throws_ok {
        $nl->diff();
    } 'EBox::Exceptions::InvalidType', 'Invalid diff data';

    cmp_ok(($nl->diff([]))[0], '==', 1, 'No differences in empty list');
    my @diff = $nl->diff([{name => 'jetplane-landing'}]);
    cmp_deeply(\@diff, [0, {new => ['jetplane-landing'], old => [], changed => []}],
               'New node in arriving list');

    $nl->set(addr => '10.1.1.4', name => 'ab', port => 443, localNode => 1);
    @diff = $nl->diff([]);
    cmp_deeply(\@diff, [0, {new => [], old => ['ab'], changed => []}],
               'Old node in removed list');

    @diff = $nl->diff([{addr => '10.1.1.4', name => 'ab', port => 443, localNode => 1, nodeid => 1}]);
    cmp_ok($diff[0], '==', 1, 'localNode attr is ignored');

    @diff = $nl->diff([{addr => '10.1.1.44', name => 'ab', port => 443, localNode => 1, nodeid => 1}]);
    cmp_deeply(\@diff, [0, {new => [], old => [], changed => ['ab']}],
               'Changed on node addr attribute');

    # Testing all together
    $nl->set(addr => '10.1.1.232', name => 'old', port => 443, localNode => 1);
    @diff = $nl->diff([{addr => '10.1.1.44', name => 'ab', port => 443, localNode => 1, nodeid => 1},
                       {addr => '10.1.1.1', name => 'new', port => 443, localNode => 0, nodeid => 3}]);
    cmp_deeply(\@diff, [0, {new => ['new'], old => ['old'], changed => ['ab']}],
               'Testing all together');
    $nl->empty();
}

sub test_size : Test(4)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    $nl->empty();
    cmp_ok($nl->size(), '==', 0, 'Empty list equals to 0');
    $nl->set(addr => '10.1.1.2', name => 'graham', port => 443, localNode => 1);
    cmp_ok($nl->size(), '==', 1, 'A list with 1 element');
    $nl->set(addr => '10.1.1.3', name => 'coxon', port => 443, localNode => 0);
    cmp_ok($nl->size(), '==', 2, 'A list with 2 elements');
    $nl->remove('coxon');
    cmp_ok($nl->size(), '==', 1, 'A list after removal');
    $nl->empty();
}

1;

END {
    EBox::HA::NodeList::Test->runtests();
}
