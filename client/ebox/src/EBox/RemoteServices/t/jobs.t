#!/usr/bin/perl -w
#
# Copyright (C) 2008 Warp Networks S.L.
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

package main;

use warnings;
use strict;

use EBox;
use Test::More tests => 4;
use Test::Exception;

BEGIN {
    diag('A unit test for EBox::RemoteServices::Jobs');
    use_ok('EBox::RemoteServices::Jobs')
      or die;
}

EBox::init();

my $notifier = new EBox::RemoteServices::Jobs();
isa_ok($notifier, 'EBox::RemoteServices::Jobs');

lives_ok {
    $notifier->jobResult(jobId  => 1,
                         stdout => 'foo',
                         stderr => 'bar',
                         exitValue => 1);
} 'Notifying a job result';

dies_ok {
    $notifier->jobResult(jobid => 1212121,
                         stdout => 'foo',
                         stderr => 'bar',
                         exitValue => 1);
} 'Notifying an inexistent job result';
