#!/usr/bin/perl -w

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

# A module to test EBox::Event::Dispatcher::Mail module

use Test::More tests => 4;
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use lib ('../../../..', '../../../../../../../common/libebox/src');

use EBox;
use EBox::Event;
use EBox::Global;

BEGIN {
    diag ( 'Starting EBox::Event::Dispatcher::Mail test' );
    use_ok ( 'EBox::Event::Dispatcher::Mail' )
      or die;
}

EBox::init();

my $mailDispatcher;
my $event;
lives_ok {
    $mailDispatcher = new EBox::Event::Dispatcher::Mail();
    $event = new EBox::Event(
                             message => 'test event',
                             level   => 'info',
                            );
} 'Creating the mail dispatcher and the event to send';

lives_ok {
    $mailDispatcher->enable()
} 'Enabling the mail dispatcher';

ok ( $mailDispatcher->send($event),
     'Sending test event to the admin');

1;

