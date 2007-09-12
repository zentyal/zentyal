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

# A module to test Event::Dispatcher::Jabber module

use Test::More qw (no_plan);
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use lib ('../../../..', '../../../../../../../common/libebox/src');

use EBox;
use EBox::Event;
use EBox::Global;

diag ( 'Starting EBox::Event::Dispatcher::Jabber test' );

BEGIN {
  use_ok ( 'EBox::Event::Dispatcher::Jabber' )
    or die;
}

my $jabberDispatcher;
my $event;
lives_ok
  {
      $jabberDispatcher = new EBox::Event::Dispatcher::Jabber();
      $event = new EBox::Event(
                               message => 'test event',
                               level   => 'info',
                              );
  } 'Creating the jabber dispatcher and the event to send';

lives_ok
  {
      $jabberDispatcher->enable()
  } 'Enabling the jabber dispatcher';

ok ( $jabberDispatcher->send($event),
     'Sending test event to the admin');

1;

