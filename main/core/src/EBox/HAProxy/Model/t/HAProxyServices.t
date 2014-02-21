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

package EBox::HAProxy::Model::HAProxyServices::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::HAProxy;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use EBox::TestStubs;
use Test::MockObject::Extends;
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

sub haproxy_services_use_ok : Test(startup => 1)
{
    use_ok('EBox::HAProxy::Model::HAProxyServices') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;

    my $redis = EBox::Test::RedisMock->new();

    my $haproxy = EBox::HAProxy->_create(redis => $redis);

    $self->{model} = $haproxy->model('HAProxyServices');
    $self->{model} = new Test::MockObject::Extends($self->{model});

    my $model = $self->{model};

    my %modelElems = map { $_->{fieldName} => $_ } @{$model->table()->{'tableDescription'}};
    $self->{modelElems} = \%modelElems;
}

sub test_validate_ssl_port_change :  Test(4)
{
    my ($self) = @_;

    my $model = $self->{model};

    my $row = new EBox::Model::Row(dir => 'foo', confmodule => $model);
    my %values = ('serviceId' => 'id', 'module' => 'mod', 'service' => 'module',
                  'port' => { port_disabled => 1 }, 'defaultPort' => 0,
                  'blockPort' => 0, 'sslPort' => { 'sslPort_number' => 443 },
                  'defaultSSLPort' => 0, 'blockSSLPort' => 0, 'canBeDisabled' => 1);
    foreach my $fn (keys %values) {
        my $type = $self->{modelElems}->{$fn}->clone();
        $type->setValue($values{$fn});
        $row->addElement($type);
    }

    $model->mock('ids', sub { ['a'] });
    $model->mock('row', sub { $row });

    $model->set_false('checkServicePort');
    lives_ok {
        $model->validateSSLPortChange(3443);
    } 'No problem to change to a free port';

    lives_ok {
        $model->validateSSLPortChange(443);
    } 'No problem to change to a non-free port as it is not default SSL';

    $row->elementByName('defaultSSLPort')->setValue(1);
    throws_ok {
        $model->validateSSLPortChange(443);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is DEFAULT SSL';

    $row->elementByName('sslPort')->setValue({'sslPort_disabled' => 1});
    $row->elementByName('port')->setValue({ 'port_number' => 80});
    throws_ok {
        $model->validateSSLPortChange(80);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is plain HTTP';


}

1;


END {
    EBox::HAProxy::Model::HAProxyServices::Test->runtests();
}
