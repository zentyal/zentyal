package SambaTest;

use strict;
use warnings;

use base 'Test::Class';

use File::Path;
use File::Basename;
use File::stat;
use Test::More;
use Test::Exception;
use Test::File;

use EBox::Samba;
use EBox::UsersAndGroups;

use Readonly;
Readonly::Scalar my $TEST_DIR => '/tmp/ebox.samba.root.test';
Readonly::Scalar my $CONFIG_BACKUP_DIR => "$TEST_DIR/backup";
Readonly::Scalar my $CONFIG_BACKUP_WO_SHARES_DIR => "$TEST_DIR/backup-wo";
Readonly::Scalar my $FULL_BACKUP_DIR => "$TEST_DIR/full";
Readonly::Scalar my $FULL_BACKUP_WO_SHARES_DIR => "$TEST_DIR/full-wo";
Readonly::Scalar my $FULL_BACKUP_LEFTOVER_DIR => "$TEST_DIR/full-left";
Readonly::Scalar my $CONFIG_BACKUP_LEFTOVER_DIR => "$TEST_DIR/config-left";
Readonly::Scalar my $TEST_USER         => 'testUser354';
Readonly::Scalar my $TEST_USER_LEFTOVER => $TEST_USER . 'l';


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

  File::Path::mkpath([$TEST_DIR, $CONFIG_BACKUP_DIR, $FULL_BACKUP_DIR, $CONFIG_BACKUP_WO_SHARES_DIR, $FULL_BACKUP_WO_SHARES_DIR, $FULL_BACKUP_LEFTOVER_DIR, $CONFIG_BACKUP_LEFTOVER_DIR]);
}



sub _removeTestUsers
{
  my $users = EBox::Global->modInstance('users');
  foreach my $user ($TEST_USER, $TEST_USER_LEFTOVER) {
    if ($users->userExists($user)) {
      $users->delUser($user);
    }
    EBox::Sudo::root('/bin/rm -rf ' . EBox::SambaLdapUser::usersPath() . '/' . $user );
  }


}

sub teardownTestUsers : Test(teardown)
{
  _removeTestUsers();
}

sub setupTestUser : Test(setup)
{
  _removeTestUsers();
}


sub configBackupWithoutSharesTest : Test(2)
{
  _checkBackup($CONFIG_BACKUP_WO_SHARES_DIR, 0);
  _checkRestore($CONFIG_BACKUP_WO_SHARES_DIR, 0);
}

sub configBackupTest : Test(8)
{
  my $status = _setConfig();

  _checkBackup($CONFIG_BACKUP_DIR, 0);
  ok !( -f "$CONFIG_BACKUP_DIR/samba.bak"), 'Checking that configuration data is not stored in the backup root dir';

  _messConfig();

  _checkRestore($CONFIG_BACKUP_DIR, 0);

  _checkConfig($status);
}


sub fullBackupWithoutSharesTest : Test(2)
{
  _checkBackup($FULL_BACKUP_WO_SHARES_DIR,  1);
  _checkRestore($FULL_BACKUP_WO_SHARES_DIR, 1);
}

sub fullBackupTest : Test(7)
{
  my $status = _setConfig();
  
  _checkBackup($FULL_BACKUP_DIR,  1);

  _messConfig();

  _checkRestore($FULL_BACKUP_DIR, 1);

  _checkConfig($status);
}


sub _checkBackup
{
  my ($dir, $fullBackup) = @_;

  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

  lives_ok { 
#    $users->makeBackup($dir, fullBackup => $fullBackup);
    $samba->makeBackup($dir, fullBackup => $fullBackup) ;
  } 'Backup data in ' . $fullBackup ? 'full backup mode' : 'configuration backup mode' ;
}


sub _checkRestore
{
  my ($dir, $fullRestore) = @_;

  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

  lives_ok { 
#    $users->restoreBackup($dir, fullRestore => $fullRestore);
    $samba->restoreBackup($dir, fullRestore => $fullRestore) ;
  } 'Restore data in ' . $fullRestore ? 'full restore mode' : 'configuration restore mode' ;
}

sub _setConfig
{
  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

  $samba->setFileService(1);
  $users->addUser({user => $TEST_USER, fullname => 'aa', password => 'a', comment => 'a'});

  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};

  my $homedirStat = stat($homedir);
  return { homedirStat => $homedirStat };
}

sub _messConfig
{
  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

#  $users->addUser({user => $TEST_USER_LEFTOVER, fullname => 'aa', password => 'a', comment => 'a'});
  $samba->setFileService(0);

  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};
  EBox::Sudo::root("/bin/rm -rf $homedir");
  (! -e $homedir) or die 'homedir not removed' ;
}


