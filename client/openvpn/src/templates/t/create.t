use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More qw(no_plan);

my $printOutput = 0;
my $outputFile  = '/tmp/create.html';
system "rm -rf $outputFile";

my $template =   getcwd() . '/../create.mas';
my @compRoot = ('/usr/share/ebox/templates');


my @certificates = ('macaco certificate', 'baboon certificate');

my @cases = (  
	     [ disabled => 1, availableCertificates => \@certificates],# disabled
	     [ disabled => 0, availableCertificates => []],            # enabled with NO certificates
	     [ disabled => 0, availableCertificates => \@certificates],#enabled
	    );


foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile, compRoot => \@compRoot);
}

1;
