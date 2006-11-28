package EBox::Exceptions::Sudo::Command;
use base qw(EBox::Exceptions::Command EBox::Exceptions::Sudo::Base);

use strict;
use warnings;

sub new 
{
  my ($class, @constructorParams)  =  @_;
  push @constructorParams, (cmdType => 'root command');
 
  $Log::Log4perl::caller_depth += 1;
  my $self = $class->SUPER::new(@constructorParams);
  $Log::Log4perl::caller_depth -= 1;
  
  bless ($self, $class);
  return $self;
}




1;
