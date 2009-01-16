#!/usr/bin/perl -w
#
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
use EBox::Global;
use EBox;

use Test::More tests => 12;
use Error qw(:try);

EBox::init();



my $backupServ = EBox::RemoteServices::Backup->new();


my $name = 'remoteBackupName';
my $name2 = 'remoteBackupName2';

livesOk( 
	sub { $backupServ->makeRemoteBackup($name); }, 
	'Making remote backup'
       );


livesOk( 
	sub { $backupServ->makeRemoteBackup($name2); }, 
	'Making a second remote backup'
       );

my $backupList;


foreach (0 .. 1) {
  diag ' we execute the following two tests  two times in a rowto force to use the cached results';
  livesOk( 
	  sub {  $backupList = $backupServ->listRemoteBackups(); },
	  'listing remote backups'
	 );
  
  
  
  
  diag "Backup list " . Dumper $backupList;
  
  my $bothExists = (exists $backupList->{$name}) and (exists $backupList->{$name2});
  ok $bothExists, 'Checking if the backups are in the backup list';
}




livesOk( 
	sub { $backupServ->restoreRemoteBackup($name);},
	 'Restoring remote backup'
       );




livesOk(
	sub {  $backupServ->removeRemoteBackup($name) },
	'Removing remote backup'
       );


livesOk( 
	sub {  $backupList = $backupServ->listRemoteBackups(); },
	'listing remote backups after removal'
       );


diag "Backup list after removal " . Dumper $backupList;

my $oneExists = (not exists $backupList->{$name}) and (exists $backupList->{$name2});
ok $oneExists, 'Checking if the backup is removed from the list';



my $downloadedArchive;
livesOk( 
	sub {  $downloadedArchive = $backupServ->downloadRemoteBackup($name2); },
	'download a remote backup'
       );


my $archiveExists = (-r $downloadedArchive);
ok $archiveExists, 'Checking wether a backup archive was downloaded';



my $global = EBox::Global->modInstance('global');
$global->saveAllModules();


sub livesOk
{
  my ($sub_r, $testName) = @_;

  try {
    $sub_r->();
    pass $testName;
  }
  otherwise {
    my $ex = shift;
    diag "$ex";
    fail $testName;
  };
      

}


1;
