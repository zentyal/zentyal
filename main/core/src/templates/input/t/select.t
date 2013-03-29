use strict;
use warnings;

use lib '../..';

use EBox::Test::Mason;

use Test::More tests => 5;

my @options = (
	       { value => 'baboon' },
	       { value => 'mandrill', printableValue => 'mandrill printable value'},
	       { value => 'gibon', printableValue => 'gibon printable value'},
);

my @nameAndValue = (name => 'monkeys', value => 'mandrill');

my @cases = (
	     [ name => 'monos' ],  # minimal case
	     [@nameAndValue],
	     [@nameAndValue, options => \@options],
	     [@nameAndValue, options => \@options,  disabled => 'disabled'],
	     [@nameAndValue, options => \@options,  multiple => 'multiple'],
);

EBox::Test::Mason::testComponent('input/select.mas', \@cases);

1;
