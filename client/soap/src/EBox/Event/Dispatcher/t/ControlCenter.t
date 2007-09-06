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

# A unit test for the Control Center dispatcher. It can only be tested
# when the connection between CC and eBox.

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox;
use EBox::Global;
use EBox::Event;

use lib '../../../..';

BEGIN {
  use_ok ( 'EBox::Event::Dispatcher::ControlCenter' )
    or die;
}

EBox::init();

my $ca = EBox::Global->modInstance('ca');
my $eBoxCN = $ca->eBoxCN();

my ($dispatcher, $event);
lives_ok { $dispatcher = new EBox::Event::Dispatcher::ControlCenter() }
  'Creating Control Center dispatcher';

lives_ok { $event = new EBox::Event( message => 'An example event',
                                     level   => 'info',
                                     dispatchTo => 'ControlCenter',
                                   );
       } 'Creating an event';

ok ( $dispatcher->send($eBoxCN, $event), 'Sending event to the control center');
