package EBox::Test::Mason;
# package: EBox::Test::Mason
#  to ease the testing of mason components. This does NOT test all the content (use HTML::Maason::Test for this) but only checks if compiles.
# You can revise the output files by eye after running the tests
#
# This currently depends from exec-mason-temaplate tool

use strict;
use warnings;

use File::Slurp;
use File::Basename;

use Test::More;

sub checkTemplateExecution
{
  my %args = @_;
  my $template       = $args{template};
  my $templateParams = exists $args{templateParams} ? '--params ' . $args{templateParams} : '';
  my @compRoot      =  exists $args{compRoot} ? @{ $args{compRoot }} : ();
  my $printOutput    = $args{printOutput};
  my $outputFile     = exists $args{outputFile} ? $args{outputFile} : '/tmp/' . basename $template;

  my @compRootParams = map { "--comp-root $_" } @compRoot;


  
  my $cmd = "exec-mason-template  $templateParams @compRootParams $template";
  my @templateOutput = `$cmd`;
  my $cmdOk =  ($? == 0);
  
  ok $cmdOk, "Testing if execution of template $template with params $templateParams was sucessdul";
  
  if ($printOutput) {
    diag "Template $template with parameters $templateParams output:\n@templateOutput\n";
  }
  if ($outputFile) {
    _printOutputFile($outputFile, \@templateOutput);
  }
}


sub _printOutputFile
{
  my ($outputFile, $data) = @_;
  my $separator;
  
  if ($outputFile =~ m/\.html?$/) {
    $separator = '<hr/>';    
  }
  else {
    $separator = "---------------\n";
  }
  
  write_file($outputFile, { append => 1}, $separator );
  write_file($outputFile, {append =>  1 }, $data );
}

1;
