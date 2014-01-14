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

sub test_set : Test(5)
{
    my ($self) = @_;

    my $nl = $self->{nodeList};
    cmp_deeply($nl->list(), [], 'list is empty');
    lives_ok {
        $nl->set(addr => '10.1.1.1', name => 'a', webAdminPort => 443);
    } 'Add a new node';
    cmp_deeply($nl->list(), [{addr => '10.1.1.1', name => 'a', webAdminPort => 443, localNode => 0}],
               'list has this member');
    lives_ok {
        $nl->set(addr => '10.1.1.2', name => 'a', webAdminPort => 443, localNode => 1);
    } 'Update a node';
    cmp_deeply($nl->list(), [{addr => '10.1.1.2', name => 'a', webAdminPort => 443, localNode => 1}],
             'list has an updated member');
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
        $nl->set(addr => '10.1.1.2', name => 'a', webAdminPort => 443);
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
    $nl->set(addr => '10.1.1.2', name => 'a', webAdminPort => 443);
    cmp_ok($nl->empty(), '==', 1);
    cmp_deeply($nl->list(), [], 'list is empty');
}

1;


END {
    EBox::HA::NodeList::Test->runtests();
}
