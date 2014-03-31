#!/usr/bin/perl -w

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

#################################################
# A script to test ConfigureWatchers model
#################################################

use Test::More skip_all => 'FIXME';
use Test::More tests => 6;
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox::Global::TestStub;

use lib '../../../..';

diag ('Starting EBox::Events::Model::ConfigureWatchers');

BEGIN {
    use_ok ('EBox::Events::Model::ConfigureWatchers') or die;
}

EBox::Global::TestStub::fake();

my $events;
lives_ok {
    my $gl = EBox::Global->getInstance();
    $events = $gl->modInstance('events')
} 'Getting events ebox module';

my $model;
lives_ok {
    $model = $events->model('ConfigureWatchers');
} 'Getting the event watcher model';

isa_ok ($model, 'EBox::Events::Model::ConfigureWatchers',
        'Getting the appropiate model');

my $oldRow;
lives_ok {
    my $rowIds = $model->ids();
    $oldRow = $model->row($rowIds->[0]);
} 'Getting old row';

lives_ok {
    $model->setRow(
        id => $oldRow->{id},
        eventWatcher => $oldRow->{valueHash}->{eventWatcher}->{value},
        description  => undef,
        enabled      => ! ($oldRow->{valueHash}->{enabled}->{value}),
    );
} 'Changing the enabled status';

