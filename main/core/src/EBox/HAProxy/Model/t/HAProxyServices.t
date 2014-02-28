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

use EBox::Exceptions::External;
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

sub test_validate_ports_change :  Test(9)
{
    my ($self) = @_;

    my $model = $self->{model};

    my $row = new EBox::Model::Row(dir => 'foo', confmodule => $model);
    my %values = ('serviceId' => 'id', 'module' => 'mod', 'service' => 'module',
                  'port' => { port_number => 80 }, 'defaultPort' => 0,
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
    throws_ok {
        $model->validatePortsChange(80, 80, 'changedService');
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is DEFAULT';

    lives_ok {
        $model->validatePortsChange(8080, 443, 'changedService');
    } 'No problem to change to a free port for http and https';

    lives_ok {
        $model->validatePortsChange(80, 443, 'changedService');
    } 'No problem to change to a non-free port as it is not default';

    $row->elementByName('defaultPort')->setValue(1);
    $row->elementByName('defaultSSLPort')->setValue(1);
    lives_ok {
        $model->validatePortsChange(80, 443, 'changedService');
    } 'No problem to change to a non-free port even if there is already a default one because it is not DEFAULT';

    throws_ok {
        $model->validatePortsChange(80, 443, 'changedService', 1, 1);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is DEFAULT';

    lives_ok {
        $model->validatePortsChange(80, 443, 'id', 1, 1);
    } 'No problem if we call validation for the same service and port and being default';

    lives_ok {
        $model->validatePortsChange(undef, 80, 'id', 0, 0);
    } 'No problem if we call validation for HTTPS using a previous value of HTTP';

    # Simulate a collision with an outsider service.
    $model->mock('checkServicePort', sub { throw EBox::Exceptions::External(); });
    lives_ok {
        $model->validatePortsChange(80, 443, 'changedService', 0, 0, 1);
    } 'No problem if we pass the force flag and checkServicePort returns true';
    throws_ok {
        $model->validatePortsChange(80, 443, 'changedService', 0, 0, 0);
    } 'EBox::Exceptions::External', 'Problem to change a port when checkServicePort is not forced';
}

sub test_validate_http_port_change :  Test(6)
{
    my ($self) = @_;

    my $model = $self->{model};

    my $row = new EBox::Model::Row(dir => 'foo', confmodule => $model);
    my %values = ('serviceId' => 'id', 'module' => 'mod', 'service' => 'module',
                  'port' => { port_number => 80 }, 'defaultPort' => 0,
                  'blockPort' => 0, 'sslPort' => { 'sslPort_disabled' => 1 },
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
        $model->validateHTTPPortChange(8080, 'changedService', 0);
    } 'No problem to change to a free port';

    lives_ok {
        $model->validateHTTPPortChange(80, 'changedService', 0);
    } 'No problem to change to a non-free port as it is not default';

    $row->elementByName('defaultPort')->setValue(1);
    lives_ok {
        $model->validateHTTPPortChange(80, 'changedService', 0);
    } 'No problem to change to a non-free port even if there is already a default one because it is not DEFAULT';

    throws_ok {
        $model->validateHTTPPortChange(80, 'changedService', 1);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is DEFAULT';

    lives_ok {
        $model->validateHTTPPortChange(80, 'id', 1);
    } 'No problem if we call validation for the same service and port and being default';

    $row->elementByName('port')->setValue({'port_disabled' => 1});
    $row->elementByName('sslPort')->setValue({ 'sslPort_number' => 80});
    throws_ok {
        $model->validateHTTPPortChange(80, 'changedService', 0);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is HTTPS';


}

sub test_validate_https_port_change :  Test(6)
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
        $model->validateHTTPSPortChange(3443, 'changedService', 0);
    } 'No problem to change to a free port';

    lives_ok {
        $model->validateHTTPSPortChange(443, 'changedService', 0);
    } 'No problem to change to a non-free port as it is not default SSL';

    $row->elementByName('defaultSSLPort')->setValue(1);
    lives_ok {
        $model->validateHTTPSPortChange(443, 'changedService', 0);
    } 'No problem to change to a non-free port even if there is already a default one because it is not DEFAULT SSL';

    throws_ok {
        $model->validateHTTPSPortChange(443, 'changedService', 1);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is DEFAULT SSL';

    lives_ok {
        $model->validateHTTPSPortChange(443, 'id', 1);
    } 'No problem if we call validation for the same service and port and being default ssl';

    $row->elementByName('sslPort')->setValue({'sslPort_disabled' => 1});
    $row->elementByName('port')->setValue({ 'port_number' => 80});
    throws_ok {
        $model->validateHTTPSPortChange(80, 'changedService', 0);
    } 'EBox::Exceptions::External', 'Problem to change to a non-free port as it is plain HTTP';
}

1;

END {
    EBox::HAProxy::Model::HAProxyServices::Test->runtests();
}