sub _checkConfig
{
  my ($status) = @_;

  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');

  ok $samba->fileService(), 'Checking that file service was restored';
#  ok !$users->userExists($TEST_USER_LEFTOVER), "checking that user added after backup does not exists";

  my $homedir = $users->userInfo($TEST_USER)->{homeDirectory};
  _checkRestoredDir($homedir, $status->{homedirStat});
}

sub leftoversWithConfigurationBackupTest : Test(49)
{
  _leftoversTest($CONFIG_BACKUP_LEFTOVER_DIR, 0);
}


sub leftoversWithFullBackupTest   : Test(49)
{
  _leftoversTest($FULL_BACKUP_LEFTOVER_DIR, 1);
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

# this counts for 49 tests
sub _leftoversTest 
{
  my ($backupDir, $fullBackup) = @_;

  my $samba = EBox::Global->modInstance('samba');
  my $users = EBox::Global->modInstance('users');
  
  my $leftoversBase = $samba->leftoversDir();
  EBox::Sudo::root("/bin/rm -rf $leftoversBase");


  my $status = _setConfig();
  
  _checkBackup($backupDir, $fullBackup);

  _messConfig();

  
  # simulate leftover bits from user 
  my $homedir = EBox::SambaLdapUser::usersPath() . '/leftoverUserTest';
  _simulateLeftoverDir($homedir);
  # simulate leftover bits from group
  my $groupdir = EBox::SambaLdapUser::groupsPath() . '/leftoverGroupTest';
  _simulateLeftoverDir($groupdir);

  _checkRestore($backupDir, $fullBackup);

  _checkConfig($status);

  diag "Checking if leftover stuff was correctly treated\n";

  my $userLeftoverDir = $leftoversBase . '/users/' . File::Basename::basename($homedir);
  _checkLeftoverDirAfterBackup($homedir, $userLeftoverDir);
  my $groupLeftoverDir = $leftoversBase . '/groups/' . File::Basename::basename($groupdir);
  _checkLeftoverDirAfterBackup($groupdir, $groupLeftoverDir);


  diag "we will put leftovers and restore again to be sure that the leftover are respected";

  _simulateLeftoverDir($homedir);
  _simulateLeftoverDir($groupdir);

  _checkRestore($backupDir, $fullBackup);

  _checkConfig($status);

  my $userLeftoverDir2=  "$userLeftoverDir.2";
  _checkLeftoverDirAfterBackup($homedir, $userLeftoverDir2);
  my $groupLeftoverDir2=  "$groupLeftoverDir.2";
  _checkLeftoverDirAfterBackup($groupdir, $groupLeftoverDir2);
}

sub _simulateLeftoverDir
{
  my ($dir) = @_;

  EBox::Sudo::root("/bin/mkdir $dir");
  my $dirFile = "$dir/canary";
  EBox::Sudo::root("/bin/touch $dirFile");
  EBox::Sudo::root("/bin/chown -R 3000.3000 $dir"); # arbitray id for simulate lost id
}

sub _checkLeftoverDirAfterBackup
{
  my ($previousDir, $leftoverDir) = @_;
  diag "Case $previousDir $leftoverDir \n";

  ok !(-d $previousDir), 'Checking if homedir was not left in his previous place';


  my $stDir = EBox::Sudo::stat($leftoverDir);  
  ok $stDir, 'Checking if homedir was moved to leftover dir';
 SKIP:{
    skip 3, "Home dir not moved so ownership and permissions tests skipped" unless defined $stDir;
    is $stDir->uid, 0, 'Checking that file now is owner by root';
    is $stDir->gid, 0, 'Checking that file now is owner by root group';
	
    my $permissions = EBox::FileSystem::permissionsFromStat($stDir);
    is $permissions,  '0755', 'Checking that user leftover dir has restricitive permissions';
  }

  my $stCanary = EBox::Sudo::stat($leftoverDir . '/canary');
  ok $stCanary, 'Checking that canary file was not lost';
 SKIP:{
    skip 3, "Canary file lost so ownership and permissions tests skipped" unless  $stCanary;
    is $stCanary->uid, 0, 'Checking that file now is owner by root';
    is $stCanary->gid, 0, 'Checking that file now is owner by root group';
	
    my $filePermissions = EBox::FileSystem::permissionsFromStat($stCanary);
    is $filePermissions,  '0600', 'Checking that canary file has restricitive permissions';
  }

}




1;
