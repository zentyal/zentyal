use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 4;

my $printOutput = 0;
my $outputFile  = '/tmp/link.html';
system "rm -rf $outputFile";


my $linkTemplate =   getcwd() . '/../link.mas';

my @cases = (
	     [href => "http://www.google.com"],
	     [href => "http://www.google.com", text => "simple link title"],
	     [href => "http://www.google.com", image => "/www/simple.jpg"],
	     [href => "http://www.google.com", text => "simple link title", image => "/www/simple/jpg"],
	    );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $linkTemplate, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}



1;
