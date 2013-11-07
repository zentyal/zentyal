#!/usr/bin/perl -w
#
# Copyright (C) 2013 Zentyal S.L.
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

package EBox::RemoteServices::Reporter::Test;

use base 'Test::Class';

use Test::Exception;
use Test::MockModule;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;


sub use_reporter_ok : Test(startup => 1)
{
    use_ok('EBox::RemoteServices::Reporter') or die;
}


sub set_up_instance : Test(setup)
{
    my ($self) = @_;

    $self->{instance} = EBox::RemoteServices::Reporter->instance();
}


sub test_isa_ok : Test
{
    my ($self) = @_;
    isa_ok($self->{instance}, 'EBox::RemoteServices::Reporter');
}


sub test_consolidate_send: Tests
{
    my ($self) = @_;

    # Create a dummy reporter
    # Register it
    # Make sure no data has been sent through this reporter after trying to consolidate

    my $manager = $self->{instance};
    my $reporterMod = new Test::MockModule('EBox::Reporter::Base');
    my $reporterObj = new Test::MockObject();
    $reporterObj->set_true('enabled');
    $reporterObj->set_always('_beginTime', time());
    $reporterObj->set_false('consolidate');
    $reporterMod->mock('new', $reporterObj);

    ok($manager->register('EBox::Reporter::Base'), 'Register dummy reporter');

    lives_ok {
        $manager->consolidate();
    } 'Consolidate the dummy';

    lives_ok {
        $manager->send();
    } 'Try to send the dummy';

    ok( (not $reporterObj->called('send')), 'Send was not called inside the mocked object');
}

1;

END {
    EBox::RemoteServices::Reporter::Test->runtests();
}
