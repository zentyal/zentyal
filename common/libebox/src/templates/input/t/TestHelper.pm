package TestHelper;

use strict;
use warnings;

use EBox::Test::Mason;
use File::Basename;
use Cwd;

sub testComponent
{
  my ($component, $cases_r, $printOutput) = @_;
  defined $printOutput or $printOutput = 0;

  my ($componentWoExt) = split '\.', (basename $component);
  my $outputFile  = "/tmp/$componentWoExt.html";
  system "rm -rf $outputFile";

  my $compRoot =   dirname dirname getcwd(); # XXX this is templates/input directory specific
  my $template =   (dirname getcwd()) . "/$component";

  foreach my $params (@{ $cases_r }) {
    EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, compRoot => [$compRoot], printOutput => $printOutput, outputFile => $outputFile);
  }


}

1;
