# Copyright (C) 2007 Warp Networks S.L.
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

# Unit test to check the events API exposition

use strict;
use warnings;

use lib '../..';

use Test::More qw(no_plan);
use Test::Exception;
use EBox::Global;
use EBox;


BEGIN {
    diag ( 'Starting events exposed API test unit' );
    use_ok( 'EBox::Events' );
}

EBox::init();

my $events = EBox::Global->modInstance('events');
isa_ok( $events, 'EBox::Events');

lives_ok {
    $events->enableDispatcher('EBox::Event::Dispatcher::Jabber', 0);
} 'Disabling jabber dispatcher';

ok( ! $events->isEnabledDispatcher('EBox::Event::Dispatcher::Jabber')->value(),
    'Disable jabber dispatcher done');

lives_ok {
    $events->enableDispatcher('EBox::Event::Dispatcher::Log', 1);
} 'Enabling log dispatcher';

ok( $events->isEnabledDispatcher('EBox::Event::Dispatcher::Log')->value(),
    'Enable log dispatcher done');

lives_ok {
    $events->enableWatcher('EBox::Event::Watcher::Runit', 0);
} 'Disabling runit watcher';

ok( ! $events->isEnabledWatcher('EBox::Event::Watcher::Runit')->value(),
    'Disable runit watcher done');

lives_ok {
    $events->enableWatcher('EBox::Event::Watcher::State', 1);
} 'Enabling state watcher';

ok( $events->isEnabledWatcher('EBox::Event::Watcher::State')->value(),
    'Enable state watcher done');

1;
