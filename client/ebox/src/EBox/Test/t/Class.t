use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

use lib '../../..';



use_ok('EBox::Test::Class');

$INC{'SimpleTest.pm'} = 1;
lives_ok { SimpleTest->runtests()  } 'Checking that runtests method lives in child class';


package SimpleTest;
use base 'EBox::Test::Class';
use Test::Simple;

sub simple : Test(1)
{
  ok (1, "Checking that child class executes well");
}

1;
