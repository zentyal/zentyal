package EBox::Test::CGI;
# Description:
#
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK   = qw(runCgi setCgiParams cgiErrorOk cgiErrorNotOk  checkCgiError checkMasonParameters muteHtmlOutput);
our %EXPORT_TAGS = (all => \@EXPORT_OK  );

use Test::Differences;
use Test::Builder;
my $Test = Test::Builder->new;

sub runCgi
{
    my ($cgi, @params) = @_;
    
    setCgiParams($cgi, @params);

    $cgi->run();
}


sub setCgiParams
{
    my ($cgi, %params) = @_;

    while (my ($paramName, $paramValue) = each %params) {
	my $query = $cgi->{cgi};
	$query->param( $paramName =>  $paramValue);
    }

}

# there are 3 subs to check error because i am not sure what style/name is better
sub cgiErrorOk
{
    my ($cgi, $name) = @_;
    my $errorFound = _errorInCgi($cgi);

    $Test->ok($errorFound, $name);
}

sub cgiErrorNotOk
{
    my ($cgi, $name) = @_;
    my $errorNotFound = not _errorInCgi($cgi);

    $Test->ok($errorNotFound, $name);
}


sub checkCgiError
{
    my ($cgi, $wantError, $name) = @_;
    if ($wantError) {
	cgiErrorOk($cgi, $name);
    }
    else {
	cgiErrorNotOk($cgi, $name);
    }
}

sub _errorInCgi
{
    my ($cgi) = @_;
    return defined ($cgi->{error}) or defined ($cgi->{olderror});
}


sub muteHtmlOutput
{
  my ($class) = @_;

  my $mutePrintHtmlCode = "no warnings; package $class; sub _print {}; ";
  eval $mutePrintHtmlCode;
  if ($@) {
    die "Error when overriding _printHtml with a muted version: $@";
  }
          
}
  



sub checkMasonParameters
{
    my ($cgi, %params) = @_;
    my $error = undef;

    exists $params{wantedParameters} or die "wantedParameters argument not found";
    my $wantedParameters = $params{wantedParameters};

    my $testName = exists $params{testName} ? $params{testName} : 'Checking mason parameters';

   # we convert to hash to eliminate order issues
    my $masonParameters = $cgi->{params};
    my $params = defined $masonParameters ?  { @{ $masonParameters } } : {}; 

    eq_or_diff $params, $wantedParameters, $testName;
}


1;
