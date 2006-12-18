use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use lib '../..';
use EBox::Module;
use EBox::TestStubs qw(fakeEBoxModule);


EBox::TestStubs::activateTestStubs();
fakeEBoxModule(name => 'testMod');
backupDirTest();
createBackupDirTest();
markAsChangedTest();

sub backupDirTest
{
  my $mod = EBox::Global->modInstance('testMod');

  my @cases = (
 	       ['/' => '/testMod.bak'],
	       ['/var/lib/ebox/backups' => '/var/lib/ebox/backups/testMod.bak'],
	       ['/var/lib/ebox/backups/' => '/var/lib/ebox/backups/testMod.bak'],
	       # with repetition:
	       ['/var/lib/ebox/backups/testMod.bak' => '/var/lib/ebox/backups/testMod.bak'],
	       ['/var/lib/ebox/backups/testMod.bak/' => '/var/lib/ebox/backups/testMod.bak'],
	       ['/var/lib/ebox/backups/testMod.bak/testMod.bak' => '/var/lib/ebox/backups/testMod.bak'],
	      );

  foreach my $case_r (@cases) {
    my ($dir, $expectedBackupDir) = @{ $case_r };

    is $mod->backupDir($dir), $expectedBackupDir, "Checking backupDir($dir) eq $expectedBackupDir";
  }
}

sub createBackupDirTest
{
  my $dir = '/tmp/ebox.module.backupdir.test';
  system "rm -rf $dir";
  mkdir $dir;

  my $mod = EBox::Global->modInstance('testMod');

  my @cases = (
	       ["$dir" => "$dir/testMod.bak"],
	       ["$dir" => "$dir/testMod.bak"], # check that can be called two times in a row
	       ["$dir/testMod.bak" => "$dir/testMod.bak"], 
	       ["$dir/testMod.bak/" => "$dir/testMod.bak"], 
	       ["$dir/testMod.bak/testMod.bak" => "$dir/testMod.bak"], 
	      );

  foreach my $case_r (@cases) {
    my ($dir, $expectedBackupDir) = @{ $case_r };

    lives_and( sub { is $mod->_createBackupDir($dir), $expectedBackupDir } , "Testing _createBackupDir($dir)" );
    my $dirExists =  (-d $expectedBackupDir);
    ok $dirExists, "Checking that the backup directory  $dir is in place";
  }

}

sub markAsChangedTest
{
  EBox::TestStubs::setEBoxModule('global' => 'EBox::Global');

  my $global = EBox::Global->getInstance();
  (! $global->modIsChanged('testMod')) or die "Module must not be changed";

  lives_and (

	     sub {  
	       my $mod = $global->modInstance('testMod');
	       $mod->markAsChanged();

	       ok $global->modIsChanged('testMod');
	     },
	     'Module was marked as changed'
	    );
}


1;
