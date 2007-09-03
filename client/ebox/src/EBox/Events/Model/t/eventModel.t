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

#################################################
# A script to test ConfigureEventDataTable model
#################################################

use Test::More tests => 6;
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox::Global;
use EBox;

use lib '../../../..';

diag ( 'Starting EBox::Events::Model::ConfigureEventDataTable');

BEGIN {
    use_ok ('EBox::Events::Model::ConfigureEventDataTable')
      or die;
}

EBox::init();

my $events;
lives_ok
  {
    my $gl = EBox::Global->getInstance();
    $events = $gl->modInstance('events')
  } 'Getting events ebox module';

my $model;
lives_ok
  {
      $model = $events->configureEventModel()
  } 'Getting the event watcher model';

isa_ok ( $model, 'EBox::Events::Model::ConfigureEventDataTable', 
         'Getting the appropiate model');

my $oldRow;
lives_ok
  {
      my $rowsRef = $model->rows();
      $oldRow = $rowsRef->[0];
  } 'Getting old row';

lives_ok
  {
      $model->setRow( id => $oldRow->{id},
                      eventWatcher => $oldRow->{valueHash}->{eventWatcher}->{value},
                      description  => undef,
                      enabled      => ! ($oldRow->{valueHash}->{enabled}->{value}),
                    );
  } 'Setting the anti one enabled';

