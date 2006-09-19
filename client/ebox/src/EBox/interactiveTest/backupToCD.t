use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;
use Perl6::Junction qw(all);
use EBox::Test;

use lib '../..';
use_ok(' EBox::Backup');


my $TEST_DIR = '/tmp/ebox.backuptocd.test';
system "rm -rf $TEST_DIR";
mkdir $TEST_DIR or die "$!";


EBox::Test::activateEBoxTestStubs();
EBox::Test::setEBoxConfigKeys(tmp =>  $TEST_DIR, conf => $TEST_DIR);

diag "This test must be run as root otherwise some parts may fail";
diag "This test burns writable media.";
diag "TODO: check restore";



while (1) {
  discPrompt();
  my $backup =  EBox::Backup->new();
  my $success = lives_ok { $backup->makeBackup(description => 'ea', fullBackup => 0, directlyToCD => 1) } 'Trying backup drectly to cd';
  if ($success) {
    diag "Check the disc to assure that  data was correctly written";
  }
}



sub discPrompt
{
  diag "Insert disc and hit return to coninue or type 'quit' + return to quit\n";
  my $input = <>;
  chomp $input;
  exit 0 if $input eq 'quit';
}



1;
