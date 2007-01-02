use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 5;

my $printOutput = 0;
my $outputFile  = '/tmp/table.html';
system "rm -rf $outputFile";

my $tableTemplate =   getcwd() . '/../table.mas';


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


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $tableTemplate, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}

1;
