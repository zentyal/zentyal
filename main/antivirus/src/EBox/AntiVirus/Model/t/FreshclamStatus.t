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

package EBox::AntiVirus::Model::FreshclamStatus::Test;

use parent 'Test::Class';

use EBox::AntiVirus;
use EBox::Exceptions::Internal;
use EBox::Global::TestStub;

use Test::Exception;
use Test::MockObject::Extends;
use Test::MockObject;
use Test::More;

sub set_up_conf : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub mock_clamav_xs : Test(startup)
{
    my $mock = new Test::MockObject();
    $mock->fake_module('ClamAV::XS' => ('signatures' => sub { 100; }));
}

sub test_use_ok : Test(startup => 1)
{
    use_ok('EBox::AntiVirus::Model::FreshclamStatus') or die;
}

sub set_up_instance : Test(setup)
{
    my ($self) = @_;

    my $redis = new EBox::Test::RedisMock();
    $self->{av} = EBox::AntiVirus->_create(redis => $redis);
    $self->{av} = new Test::MockObject::Extends($self->{av});
    $self->{model} = $self->{av}->model('FreshclamStatus');
}

sub unmock_freshclamState : Test(teardown)
{
    my ($self) = @_;
    $self->{av}->unmock('freshclamState');
}

# freshclamState launches an exception
sub test_internal_exc_state : Test(2)
{
    my ($self) = @_;

    $self->{av}->mock('freshclamState', sub { throw EBox::Exceptions::Internal()} );
    my $ret;
    lives_ok {
        $ret = $self->{model}->_content();
    } 'Lives with an exception in freshclamState';
    cmp_ok($ret->{nSignatures}, '==', 0, 'No signatures');
}

sub test_update : Test(4)
{
    my ($self) = @_;

    my $mod = new Test::MockObject::Extends($self->{model});
    $mod->mock('_lastUpdateDate', sub { time() - 10; });
    $mod->{confmodule}->mock('freshclamState', sub { { 'date' => time, 'update' => 1} } );

    my $ret;
    lives_ok {
        $ret = $mod->_content();
    } 'Lives with normal update in freshclamState';
    cmp_ok($ret->{nSignatures}, '==', 100, 'Nice number of signatures');
    cmp_ok($ret->{message}, 'eq', 'Last update successful.', 'Nice message');
    ok($ret->{date}, 'There is date');
}

sub test_outdated : Test(4)
{
    my ($self) = @_;

    my $mod = new Test::MockObject::Extends($self->{model});
    $mod->mock('_lastUpdateDate', sub { time() - 10; });
    $mod->{confmodule}->mock('freshclamState', sub { { 'date' => time, 'update' => 1} } );

    my $ret;
    lives_ok {
        $ret = $mod->_content();
    } 'Lives with an outdated in freshclamState';
    cmp_ok($ret->{nSignatures}, '==', 100, 'Nice number of signatures');
    cmp_ok($ret->{message}, 'eq', 'Last update successful.', 'Nice message');
    ok($ret->{date}, 'There is date');
}

sub test_uninitialised : Test(4)
{
    my ($self) = @_;

    my $mod = new Test::MockObject::Extends($self->{model});
    $mod->mock('_lastUpdateDate', sub { time() - 10; });
    $mod->{confmodule}->mock('freshclamState', sub { { 'date' => undef} } );
    $mod->{confmodule}->set_true('configured', 'isEnabled');

    my $ret;
    lives_ok {
        $ret = $mod->_content();
    } 'Lives but not initialised';
    cmp_ok($ret->{nSignatures}, '==', 100, 'Nice number of signatures');
    cmp_ok($ret->{message}, 'eq', 'The antivirus database has not been updated since the module was enabled.',
           'Uninitialised message');
    ok($ret->{date}, 'There is date');
}

1;

END {
    EBox::AntiVirus::Model::FreshclamStatus::Test->runtests();
}
