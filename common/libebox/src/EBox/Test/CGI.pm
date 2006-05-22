package EBox::Test::CGI;
# Description:
#
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK   = qw(runCgi cgiErrorOk cgiErrorNotOk);
our %EXPORT_TAGS = (all => \@EXPORT_OK  );


use Test::Builder;
my $Test = Test::Builder->new;

sub runCgi
{
    my ($cgi, %params) = @_;
    
    while (my ($paramName, $paramValue) = each %params) {
	my $query = $cgi->{cgi};
	$query->param( $paramName =>  $paramValue);
    }

    $cgi->run();

}

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



sub _errorInCgi
{
    my ($cgi) = @_;
    return defined ($cgi->{error}) or defined ($cgi->{olderror});
}


1;
