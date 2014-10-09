#!/usr/bin/perl -w

# Copyright (C) 2012-2014 Zentyal S.L.
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

# A module to test the <EBox::RemoteServices::Subscription::Check> class

use strict;
use warnings;

package EBox::RemoteServices::Subscription::Check::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::TestStubs;
use Test::MockModule;
use Test::MockObject;
use Test::More;

BEGIN {
    diag('A unit test for EBox::RemoteServices::Subscription::Check');
}

my $pop = 0;
my $push = 0;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub use_module_ok : Test(startup => 1)
{
    use_ok('EBox::RemoteServices::Subscription::Check')
      or die;
}

sub get_checker : Test(setup)
{
    my ($self) = @_;
    $self->{checker} = new EBox::RemoteServices::Subscription::Check();
    $self->{det} = {
        basic => { features => { serverusers => { max => undef }}},
        prof => { features => { serverusers => { max => 25 }}},
        busi => { features => { serverusers => { max => 75 }}},
        prem => { features => { serverusers => { max => 300 }}}}
}

sub mock_rs : Test(setup)
{
    EBox::TestStubs::fakeModule(
        name => 'remoteservices',
        subs => [ 'pushAdMessage' => sub { $push++; },
                  'popAdMessage' => sub { $pop++; },
                  'i18nServerEdition' => sub { '' } ]);
}

sub test_use_ok: Test
{
    my ($self) = @_;
    isa_ok($self->{checker}, 'EBox::RemoteServices::Subscription::Check');
}

sub test_no_users: Test(2)
{
    my ($self) = @_;
    cmp_ok($self->{checker}->check($self->{det}->{prof}), '==', 1,
           'No problem without users module');

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 0; } ]);

    cmp_ok($self->{checker}->check($self->{det}->{prof}), '==', 1,
           'No problem without disabled users module');
}

sub test_no_limit: Test(2)
{
    my ($self) = @_;

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 240]; }]);

    my $nPops = $pop;
    cmp_ok($self->{checker}->check($self->{det}->{basic}), '==', 1,
           'Basic community has no problems');
    cmp_ok($pop, '>', $nPops, 'popAdMessage was called');
}

sub test_prof: Test(4)
{
    my ($self) = @_;

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 240]; } ]);

    my $nPops = $pop;
    my $nPushes = $push;
    cmp_ok($self->{checker}->check($self->{det}->{prof}), '==', 1,
           'Professional has a warning');
    cmp_ok($push, '>', $nPushes, 'pushAdMessage was called');

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 20] } ]);
    cmp_ok($self->{checker}->check($self->{det}->{prof}), '==', 1,
           'Professional has no warning');
    cmp_ok($pop, '>', $nPops, 'popAdMessage was called');
}

sub test_busi: Test(4)
{
    my ($self) = @_;

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 240]; } ]);

    my $nPops = $pop;
    my $nPushes = $push;
    cmp_ok($self->{checker}->check($self->{det}->{busi}), '==', 1,
           'Business has a warning');
    cmp_ok($push, '>', $nPushes, 'pushAdMessage was called');

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 50]; } ]);
    cmp_ok($self->{checker}->check($self->{det}->{busi}), '==', 1,
           'Business has no warning');
    cmp_ok($pop, '>', $nPops, 'popAdMessage was called');

}

sub test_prem: Test(4)
{
    my ($self) = @_;

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 440]; } ]);

    my $nPops = $pop;
    my $nPushes = $push;
    cmp_ok($self->{checker}->check($self->{det}->{prem}), '==', 1,
           'Premium has a warning');
    cmp_ok($push, '>', $nPushes, 'pushAdMessage was called');

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 140]; } ]);
    cmp_ok($self->{checker}->check($self->{det}->{prem}), '==', 1,
           'Premium has no warning');
    cmp_ok($pop, '>', $nPops, 'popAdMessage was called');
}

1;

END {
    EBox::RemoteServices::Subscription::Check::Test->runtests();
}
