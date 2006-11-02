package Perl6::Junction::Any;
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


sub any {
	my ($proto, @param) = @_;
	
	return bless \@param, $proto;
}


sub num_eq {
  return regex_eq(@_) if ref($_[1]) eq 'Regexp';
  
	my ($self, $test) = @_;
	
	for (@$self) {
		return 1 if $_ == $test;
	}
	
	return;
}


sub num_ne {
  return regex_ne(@_) if ref($_[1]) eq 'Regexp';
  
	my ($self, $test) = @_;
	
	for (@$self) {
		return 1 if $_ != $test;
	}
	
	return;
}


sub num_ge {
	my ($self, $test, $switch) = @_;
	
	return num_le($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ >= $test;
	}
	
	return;
}


sub num_gt {
	my ($self, $test, $switch) = @_;
	
	return num_lt($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ > $test;
	}
	
	return;
}


sub num_le {
	my ($self, $test, $switch) = @_;
	
	return num_ge($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ <= $test;
	}
	
	return;
}


sub num_lt {
	my ($self, $test, $switch) = @_;
	
	return num_gt($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ < $test;
	}
	
	return;
}


sub str_eq {
	my ($self, $test) = @_;
	
	for (@$self) {
		return 1 if $_ eq $test;
	}
	
	return;
}


sub str_ne {
	my ($self, $test) = @_;
	
	for (@$self) {
		return 1 if $_ ne $test;
	}
	
	return;
}


sub str_ge {
	my ($self, $test, $switch) = @_;
	
	return str_le($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ ge $test;
	}
	
	return;
}


sub str_gt {
	my ($self, $test, $switch) = @_;
	
	return str_lt($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ gt $test;
	}
	
	return;
}


sub str_le {
	my ($self, $test, $switch) = @_;
	
	return str_ge($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ le $test;
	}
	
	return;
}


sub str_lt {
	my ($self, $test, $switch) = @_;
	
	return str_gt($self, $test) if $switch;
	
	for (@$self) {
		return 1 if $_ lt $test;
	}
	
	return;
}


sub regex_eq {
  my ($self, $test, $switch) = @_;
  
  for (@$self) {
		return 1 if $_ =~ $test;
	}
	
	return;
}


sub regex_ne {
  my ($self, $test, $switch) = @_;
  
  for (@$self) {
		return 1 if $_ !~ $test;
	}
	
	return;
}


1;

