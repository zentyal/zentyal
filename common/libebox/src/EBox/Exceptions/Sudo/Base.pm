package EBox::Exceptions::Sudo::Base;
use base EBox::Exceptions::Internal;
# package: 
#  this package only exists to give sudo-related exceptions a common and exclusive parent 
use strict;
use warnings;


sub new 
{
  my $class = shift @_;
  return $class->SUPER::new(@_);
}

1;
