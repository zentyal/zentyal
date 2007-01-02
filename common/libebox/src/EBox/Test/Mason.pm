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
use HTML::Mason;
use Cwd qw(abs_path);
use Test::More;
use Error qw(:try);

sub checkTemplateExecution
{
  my %args = @_;
  my $template       = $args{template};
  my $templateParams = exists $args{templateParams} ? $args{templateParams} : [];
  my $compRoot      =  exists $args{compRoot}       ? $args{compRoot } : [];

  my $printOutput    = $args{printOutput};
  my $outputFile     = exists $args{outputFile} ? $args{outputFile} : '/tmp/' . basename $template;

  my $templateOutput;

  my $templateExecutionOk = 0;
  try { 
    $templateOutput = executeTemplate(template       => $template, 
				      templateParams => $templateParams,
				      compRoot       => $compRoot,
				     );
    $templateExecutionOk = 1;
  }
  otherwise {
    my $ex = shift @_;
    my $exText = "$ex";
    $templateOutput = \$exText; # templateOutput msut be a scalar ref to be in the same form that the return value of executeTemplate
  };

  ok $templateExecutionOk, "Testing if execution of template $template with params @$templateParams was sucessful";
  
  if ($printOutput) {
    diag "Template $template with parameters @$templateParams output:\n$$templateOutput\n";
  }
  if ($outputFile) {
    _printOutputFile($outputFile, $templateOutput);
  }
}


sub executeTemplate
{
  my %args = @_;
  my $template        = $args{template};
  my @params          = exists $args{templateParams} ?  @{ $args{templateParams} } : ();
  my $additionalRoots = exists $args{compRoot}       ?  $args{compRoot}            : [];

  my $comp_root = _comp_root($template, $additionalRoots);
  my $templateOutput;

  my $interp = HTML::Mason::Interp->new(comp_root => $comp_root, out_method => \$templateOutput);

  my $comp = $interp->make_component(comp_file => $template);


  $interp->exec($comp, @params);
  
  return \$templateOutput;
}



sub _comp_root
{
  my ($template, $root_paths_r) = @_;
  my @root_paths = @{ $root_paths_r } ;
  
  my $main_root = abs_path ($template);
  $main_root = dirname $main_root;
 
  my $i = 0; # counter to generate comp_root ids
  my @roots = map { 
    $i++;  
    [ "user-$i" => $_ ] } 
    @root_paths;

  unshift @roots, [ MAIN => $main_root ];


  return \@roots;
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
