package SambaTest;

use strict;
use warnings;

use base 'Test::Class';

use File::Path;
use File::stat;
use File::Slurp::Tree;
use Test::More;
use Test::Exception;


use lib '../..';

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





sub teardownTestUser : Test(teardown)
{
  my $users = EBox::Global->modInstance('users');
  if ($users->userExists($TEST_USER)) {
    $users->delUser($TEST_USER);
  }
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
  my $homedirStat = stat $homedir;

  lives_ok { $samba->makeBackup($CONFIG_BACKUP_DIR) } 'Config backup';
  ok !( -f "$CONFIG_BACKUP_DIR/samba.bak"), 'Checking that configuration data is not stored in the backup root dir';

  # unset stuff
  $samba->setFileService(0);
  EBox::Sudo::root("/bin/rm -rf $homedir");
  (! -e $homedir) or die 'homedir not removed' ;

  lives_ok { $samba->restoreBackup($CONFIG_BACKUP_DIR) } 'Config restore';

  ok $samba->fileService(), 'Checking that file service was restored';

  ok -d $homedir, 'Checking if homedir was restored';
  my $newHomedirStat = stat $homedir;
  foreach (qw(uid gid mode)) {
    is $newHomedirStat->$_, $homedirStat->$_, "Checking restored $_";
  }


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
  my $homedirStat = stat $homedir;
#  writeFileTree($homedir);
  
  lives_ok { $samba->makeBackup($FULL_BACKUP_DIR, fullBackup => 1) } 'Full backup';

  # unset stuff
  $samba->setFileService(0);
  EBox::Sudo::root("/bin/rm -rf $homedir");
  (! -e $homedir) or die 'homedir not removed' ;

  lives_ok { $samba->restoreBackup($FULL_BACKUP_DIR, fullBackup => 1) } 'Full restore';

  # check restored stuff
  ok $samba->fileService(), 'Checking that file service was restored';

  ok -d $homedir, 'Checking if homedir was restored';
  my $newHomedirStat = stat $homedir;
  foreach (qw(uid gid mode)) {
    is $newHomedirStat->$_, $homedirStat->$_, "Checking restored $_";
  }
#  checkFileTree($homedir);
}




Readonly::Scalar my $REF_DIR =>  '..';


sub writeFileTree
{
  my ($dir) = @_;

  my $tree = File::Slurp::Tree::slurp_tree($REF_DIR);
  File::Slurp::Tree::spew_tree($dir => $tree);
}

sub checkFileTree
{
  my ($dir) = @_;

  my $expected = File::Slurp::Tree::slurp_tree($REF_DIR);
  my $actual = File::Slurp::Tree::slurp_tree($REF_DIR);

  is_deeply $actual, $expected, "Checking file tree rooted a $dir";
}


1;
