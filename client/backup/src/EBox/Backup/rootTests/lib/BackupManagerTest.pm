# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package BackupManagerTest;

use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Gettext;
use EBox::Config::TestStub;
use EBox::Test;
use EBox::FileSystem;
use Test::More;
use Test::Exception;
use Test::Differences;
use File::Slurp::Tree;

use Readonly;
Readonly::Scalar my $BACKUP_MANAGER_BIN => '/usr/sbin/backup-manager';


sub _useTest : Test(1)
{
  use_ok('EBox::Backup::BackupManager');
}





sub prepareDirs : Test(startup)
{
  my $stubDir = testDir() . '/stubs';
  my $stubBackupDir = $stubDir . '/backup';
  EBox::Config::TestStub::setConfigKeys(tmp => testDir(), stubs => $stubDir );
  my @dirs = (testDir(), archiveDir(), backedUpDir(), $stubDir, $stubBackupDir);
  EBox::FileSystem::cleanDir(@dirs);

  system "cp ../../../../stubs/*.mas $stubBackupDir/";
  die $! if ($? != 0);
}


sub testDir
{
  return '/tmp/ebox-backup-backupmanager';
}


sub archiveDir
{
  return testDir() . '/archive';
}


sub backedUpDir
 {
   return testDir() . '/backedUp';
}


sub backupTest : Test(3)
{
  my %fileTree = (
		  primates => {
			       monos => {
					 macaco => 'jefatura',
					 gibon  => "jefe\njefe",
					},
			    },
		  anelidos => {
			       worm => 'jim',
			      },
		  gorilla => 'koko',
		  
		 );

  spew_tree(backedUpDir(),\%fileTree );


  my @backupParams = (
		       bin            => $BACKUP_MANAGER_BIN,
		       dumpDir        => backedUpDir(),
		       repositoryRoot => archiveDir(),
		       burn           => 0, # deactivate burning of data
		     );
  lives_ok { EBox::Backup::BackupManager::backup(@backupParams)  } "backup() called with params @backupParams";


  EBox::FileSystem::cleanDir(backedUpDir());
  my $lsCommand =  '/bin/ls '  . archiveDir() . '/*.gz';
  my $tarFile =  `$lsCommand`; 
  my $tarCommand =  "tar -x -z -C /  -f$tarFile";
  system $tarCommand;
  is $?, 0, "Checking extraction of the archive with command $tarCommand";

  my $extractedFileTree = slurp_tree(backedUpDir());
  eq_or_diff $extractedFileTree, \%fileTree, 'Checking extracted files';
  
}

1;
