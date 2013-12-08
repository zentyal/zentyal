# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::ProgressIndicator::Test;

use base 'EBox::Test::Class';

use Test::Exception;
use Test::More;
use Test::MockObject;

use lib '../..';
use EBox::TestStubs;
use EBox::ProgressIndicator;

sub _fakeModules : Test(startup)
{
    EBox::TestStubs::fakeModule(
            name => 'apache',
            class => 'EBox::WebAdmin',
    );
    Test::MockObject->fake_module(
            'EBox::ProgressIndicator',
            _fork => sub {   },
    );
}

sub creationAndRetrieveTest : Test(4)
{
    my $progress;
    lives_ok {
        $progress = EBox::ProgressIndicator->create(
                totalTicks => 4,
                executable => '/bin/ls',
                );
    } 'creating progress indicator';

    my $id = $progress->id;
    my $progress2;
    lives_ok {
        $progress2 = EBox::ProgressIndicator->retrieve($id);
    } 'retrieve the same progress indicator';

    my %progressAttrs;
    my %progress2Attrs;
    foreach (qw(id ticks totalTicks started)) {
        $progressAttrs{$_} = $progress->$_;
        $progress2Attrs{$_} = $progress2->$_;
    }

    is_deeply \%progressAttrs, \%progress2Attrs, 'Checking that the two objects are equivalent';

    lives_ok   {  $progress->destroy() } 'destroy progress indicator';
}

sub basicUseCaseTest : Test(13)
{
    my $totalTicks = 4;
    my $progress = EBox::ProgressIndicator->create(
            totalTicks => $totalTicks,
            executable => '/bin/ls',
    );

    ok (not $progress->started), 'Checking started propierty after creation of the indicator';
    ok (not $progress->finished), 'Checking finished propierty after creation of the indicator';
    lives_ok {
        $progress->runExecutable();
    } 'run executable';

    ok $progress->started, 'Checking started propierty after runExecutable';
    ok (not $progress->finished), 'Checking finished propierty after runExecutable';

    my $i = 1;
    while ($i <= $totalTicks) {
        $progress->notifyTick();
        is $progress->ticks(), $i, 'checking tick count';
        $i++;
    }

    ok $progress->started, 'Checking started propierty after notify all the ticks';
    ok (not $progress->finished), 'Checking finished propierty after notify all the ticks';

    $progress->setAsFinished();

    ok $progress->finished(), 'checking wether object is marked as finished after marked as finished';
    ok $progress->started, 'Checking started propierty after object is marked as finished';
}

1;
