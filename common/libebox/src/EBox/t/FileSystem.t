package main;
# Description:
use strict;
use warnings;

use Test::More tests => 21;
use Test::Exception;
use Test::File;
use Fatal qw(mkdir);

use lib '../..';

use_ok('EBox::FileSystem');

makePrivateDirTest();
cleanDirTest();

sub makePrivateDirTest
{
  dies_ok { EBox::FileSystem::makePrivateDir($0)  } 'Test for error when trying to create a private dir over a file';
  dies_ok { EBox::FileSystem::makePrivateDir('/home')  } 'Test for error when trying to create a private dir over a existent no private dir';

  my $dir ='/tmp/ebox.test.filesystem';
  system "rm -rf $dir";
  die $! if ($? != 0);

  mkdir ($dir, 0700);
  lives_ok {EBox::FileSystem::makePrivateDir($dir)  } 'Test for success when called upon a existent private dir';

  system "rm -rf $dir";
  die $! if ($? != 0);

    dies_ok { EBox::FileSystem::makePrivateDir('/gion.private')  } 'Test for error when failing to create a private dir';

    lives_ok {EBox::FileSystem::makePrivateDir($dir)  } 'Test for success when called to create a private dir';

}


sub cleanDirTest
{
  my $rootDir ='/tmp/ebox.test.filesystem.cleanDir';
  system "rm -rf $rootDir";
  die $! if ($? != 0);
  mkdir ($rootDir, 0700);

  dies_ok { EBox::FileSystem::cleanDir("/noPermission")  } "Testing for error if not write allowed";
  dies_ok { EBox::FileSystem::cleanDir("/root/inexistentThings/inexistentDir")  } "Testing for error when called in behalf of a unredeable dir";

  system "touch $rootDir/noDir";
  dies_ok { EBox::FileSystem::cleanDir("$rootDir/noDir")  } "Testing for error when trying to clean a no-dir file";



  my %dirsWithModes = (
		       "$rootDir/hashParam" => 0750,
		       "$rootDir/stringParam" => 0700,
		      );
my @cleanDirParams = ("$rootDir/stringParam", { name => "$rootDir/hashParam", mode =>  $dirsWithModes{"$rootDir/hashParam"} });

  lives_ok  {  EBox::FileSystem::cleanDir(@cleanDirParams) }, 'cleanDir() called with no existent dirs yet';
  
  diag 'Testing directory status';
  while (my ($dir, $mode) = each %dirsWithModes) {
    file_exists_ok($dir);
    file_mode_is($dir, $mode);
  }
  
  # populating dirs
  system "touch $_/dirt" foreach keys %dirsWithModes;

  lives_ok  {  EBox::FileSystem::cleanDir(@cleanDirParams) }, 'cleanDir() called with existent dirs';
  
  diag 'Testing directory status after the cleaning';
  while (my ($dir, $mode) = each %dirsWithModes) {
    file_exists_ok($dir);
    file_mode_is($dir, $mode);
    system "ls $dir/*";
    ok ($? != 0), 'Checking that cleaned directory is empty';
  }  
  
}

1;
