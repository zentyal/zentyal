use strict;
use warnings;

use lib '../..';
use TestHelper;;
use EBox::Test::Mason;

use Test::More tests => 7;


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
	     [@nameAndValue, extraParams => [options => \@options] ],
	     [@nameAndValue, options => \@options, extraParams => [ options => [ value => 'Bad option' ] ]  ], 
	     [@nameAndValue, options => \@options, extraParams => [ disabled => 'disabled'] ],
	     [@nameAndValue, options => \@options, extraParams => [ multiple => 'multiple'] ],
	    );

TestHelper::testComponent('select.mas', \@cases);


1;
