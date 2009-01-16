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

###############
# Dependencies
###############
use EBox::Gettext;
use File::Slurp;
use Data::Dumper;
use English "-no_match_vars";

use EBox::RemoteServices::Backup;


use EBox;

EBox::init();


my $backupServ = EBox::RemoteServices::Backup->new();

my $content = "a" x 1200;
print 'Sending a configuration backup... ';
$backupServ->soapCall('pushConfBackup', $content, 'backupA', 'A conf backup');
print "[Done]$RS";
print 'Getting the all meta configuration... ';
my $all = $backupServ->soapCall('pullAllMetaConfBackup');
print "[Done] $all $RS";
print 'Getting all.info footprint';
my $footprint = $backupServ->soapCall('pullFootprintMetaConf');
print "[Done] $footprint$RS";
print 'Getting the stored conf backup... ';
my $newContent = $backupServ->soapCall('pullConfBackup', 'backupA');
print "[Done]$RS";
print 'Remove the uploaded conf backup... ';
$backupServ->soapCall('removeConfBackup', 'backupA');
print "[Done]$RS";

1;
