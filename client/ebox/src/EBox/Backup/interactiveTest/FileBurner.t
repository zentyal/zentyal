use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;
use Perl6::Junction qw(all);
use EBox::Test;

use lib '../../..';
use_ok(' EBox::Backup::FileBurner');

my $FILE = $0;

EBox::Test::activateEBoxTestStubs();
EBox::Test::setEBoxConfigKeys(tmp => '/tmp');

diag "This test must be run as root otherwise some parts may fail";
diag "This test burns writable media. It writes on them the file $FILE, change the \$FILE constant if you want burn anothe file";

die "$FILE is no redeable" if (! -r $FILE);




while (1) {
  discPrompt();
  my $success = lives_ok { EBox::Backup::FileBurner::burn(file => $FILE) } 'Trying to burn file';
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
