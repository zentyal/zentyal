use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More qw(no_plan);

my $printOutput = 1;
my $outputFile  = '/tmp/formTable.html';
system "rm -rf $outputFile";

my $template =   getcwd() . '/../formTable.mas';


my @hiddenFields = (
		    [ input => 'hidden', name => 'hifden1' ],
		    [ component => '/input/hidden.mas', name =>  'hidden2'],
		   );

my @noHiddenFields = (
		      [ input => 'text', name => 'withoutPrintableName'],
		      [ component => '/input/text.mas', name => 'withPrintableName', printableName => 'This is a control with printable name'],
		      [ name => 'withHelpcomponent', help => 'This is component help'],
		     );

my @form = (
	    
	    

	   );

my @additionalComponents = (
		       'input/text.mas', name => 'numbers', value => 'Write new number here',
		      );

my @cases = (
	     [],  # no arguments case
	     [rows => \@hiddenFields ],
	     [rows => \@noHiddenFields ],
	     [rows => [@hiddenFields, @noHiddenFields] ],
	    );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}

1;
