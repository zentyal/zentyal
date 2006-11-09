use strict;

package Test::NoWarnings::Warning;

use Carp;

my $has_st = eval "require Devel::StackTrace" || 0;

sub new
{
	my $pkg = shift;

	my %args = @_;

	my $self = bless \%args, $pkg;

	return $self;
}

sub getTrace
{
	my $self = shift;

	return $self->{Trace};
}

sub fillTrace
{
	my $self = shift;
	$self->{Trace} = Devel::StackTrace->new(
		ignore_class => [__PACKAGE__, @_],
	) if $has_st;
}

sub getCarp
{
	my $self = shift;

	return $self->{Carp};
}

sub fillCarp
{
	my $self = shift;

	my $msg = shift;

	$Carp::Internal{__PACKAGE__.""}++;
	local $Carp::CarpLevel = $Carp::CarpLevel + 1;
	$self->{Carp} = Carp::longmess($msg);
	$Carp::Internal{__PACKAGE__.""}--;
}

sub getMessage
{
	my $self = shift;

	return $self->{Message};
}

sub setMessage
{
	my $self = shift;

	$self->{Message} = shift;
}

sub fillTest
{
	my $self = shift;

	my $builder = shift;

	my $prev_test = $builder->current_test;
	$self->{Test} = $prev_test;

	my @tests = $builder->details;
	my $prev_test_name = $prev_test ? $tests[$prev_test - 1]->{name} : "";
	$self->{TestName} =  $prev_test_name;
}

sub getTest
{
	my $self = shift;

	return $self->{Test};
}

sub getTestName
{
	my $self = shift;

	return $self->{TestName};
}

sub toString
{
	my $self = shift;

	return <<EOM;
	Previous test $self->{Test} '$self->{TestName}'
	$self->{Carp}
EOM
}

1;
