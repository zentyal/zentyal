package Perl6::Junction::All;
use strict;
our $VERSION = '1.10';

use overload(
	'=='  => \&num_eq,
	'!='  => \&num_ne,
	'>='  => \&num_ge,
	'>'   => \&num_gt,
	'<='  => \&num_le,
	'<'   => \&num_lt,
	'eq'  => \&str_eq,
	'ne'  => \&str_ne,
	'ge'  => \&str_ge,
	'gt'  => \&str_gt,
	'le'  => \&str_le,
	'lt'  => \&str_lt,
	);


sub all {
	my ($proto, @param) = @_;
	
	return bless \@param, $proto;
}


sub num_eq {
	return regex_eq(@_) if ref($_[1]) eq 'Regexp';
	
	my ($self, $test) = @_;
	
	for (@$self) {
		return unless $_ == $test;
	}
	
	return 1;
}


sub num_ne {
	return regex_ne(@_) if ref($_[1]) eq 'Regexp';
	
	my ($self, $test) = @_;
	
	for (@$self) {
		return unless $_ != $test;
	}
	
	return 1;
}


sub num_ge {
	my ($self, $test, $switch) = @_;
	
	return num_le($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ >= $test;
	}
	
	return 1;
}


sub num_gt {
	my ($self, $test, $switch) = @_;
	
	return num_lt($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ > $test;
	}
	
	return 1;
}


sub num_le {
	my ($self, $test, $switch) = @_;
	
	return num_ge($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ <= $test;
	}
	
	return 1;
}


sub num_lt {
	my ($self, $test, $switch) = @_;
	
	return num_gt($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ < $test;
	}
	
	return 1;
}


sub str_eq {
	my ($self, $test) = @_;
	
	for (@$self) {
		return unless $_ eq $test;
	}
	
	return 1;
}


sub str_ne {
	my ($self, $test) = @_;
	
	for (@$self) {
		return unless $_ ne $test;
	}
	
	return 1;
}


sub str_ge {
	my ($self, $test, $switch) = @_;
	
	return str_le($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ ge $test;
	}
	
	return 1;
}


sub str_gt {
	my ($self, $test, $switch) = @_;
	
	return str_lt($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ gt $test;
	}
	
	return 1;
}


sub str_le {
	my ($self, $test, $switch) = @_;
	
	return str_ge($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ le $test;
	}
	
	return 1;
}


sub str_lt {
	my ($self, $test, $switch) = @_;
	
	return str_gt($self, $test) if $switch;
	
	for (@$self) {
		return unless $_ lt $test;
	}
	
	return 1;
}


sub regex_eq {
  my ($self, $test, $switch) = @_;
  
  for (@$self) {
		return unless $_ =~ $test;
	}
	
	return 1;
}


sub regex_ne {
  my ($self, $test, $switch) = @_;
  
  for (@$self) {
		return unless $_ !~ $test;
	}
	
	return 1;
}


1;

