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

package EBox::HA::Model::FloatingIP::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::DHCP;
use EBox::HA;
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

sub floating_ip_use_ok : Test(startup => 1)
{
    use_ok('EBox::HA::Model::FloatingIP') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;

    my $redis = EBox::Test::RedisMock->new();

    my $ha = EBox::HA->_create(redis => $redis);

    $self->{model} = $ha->model('FloatingIP');

    my $model = $self->{model};

    my ($nameElement) = grep { $_->{fieldName} eq 'name' } @{$model->table()->{'tableDescription'}};
    $self->{nameElement} = $nameElement;

    my ($floating_ipElement) = grep { $_->{fieldName} eq 'floating_ip' } @{$model->table()->{'tableDescription'}};
    $self->{floating_ipElement} = $floating_ipElement;

}

sub test_validate_row_format_exceptions :  Test(3)
{
    my ($self) = @_;

    my $model = $self->{model};

    $self->{nameElement}->setValue('test-name');
    $self->{floating_ipElement}->setValue('1.1.1.1');

    throws_ok {
        $model->validateTypedRow('add', undef, {
                                    name => $self->{nameElement},
                                    floating_ip => $self->{floating_ipElement}
                                });
    } 'EBox::Exceptions::External', 'Bad name, ilegal characters';


    my $name = "";
    for my $i (1..65) {
        $name = $name . "a";
    }
    $self->{nameElement}->setValue($name);
    $self->{floating_ipElement}->setValue('1.1.1.1');

    throws_ok {
        $model->validateTypedRow('add', undef, {
                                    name => $self->{nameElement},
                                    floating_ip => $self->{floating_ipElement}
                                });
    } 'EBox::Exceptions::External', 'Bad name, it is too long';


    $self->{nameElement}->setValue('1234');
    $self->{floating_ipElement}->setValue('1.1.1.1');

    throws_ok {
        $model->validateTypedRow('add', undef, {
                                    name => $self->{nameElement},
                                    floating_ip => $self->{floating_ipElement}
                                });
    } 'EBox::Exceptions::External', 'Bad name, it is too short';
}

sub test_validate_row_collision_exceptions : Test(5)
{
    my ($self) = @_;

    my $model = $self->{model};

    my $fakeNetworkIPs = [{
            'netmask' => '255.255.255.0',
            'address' => '1.1.1.69',
            'name'    => 'viface1'
        }];
    my $fakeFixedAddresses = [{
            'ip' => '1.1.1.70',
            'name' => 'cow',
            'mac' => 'C0:C1:C0:12:E7:1C'
        }];
    my $fakeRanges = [{
        'name' => 'testRange',
        'from' => '1.1.1.95',
        'to'   => '1.1.1.105'}];

    EBox::TestStubs::fakeModule(
            name => 'network',
            subs => [
                'allIfaces'      => sub { [ 'eth0' ] },
                'InternalIfaces' => sub { [ 'eth0' ] },
                'ExternalIfaces' => sub { [] },
                'ifaceAddresses' => sub { return $fakeNetworkIPs; },
                'ifaceMethod' => sub { return 'static'; },
                'netInitRange' => sub { return '1.1.1.1'; },
                'netEndRange' => sub { return '1.1.1.200'; }
            ]);

    EBox::TestStubs::fakeModule(
            name => 'dhcp',
            subs => [
                'fixedAddresses' => sub { return $fakeFixedAddresses; },
                'isEnabled' => sub { return 1; },
                '_getModel' => sub {return $self->{dhcpModel}; },
                'ranges'    => sub { return $fakeRanges; },
            ]);

    $self->{nameElement}->setValue('testIP');
    $self->{floating_ipElement}->setValue('1.1.1.69');

    throws_ok {
        $model->validateTypedRow('add', undef, {
                                    name => $self->{nameElement},
                                    floating_ip => $self->{floating_ipElement}
                                });
    } 'EBox::Exceptions::External', 'IP collides with interface IP';

    $self->{nameElement}->setValue('testIP');
    $self->{floating_ipElement}->setValue('1.1.1.70');

    throws_ok {
        $model->validateTypedRow('add', undef, {
                                    name => $self->{nameElement},
                                    floating_ip => $self->{floating_ipElement}
                                });
    } 'EBox::Exceptions::External', 'IP collides with DHCP fixed address';


    $self->{nameElement}->setValue('testIP');
    $self->{floating_ipElement}->setValue('1.1.1.100');

    throws_ok {
        $model->validateTypedRow('add', undef, {
            name => $self->{nameElement},
            floating_ip => $self->{floating_ipElement}
           });
    } 'EBox::Exceptions::External', 'IP collides with DHCP ranges';

    $self->{nameElement}->setValue('testIP');
    $self->{floating_ipElement}->setValue('1.1.1.210');
    throws_ok {
        $model->validateTypedRow('add', undef, {
            name => $self->{nameElement},
            floating_ip => $self->{floating_ipElement}
           });
    } 'EBox::Exceptions::External', 'Floating IP does not belong to network iface';

    $self->{nameElement}->setValue('AddedFloating');
    $self->{floating_ipElement}->setValue('1.1.1.199');
    lives_ok{
        $model->validateTypedRow('add', undef, {
            name => $self->{nameElement},
            floating_ip => $self->{floating_ipElement}
            });
    } 'Floating IP added correctly';
}

1;


END {
    EBox::HA::Model::FloatingIP::Test->runtests();
}
