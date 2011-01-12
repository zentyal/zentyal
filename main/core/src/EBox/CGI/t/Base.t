# Description:
use strict;
use warnings;


use Test::More tests => 72;
use Test::Exception;

use lib '../../..';

use_ok ('EBox::CGI::Base');

use EBox::Test::CGI ':all';
use EBox::TestStub;

EBox::TestStub::fake();

paramsAsHashTest();
validateParamsTestWithRegularCases();
validateParamsTestWithFlexibleCases();
processTest();


sub paramsAsHashTest
{
    my $cgi = new EBox::CGI::DumbCGI;
    my %params = (
		  mono    => 'macaco',
		  primate => 'gorila',
		  lemur   => 'indri',
		  numero  => 34,
		  cero    => '0',
		  numeroCero => 0,
		  );

    setCgiParams($cgi, %params);

    my $cgiParamsHash = $cgi->paramsAsHash();

    is_deeply(\%params, $cgiParamsHash, 'Checking return value of paramsAsHash')
}

sub validateParamsTestWithRegularCases
{
    my @correctCases = @{ cgiParametersCorrectCases() };
    my @deviantCases = @{ cgiParametersDeviantCases() };

    foreach my $case_r (@correctCases) {
	my $cgi = new EBox::CGI::DumbCGI;
	my @params = @{ $case_r };
	setCgiParams($cgi, @params);

	lives_ok { $cgi->_validateParams()  } "Checking parameters validation with correct parameters: @params";
    }
 

    foreach my $case_r (@deviantCases) {
	my $cgi = new EBox::CGI::DumbCGI;
	my @params = @{ $case_r };
	setCgiParams($cgi, @params);

	dies_ok { $cgi->_validateParams()  } "Checking parameters validation with deviant parameters: @params";
    }
}

sub validateParamsTestWithFlexibleCases
{
    my @deviantCases = (
			[],  # none parameter
			 ['mandatoryParameterEa'], # one mandatory alone
 			 ['mandatoryParameter', 'macacoA'], 
			# extra params:
			 ['mandatoryParameter3', '8macaco', 'hoolibuz'], 
			 ['mandatoryParameter3', 'supermacaco', 'mandatoryParameter'],
		    );
    my @straightCases = (
			 ['mandatoryParameterZ', 'macacoA'], 
			 ['mandatoryParameter1', 'forevermacacoforever'], 
			 ['mandatoryParametermacaco'],   # this lone param makes two matches. For now we consider it correct...
			 ['mandatoryParameter1', 'foomacaco'], 
			 # various mandatory matches:
			 ['mandatoryParameter1', 'foomacaco', 'mandatoryParameterGibon'],
			 # adding optionals:
			 ['mandatoryParameter1', 'foomacaco', 'fooop1'], 
			 ['mandatoryParameter1', 'foomacaco', 'mandatoryParameterGibon', 'chimop1'],
			 ['mandatoryParameter1', 'foomacaco', 'fooop1', 'barop1'], 
			 ['mandatoryParameter1', 'foomacaco', 'mandatoryParameterGibon', 'chimop1', 'titiop7'],
			 );

    my $prepareCgi_r = sub {
	my ($case_r) = @_;
	my $cgi = new EBox::CGI::FlexibleOptions;
	my @params = map { ($_ => 1)  } @{ $case_r };
	setCgiParams($cgi, @params);
	
	return $cgi;
    };

    foreach my $case_r (@straightCases) {
	my $cgi = $prepareCgi_r->($case_r);
	lives_ok { $cgi->_validateParams()  } "Checking parameters validation with correct parameters: @{$case_r}";
    }
    
    foreach my $case_r (@deviantCases) {
	my $cgi = $prepareCgi_r->($case_r);
	dies_ok { $cgi->_validateParams()  } "Checking parameters validation with deviant parameters: @{$case_r}";
    }
    
}

