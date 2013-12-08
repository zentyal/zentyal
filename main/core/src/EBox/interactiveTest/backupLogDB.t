#!/usr/bin/perl
# Copyright (C) 2010-2011 Zentyal S.L.
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

use EBox;
use EBox::PgDBEngine;


my %args = map { $_ => 1 } @ARGV;

my $backup;
my $restore;

if ($args{'-b'}) {
    $backup = 1;
} elsif ($args {'-r'}) {
    $restore = 1;
} else {
    die 'no operation mode';
}

my $basic = $args{'--basic'};
my $cleanSlices = $args{'--clean-slices'};
my $slicedMode = $basic ? 0 : 1;

EBox::init();


my $dir = '/tmp/testdb';
(-d $dir) or mkdir $dir;


my $basename = 'test';

my $dbengine = EBox::PgDBEngine->new();


if ($backup) {
    system "rm -rf $dir/*";
    if ($cleanSlices) {
        $dbengine->do('TRUNCATE TABLE backup_slices');
        print "Slice table truncated\n";
    }

    $dbengine->backupDB($dir, $basename, slicedMode => $slicedMode);

} elsif ($restore) {
    $dbengine->restoreDB($dir, $basename, slicedMode => $slicedMode);
}else {
    die 'no reached';
}

1;
