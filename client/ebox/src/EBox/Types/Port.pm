package EBox::Types::Port;
use base 'EBox::Types::Int';
#
use strict;
use warnings;

use EBox::Validate;

sub new
{
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  $self->{type} = 'port';

  bless($self, $class);
  return $self;
}

# Method: _paramIsValid
#
#     Check if the params has a correct port
#
# Overrides:
#
#     <EBox::Types::Int::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct pot
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       port
#
sub _paramIsValid
  {
      my ($self, $params) = @_;

      my $value = $params->{$self->fieldName()};

      if (defined ( $value )) {
	  EBox::Validate::checkPort($value, $self->printableName());
      }

      return 1;

  }



1;
