package GConfBackupTest;
use base 'Test::Class';

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Gnome2::GConf;

use EBox::TestStub;
use EBox::Config::TestStub;


use Readonly;
Readonly::Scalar my $TEST_DIR => '/tmp/ebox.gconfbackup.test';

use lib '../../..';
use EBox::Backup;


sub notice : Test(startup)
{
  diag "This tests alter the user's GConf data in a no-destructive way. It try to revert it after the test but it may fail";
}

sub fakeEBox : Test(startup)
{
  EBox::TestStub::fake();
  EBox::Config::TestStub::fake(tmp => $TEST_DIR);
}


sub setupTestDir : Test(setup)
{
  system "rm -rf $TEST_DIR";
  mkdir $TEST_DIR;
  mkdir EBox::Backup::dumpDir();
  mkdir EBox::Backup::restoreDir();
}

sub gconfDumpAndRestoreTest : Test(3)
{
  my $canaryKey = '/ebox/before';
  my $backup = EBox::Backup->_create();

  my $client = Gnome2::GConf::Client->get_default;
  $client->set_bool($canaryKey, 1);

  lives_ok { $backup->dumpGConf() } "Dumping GConf";

  $client->set_bool($canaryKey, 0);
  if ($client->get_bool($canaryKey)) {
    die "GConf operation failed";
  }

  # poor man;s backup emulation
  system 'cp -r ' .  EBox::Backup::dumpDir() . '/* ' . EBox::Backup::restoreDir . '/';
  die $! if ($? != 0);

  lives_ok { $backup->restoreGConf() } 'Restoring GConf';
  ok $client->get_bool($canaryKey), 'Checking canary GConf entry after restore';

  $client->unset($canaryKey); # try to not poluate user's gconf
}

1;
