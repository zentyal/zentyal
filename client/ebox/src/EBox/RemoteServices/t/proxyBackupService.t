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

use EBox::RemoteServices::ProxyBackup;
use EBox::Global;
use EBox;

use Test::More tests => 2;
use Error qw(:try);

use constant {
  USER => 'warp',
  PASSWORD => 'warp',
};

EBox::init();

my $backupServ = EBox::RemoteServices::ProxyBackup->new(user => USER,
                                                        password => PASSWORD);

my $backupList;

livesOk( 
	sub {  $backupList = $backupServ->listRemoteBackups(); },
	'listing remote backups'
       );

# we pick a backup to restore
my ($canonicalName) = keys %{ $backupList  };
my ($fileName)      = keys %{ $backupList->{$canonicalName} };

livesOk(
	sub {  $backupServ->restoreRemoteBackup($canonicalName, $fileName)  },
	"Restoring backup $fileName backed up by machine $canonicalName"
       );


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
