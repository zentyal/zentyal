# Description:
use strict;
use warnings;

use Test::More tests => 17;
use Test::Exception;
use Test::Builder::Tester ;



use lib '../../..';

use_ok ('EBox::Test::CGI', qw(:all));
use EBox::CGI::Base;




runCgiTest();
cgiErrorAssertionsTest();




sub runCgiTest
{
    my @cases = (
		 { cgiParams => [] },
		 { cgiParams => [primate => 'bonobo', otherParameter => 'macaco'] },
		 { cgiParams => [forceError => 0, otherParameter => 'macaco'] },
		 { cgiParams => [forceError => 1, otherParameter => 'macaco'], awaitedError => 1 },
		 );


    foreach my $case_r (@cases) {
	my $cgi = new EBox::CGI::DumbCGI;
	if ($cgi->hasRun()) {
	    die 'cgi reported as runned before it is really runned';
	}

	my @cgiParams    = @{ $case_r->{cgiParams}  };
	my $awaitedError = $case_r->{awaitedError};

	lives_ok { runCgi($cgi, @cgiParams) } "runCgi() call with cgi's parameters: @cgiParams";
	ok $cgi->hasRun(), "Checking if cgi has run"  ;
	
	my $error =  $cgi->{error};
	my $hasError =  defined $error;
	ok $hasError, 'Checking for error status in CGI'      if $awaitedError;
	ok !$hasError, 'Checking if CGI has not any error'    if !$awaitedError;
    }

}

sub cgiErrorAssertionsTest
{
    my $errorFreeCgi = new EBox::CGI::DumbCGI;
    my $errorRiddenCgi = new EBox::CGI::DumbCGI;
    $errorRiddenCgi->{error} = 'a error';
    
    # cgiErrorNotOk..
    test_out("ok 1 - errorFreeCgi");
    cgiErrorNotOk($errorFreeCgi, 'errorFreeCgi');    
    test_test('Checking positive assertion for cgiErrorNotOk');

    test_out("not ok 1 - errorRiddenCgi");
    test_fail(+1);
    cgiErrorNotOk($errorRiddenCgi, 'errorRiddenCgi');
    test_test('Checking negative assertion for cgiErrorNotOk');

    # cgiErrorOk..
    test_out("ok 1 - errorRiddenCgi");
    cgiErrorOk($errorRiddenCgi, 'errorRiddenCgi');
    test_test('Checking positive assertion for cgiErrorOk');

    test_out("not ok 1 - errorFreeCgi");
    test_fail(+1);
    cgiErrorOk($errorFreeCgi, 'errorFreeCgi');
    test_test('Checking negative assertion for cgiErrorOk');
}



package EBox::CGI::DumbCGI;
use base 'EBox::CGI::Base';

sub new 
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);
    $self->{hasRun} = 0; 

    bless $self, $class;
    return $self;
}

sub  _process
{
    my ($self) = @_;
    $self->{hasRun} = 1;

    my $errorParam = $self->param('forceError');


    if ($errorParam) {
	$self->{error} = 'Error forced by parameter';
    }
}


sub hasRun
{
    my ($self ) = @_;
    return $self->{hasRun};
}


# to eliminate html output while running cgi:
sub _print
{}

1;
