package main;
# package:
use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 4;

my $outputFile  = '/tmp/link.html';
my $printOutput = 0;
my $linkTemplate =   getcwd() . '/../link.mas';

my @cases = (
	     q{'href => "http://www.google.com"'},
	     q{'href => "http://www.google.com", text => "simple link title"'},
	     q{'href => "http://www.google.com", image => "/www/simple.jpg"'},
	     q{'href => "http://www.google.com", text => "simple link title", image => "/www/simple/jpg"'},
	    );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $linkTemplate, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}



1;
