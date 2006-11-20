package EBox::Exceptions::Sudo::Command;
use base 'EBox::Exceptions::Sudo::Base';
# package:
#   this class exists to notify any sudo error which does not relates to the exceutiomn of the actual command (sudoers error, bad command, etc..)
use strict;
use warnings;

sub new 
{
  my $class  = shift @_;
  my %params = @_;
  my $self;

  my $cmd    = $params{cmd};
  my $output = exists $params{output} ? $params{output} : [];
  my $error = exists $params{error} ? $params{error} : [];
  my $exitValue = $params{exitValue};
  

  local $Error::Depth = $Error::Depth + 1;
  local $Error::Debug = 1;
  
# we need this ugly workaround because Excpeions::Internal constructor logs the error parameter
  my $errorMsg = _errorMsg($cmd, $error, $output, $exitValue);

  $Log::Log4perl::caller_depth += 1;
  $self = $class->SUPER::new($errorMsg);
  $Log::Log4perl::caller_depth -= 1;
  
  bless ($self, $class);
  $self->{output} = $output;
  $self->{error}  = $error;
  $self->{exitValue} = $exitValue;

  return $self;
}



sub _errorMsg
{
  my ($cmd, $error, $output, $exitValue) = @_;
  my $errorStr = join ' ', @{ $error };
  my $outputStr = join ' ', @{ $output };

  return "Root command $cmd failed. \nError output: $errorStr\nCommand output: $outputStr. \nExit value: $exitValue";
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
