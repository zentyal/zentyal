package main;
# package:
use strict;
use warnings;

use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 3;

my $printOutput = 0;
my $outputFile  = '/tmp/componentCall.html';
system "rm -rf $outputFile";

my $template =   getcwd() . '/../componentCall.mas';

my @cases  = (
	      [ calls => [] ],
	      [ calls => ['msg.mas', msg => 'single call to msg.mas'] ],
	      [
	       calls => [
			 ['msg.mas', msg => 'Multiple calls: first call to msg.mas'],
			 ['msg.mas', msg => 'Multiple calls: second call to msg.mas'],
			]
	       ],

	     );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}



1;
