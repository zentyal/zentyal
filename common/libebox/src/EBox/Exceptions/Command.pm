package EBox::Exceptions::Command;
use base 'EBox::Exceptions::Internal';

use strict;
use warnings;

use Params::Validate qw(validate SCALAR ARRAYREF);

sub new 
{
  my $class  = shift @_;
  validate (@_, {
		 cmd => { type => SCALAR },
		 output => { type => ARRAYREF, default => []},
		 error =>  { type => ARRAYREF, default => []},
		 exitValue => { type => SCALAR },
		 cmdType => { type => SCALAR,  default => 'eBox command'},
		} 
	   );

  my %params = @_;
  my $self;

  my $cmd    = $params{cmd};
  my $output = $params{output} ;
  my $error = $params{error};
  my $exitValue = $params{exitValue};
  my $cmdType = $params{cmdType};
  

  local $Error::Depth = $Error::Depth + 1;
  local $Error::Debug = 1;
  
# we need this ugly workaround because Exceptions::Internal constructor logs the error parameter
  my $errorMsg = _errorMsg($cmdType, $cmd, $error, $output, $exitValue);

  $Log::Log4perl::caller_depth += 1;
  $self = $class->SUPER::new($errorMsg);
  $Log::Log4perl::caller_depth -= 1;

  $self->{cmd}    = $cmd;
  $self->{output} = $output;
  $self->{error}  = $error;
  $self->{exitValue} = $exitValue;

  bless ($self, $class);
  return $self;
}



sub _errorMsg
{
  my ($cmdType, $cmd, $error, $output, $exitValue) = @_;
  my $errorStr = join ' ', @{ $error };
  my $outputStr = join ' ', @{ $output };

  return "$cmdType $cmd failed. \nError output: $errorStr\nCommand output: $outputStr. \nExit value: $exitValue";
}

sub cmd
{
  my ($self) = @_;
  return $self->{cmd};
}

sub output
{
  my ($self) = @_;
  return $self->{output};
} 

sub error
{
  my ($self) = @_;
  return $self->{error};
} 

sub exitValue
{
  my ($self) = @_;
  return $self->{exitValue};
} 

1;
