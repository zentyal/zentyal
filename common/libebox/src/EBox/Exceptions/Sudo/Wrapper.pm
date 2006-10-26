package EBox::Exceptions::Sudo::Wrapper;
use base 'EBox::Exceptions::Sudo::Base';
# package:
#   this class exists to notify any sudo error which does not relates to the exceutiomn of the actual command (sudoers error, bad command, etc..)
use strict;
use warnings;

sub new 
{
  my $class = shift @_;

  local $Error::Depth = $Error::Depth + 1;
  local $Error::Debug = 1;
  
  $Log::Log4perl::caller_depth += 1;
  my $self = $class->SUPER::new(@_);
  $Log::Log4perl::caller_depth -= 1;
  
  bless ($self, $class);
  
  return $self;
}

1;
