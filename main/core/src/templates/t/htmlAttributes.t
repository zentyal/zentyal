use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;
use Dir::Self;

use Test::More tests => 3;

my $printOutput = 0;
my $outputFile  = '/tmp/htmlAttributes.txt';
system "rm -rf $outputFile";

my @cases = (
    [],
    [qw(name macaco)],
    [qw(name macaco value jefatura)],
);

my $htmlAttributesTemplate = __DIR__ . '/../htmlAttributes.mas';

foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $htmlAttributesTemplate, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}

1;
