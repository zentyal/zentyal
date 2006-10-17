package SambaTest;

use strict;
use warnings;

use base 'Test::Class';

use File::Path;
use File::stat;
use Test::More;
use Test::Exception;
use Test::File;

use EBox::Samba;
use EBox::Test;

use Readonly;
Readonly::Scalar my $TEST_DIR => '/tmp/ebox.samba.root.test';
Readonly::Scalar my $CONFIG_BACKUP_DIR => "$TEST_DIR/backup";
Readonly::Scalar my $CONFIG_BACKUP_WO_SHARES_DIR => "$TEST_DIR/backup-wo";
Readonly::Scalar my $FULL_BACKUP_DIR => "$TEST_DIR/full";
Readonly::Scalar my $FULL_BACKUP_WO_SHARES_DIR => "$TEST_DIR/full-wo";
Readonly::Scalar my $TEST_USER         => 'testUser354';



sub __notice : Test(startup)
{
  diag "This test must be run as root\n";
  diag "It requires that you had isntalled the samba and usergroups modules and his asscoiate software\n";
  diag "WARNING: Do not use it in a production system. It may change or corrupt your data\n";
}

sub _initEBox : Test(startup)
{
  EBox::init();
}

sub setupTestDir : Test(startup)
{
  if (-e $TEST_DIR) {
    File::Path::rmtree($TEST_DIR);
  }

  File::Path::mkpath([$TEST_DIR, $CONFIG_BACKUP_DIR, $FULL_BACKUP_DIR, $CONFIG_BACKUP_WO_SHARES_DIR, $FULL_BACKUP_WO_SHARES_DIR]);
}



sub _removeTestUser
{
  my $users = EBox::Global->modInstance('users');
  if ($users->userExists($TEST_USER)) {
    $users->delUser($TEST_USER);
  }
  EBox::Sudo::root("/bin/rm -rf /home/samba/users/$TEST_USER");
}

sub teardownTestUser : Test(teardown)
{
  _removeTestUser();
}

sub setupTestUser : Test(setup)
{
  _removeTestUser();
}


sub configBackupWithoutSharesTest : Test(2)
{
  my $samba = EBox::Global->modInstance('samba');
  lives_ok { $samba->makeBackup($CONFIG_BACKUP_WO_SHARES_DIR) } 'Config backup without any directory';
  lives_ok { $samba->restoreBackup($CONFIG_BACKUP_WO_SHARES_DIR) } 'Config restore without any directory';
}

sub configBackupTest : Test(8)
{
  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');
  

  # setup things ..
  $samba->setFileService(1);
  $users->addUser({user => $TEST_USER, fullname => 'aa', password => 'a', comment => 'a'});
  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};
  my $homedirStat = stat($homedir);
  defined $homedirStat or die "Can not get stat object for $homedir";

  lives_ok { $samba->makeBackup($CONFIG_BACKUP_DIR) } 'Config backup';
  ok !( -f "$CONFIG_BACKUP_DIR/samba.bak"), 'Checking that configuration data is not stored in the backup root dir';

  # unset stuff
  $samba->setFileService(0);
  EBox::Sudo::root("/bin/rm -rf $homedir");
  (! -e $homedir) or die 'homedir not removed' ;

  lives_ok { $samba->restoreBackup($CONFIG_BACKUP_DIR) } 'Config restore';

  ok $samba->fileService(), 'Checking that file service was restored';

  _checkRestoredDir($homedir, $homedirStat);
}


sub fullBackupWithoutSharesTest : Test(2)
{
my $samba = EBox::Global->modInstance('samba');
  lives_ok { $samba->makeBackup($FULL_BACKUP_WO_SHARES_DIR, fullBackup => 1) } 'Full backup without any directory';
  lives_ok { $samba->restoreBackup($FULL_BACKUP_WO_SHARES_DIR, fullBackup => 1) } 'Full restore without any directory';
}

sub fullBackupTest : Test(7)
{
  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

  # setup things ..
  $samba->setFileService(1);
  $users->addUser({user => $TEST_USER, fullname => 'aa', password => 'a', comment => 'a'});
  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};
  my $homedirStat = stat($homedir);
  
  lives_ok { $samba->makeBackup($FULL_BACKUP_DIR, fullBackup => 1) } 'Full backup';

  # unset stuff
  $samba->setFileService(0);
  EBox::Sudo::root("/bin/rm -rf $homedir");
  (! -e $homedir) or die 'homedir not removed' ;

  lives_ok { $samba->restoreBackup($FULL_BACKUP_DIR, fullRestore => 1) } 'Full restore';

  # check restored stuff
  ok $samba->fileService(), 'Checking that file service was restored';

  _checkRestoredDir($homedir, $homedirStat);
}

sub leftoversWithConfigurationBackupTest : Test(11)
{
  _leftoversTest(0);
}


sub leftoversWithFullBackupTest   : Test(11)
{
  _leftoversTest(1);
}


# that counts for 4 checks
sub _checkRestoredDir
{
  my ($dir, $previousStat) = @_;

  my $newStat = EBox::Sudo::stat($dir);
  ok $newStat,  'Checking if dir was restored';
 SKIP: {
    skip 3, "Dir not restored so we don't test ownership and permissions" unless defined $newStat;

    foreach (qw(uid gid mode)) {
      is $newStat->$_, $previousStat->$_, "Checking restored $_";
    }
  }
}

# this counts for 11 tests
sub _leftoversTest 
{
  my ($fullBackup) = @_;
  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');
  
  lives_ok { $samba->makeBackup($FULL_BACKUP_DIR, fullBackup => 1) } 'Full backup';

  # add user after backup
  $users->addUser({user => $TEST_USER, fullname => 'aa', password => 'a', comment => 'a'});
  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};
  my $homedirFile = "$homedir/canary";
  EBox::Sudo::root("/bin/touch $homedirFile");

  lives_ok { $samba->restoreBackup($FULL_BACKUP_DIR, fullBackup => 1) } 'Full restore';

  ok !(-d $homedir), 'Checking if homedir was not left in his previous place';
  
  my $leftoverDir = $samba->leftoversDir() . '/' . File::Path::basename($homedir);
  ok -d $leftoverDir, 'Checking if homedir was moved to leftover dir';
  owner_is ($leftoverDir, 'root', 'Checking that leftover dir is owned by root');
  group_is($leftoverDir, 'root', 'Checking that leftover dir is owned by root group');
  file_mode_is($leftoverDir, oct 700, 'Checking that leftover dir has restrictive permissions');
  
  my $stat = EBox::Sudo::stat($leftoverDir . '/canary');
  ok $stat, 'Checking that canary file was not lost';
 SKIP:{
    skip 3, "Canary file lost so ownership and permissions tests skipped" unless defined $stat;
    is $stat->{uid}, 0, 'Checking that file now is owner by root';
    is $stat->{gid}, 0, 'Checking that file now is owner by root group';
  
    my $permissions = EBox::FileSystem::permissionsFromStat($stat);
    is $permissions, oct 500, 'Checking that canary file has restricitive permissions';
  }
}




1;
