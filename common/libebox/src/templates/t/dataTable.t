package main;
# package:
use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 5;

my $printOutput = 0;
my $outputFile  = '/tmp/dataTable.html';
system "rm -rf $outputFile";

my $tableTemplate =   getcwd() . '/../dataTable.mas';


my @columnTitles = qw(Arabic Roman Binary Actions);
my @rows = (
	    ['not a number', 'no roman concept', 'NaN', 
	     [] #  no actions avaialble for NaNs..	       ],
	    ],

	    ['0', 'no symbol for zero', '0', 
	     [
	      { url => 'increase?id=0', icon => 'www/img/increase.png', text => 'Increase this number' },
	       ],
	    ],

	    ['4', 'IV', '100',, 
	     [
	      { url => 'increase?id=4', icon => 'www/img/increase.png', text => 'Increase this number' },
	      { url => 'denominator?id=4', icon => 'www/img/denominator.png', text => 'Use this number as denominator' },

	       ],],

	    ['15', 'XV', '1111',, 
	     [
	      { url => 'increase?id=15', icon => 'www/img/increase.png', text => 'Increase this number' },
	      { url => 'denominator?id=15', icon => 'www/img/denominator.png', text => 'Use this number as denominator' },
	       ],
	    ],
	    

	   );
my @additionalComponents = (
		       'input/text.mas', name => 'numbers', value => 'Write new number here',
		      );

my @cases = (
	     [],  # no arguments case
	     [rows => \@rows ],
	     [columnTitles => \@columnTitles],
	     [columnTitles => \@columnTitles, rows => \@rows],
	     [columnTitles => \@columnTitles, rows => \@rows, additionalComponents => \@additionalComponents],
	    );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $tableTemplate, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}

1;
