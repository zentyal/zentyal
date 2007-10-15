package EBox::Squid::Types::Policy;
use base 'EBox::Types::Select';

use strict;
use warnings;

use EBox::Gettext;

use Perl6::Junction qw(all);

my $allPolicies = all qw(allow deny filter);

sub new
{
  my ($class, %params) = @_;

  if (not exists $params{defaultValue}) {
    $params{defaultValue} = 'allow';
  }

  $params{editable} = 1;
  $params{populate} = \&_populate;

  my $self = $class->SUPER::new(%params);

  bless $self, $class;
  return $self;
}


sub _populate
{
  my @elements = (
		  { value => 'allow',  printableValue => __('Unfilter') },
		  { value => 'filter', printableValue => __('Filter') },
		  { value => 'deny',   printableValue => __('Deny') },
		 );

  return \@elements;
}


sub _paramIsValid
{
  my ($self, $params) = @_;
  
  my $value = $params->{$self->fieldName()};
  $self->checkPolicy($value);
}

sub checkPolicy
{
  my ($class, $policy) = @_;
  if ($policy ne $allPolicies) {
    throw EBox::Exceptions::InvalidData(
					data  => __(q{Squid's policy}),
					value => $policy,
				       );
  }
}


1;
