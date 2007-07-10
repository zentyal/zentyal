use strict;
use warnings;


use TestHelper; 

use Test::More tests => 4;



my @hiddenFields = (
		    [ input => 'hidden', name => 'hifden1' ],
		    [ component => '/input/hidden.mas', name =>  'hidden2'],
		   );

my @noHiddenFields = (
		      [ input => 'text', name => 'withoutPrintableName'],
		      [ component => '/input/text.mas', name => 'withPrintableName', printableName => 'This is a control with printable name'],
		      [ name => 'withHelpcomponent', help => 'This is component help'],
		      [ name =>'submit', input => 'submit' ],
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



TestHelper::testComponent('formTable.mas', \@cases);

1;