sub processTest
{
    my @correctCases = @{ cgiParametersCorrectCases() };
    
    foreach my $case_r (@correctCases) {
	my $cgi = new EBox::CGI::DumbCGI;
	my @cgiParams = @{ $case_r };
	my @expectedMasonParametes = @cgiParams;

	setCgiParams($cgi, @cgiParams);
	lives_ok { $cgi->_process() } "Checking error-free cgi run";
	cgiErrorNotOk($cgi, 'Checking that not error has been found in the cgi');
	checkMasonParameters($cgi, wantedParameters => {@expectedMasonParametes});
    }

    my @deviantCases = (
			# first, puck up all the incorrect parameters cases
			@{ cgiParametersDeviantCases() },
			# then add forceError parameter in all parameters correct cases
			map {
			    my %case = @{$_};
			    $case{forceError} = 1;
			    [%case]
			} @{ cgiParametersCorrectCases() },
			);

    foreach my $case_r (@deviantCases) {
	my $cgi = new EBox::CGI::DumbCGI;
	my @cgiParams = @{ $case_r };
	my @expectedMasonParametes =  (@cgiParams, errorFound => 1);

	setCgiParams($cgi, @cgiParams);
	lives_ok { $cgi->_process() } 'Checking that cgi with error does not throw any exception';
	cgiErrorOk($cgi, 'Checking that error is correctly marked');
	checkMasonParameters($cgi, wantedParameters => {@expectedMasonParametes}, testName => 'Checking mason parameters for CGI with error');
    }
    

    # masonParameter dies case
    my @deviantMasonCases = map   {    
                                   my @case = @{ $_ };
                                   push @case, (masonFails =>  1); 
				   [ @case ];  
				 } (
				    # exception only in masonParameters
				    @correctCases[0, 1], 
				    # exception both in actuate and in  masonParameters
				    @deviantCases[-1, -2],  # we pick the last two because they have good cgi parameters
				   );

    foreach my $case_r (@deviantMasonCases) {
	my $cgi = new EBox::CGI::DumbCGI;
	my @cgiParams = @{ $case_r };

	setCgiParams($cgi, @cgiParams);
	lives_ok { $cgi->_process() } 'Checking that cgi with masonParameters error  does not throw any exception';
	cgiErrorOk($cgi, 'Checking wether error is correctly marked');
	checkMasonParameters($cgi, wantedParameters => { }, testName => 'Checking mason parameters for CGI with masonParameters aborted ');
    }


}


sub cgiParametersCorrectCases
{

  my @requiredParams = @{   EBox::CGI::DumbCGI::requiredParameters() };
  my @optionalParams = grep  { ($_ ne 'forceError') and ($_ ne 'masonFails') }  @{ EBox::CGI::DumbCGI::optionalParameters() };

 my @correctCases = (
			[ map { $_ => 'req'  } @requiredParams ] ,
 			[ (map { $_ => 'req'  } @requiredParams), map { ($_ => 'opt')  } @optionalParams, ] ,
		    	[ (map { $_ => 'req'  } @requiredParams), map { $_ => 'opt'  }  (grep { $_ =~ m/[12]/ }  @optionalParams) ] ,
		        [ (map { $_ => 'req'  } @requiredParams), map { $_ => 'opt'  }  (grep { $_ =~ m/3/ }  @optionalParams) ] ,
     );

  return \@correctCases;
}


sub cgiParametersDeviantCases
{
  my @requiredParams = @{ EBox::CGI::DumbCGI::requiredParameters() };
  my @optionalParams = grep { $_ ne 'masonFails'  } @{  EBox::CGI::DumbCGI::optionalParameters() };

   my @deviantCases = (
			# no parameters
			[],
			# only optional parameters
			[map { $_ => 'opt' }   @optionalParams ],
			# missing required parameters
			[ map { $_ => 'req'  } grep { m/[12]/  }  @requiredParams ] ,
			# extra parameters
			[ (map { $_ => 'req'  }  @requiredParams), 'extraParameter' => 1 ] ,
			);

  return \@deviantCases;
}

package EBox::CGI::DumbCGI;
use lib '../../..';
use base 'EBox::CGI::Base';
use Test::More;

sub new 
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);

    bless $self, $class;
    return $self;
}


sub actuate
{
    my ($self) = @_;

    my $errorParam = $self->param('forceError');


    if (defined $errorParam) {
	throw EBox::Exceptions::External $errorParam;
    }
}

sub optionalParameters
{
    return [qw(forceError optional1 optional2 masonFails)];
}

sub requiredParameters
{
    return [qw(required1 required2 required3)];
}

# echoes the cgi parameters as mason parameters and adds (errorFound => 1) if cgi has any error
#  with masonFails  parameter it eill throw exception (regardless of his value)
sub masonParameters
{
    my ($self) = @_;

    my @names = @{ $self->params() };

    my $masonFails = grep { $_ eq 'masonFails' } @names;
    if ($masonFails) {
      throw EBox::Exceptions::External 'masonParameters failed';
    }

    my @params = map { $_ => $self->param($_) } @names; 

    my $error    = $self->{error};
    my $oldError = $self->{olderror};

    if (defined $error  or (defined $oldError)) {
	push @params, ( errorFound => 1);
    }

    return \@params;
}

# to eliminate html output while running cgi:
sub _print
{}



package EBox::CGI::FlexibleOptions;
use base 'EBox::CGI::Base';

sub new 
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);

    bless $self, $class;
    return $self;
}

sub requiredParameters
{
    return [
	      'mandatoryParameter\w+', # anything that start with 'mandatory and continues with word chars
	      '.*macaco.*'  # anything that has the string macaco on it
	    ];
}

sub optionalParameters
{
    return [
	    '.*op\d'  # anything that ends whit 'op' + digit
	    ];
}

1;
