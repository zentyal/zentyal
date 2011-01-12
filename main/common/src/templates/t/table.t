use strict;
use warnings;

use TestHelper;
use Test::More tests => 5;


my @columnTitles = qw(arabic roman binary);
my @rows = (
	    ['0', 'no symbol for zero', 0,],
	    ['4', 'IV', '100',],
	    ['15', 'XV', '1111',],
	   );
my @additionalComponents = (
		       'msg.mas', msg => "suddenly, a message",
		      );

my @cases = (
	     [],  # no arguments case
	     [rows => \@rows ],
	     [columnTitles => \@columnTitles],
	     [columnTitles => \@columnTitles, rows => \@rows],
	     [columnTitles => \@columnTitles, rows => \@rows, additionalComponents => \@additionalComponents],
	    );


TestHelper::testComponent('table.mas', \@cases);


1;
