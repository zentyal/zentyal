use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;
use Perl6::Junction qw(all);
use EBox::TestStubs;

use lib '../..';

use_ok(' EBox::Backup');
use EBox::Backup::Test;

my $TEST_DIR = '/tmp/ebox.backuptocd.test';
system "rm -rf $TEST_DIR";
mkdir $TEST_DIR or die "$!";


EBox::TestStubs::activateTestStubs();
EBox::TestStubs::setEBoxConfigKeys(tmp =>  $TEST_DIR, conf => $TEST_DIR);
EBox::Backup::Test::setUpCanaries();

diag "This test must be run as root otherwise some parts may fail";
diag "This test burns writable media.";


while (1) {
    if (backupTest()) {
      restoreTest();
  }
}


sub backupTest
{
  diag "We will try to backup to disc";
  discPrompt();

  EBox::Backup::Test::setCanaries('before');

  my $backup =  EBox::Backup->new();
  my $success = lives_ok { $backup->makeBackup(description => 'ea', fullBackup => 1, directlyToDisc => 1) } 'Trying backup directly to cd';
  return $success;
}


sub restoreTest
{
    diag "We will try to restore from the disc";
    discPrompt();

    my $backup =  EBox::Backup->new();
    EBox::Backup::Test::setCanaries('after');

    lives_ok { $backup->restoreBackupFromDisc(fullRestore => 1) } 'Trying restore from disc';
    EBox::Backup::Test::checkCanaries('before', 1);    
}

sub discPrompt
{
  print "Insert disc and hit return to continue or type 'quit' + return to quit\n";
  my $input = <>;
  chomp $input;
  exit 0 if $input eq 'quit';
}



1;
