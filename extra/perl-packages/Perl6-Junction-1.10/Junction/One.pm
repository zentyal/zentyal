package Perl6::Junction::One;
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


sub one {
	my ($class, @param) = @_;
	
	return bless \@param, $class;
}


sub num_eq {
  return regex_eq(@_) if ref($_[1]) eq 'Regexp';
  
	my ($self, $test) = @_;
	my $count = 0;
	
	for (@$self) {
		if ($_ == $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub num_ne {
  return regex_ne(@_) if ref($_[1]) eq 'Regexp';
  
	my ($self, $test) = @_;
	my $count = 0;
	
	for (@$self) {
		if ($_ != $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub num_ge {
	my ($self, $test, $switch) = @_;
	
	return num_le($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ >= $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub num_gt {
	my ($self, $test, $switch) = @_;
	
	return num_lt($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ > $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub num_le {
	my ($self, $test, $switch) = @_;
	
	return num_ge($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ <= $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub num_lt {
	my ($self, $test, $switch) = @_;
	
	return num_gt($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ < $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_eq {
	my ($self, $test) = @_;
	my $count = 0;
	
	for (@$self) {
		if ($_ eq $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_ne {
	my ($self, $test) = @_;
	my $count = 0;
	
	for (@$self) {
		if ($_ ne $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_ge {
	my ($self, $test, $switch) = @_;
	
	return str_le($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ ge $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_gt {
	my ($self, $test, $switch) = @_;
	
	return str_lt($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ gt $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_le {
	my ($self, $test, $switch) = @_;
	
	return str_ge($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ le $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub str_lt {
	my ($self, $test, $switch) = @_;
	
	return str_gt($self, $test) if $switch;
	
	my $count = 0;
	
	for (@$self) {
		if ($_ lt $test) {
			return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub regex_eq {
  my ($self, $test, $switch) = @_;
  
  my $count = 0;
  
  for (@$self) {
		if ($_ =~ $test) {
		  return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


sub regex_ne {
  my ($self, $test, $switch) = @_;
  
  my $count = 0;
  
  for (@$self) {
		if ($_ !~ $test) {
		  return if $count;
			$count = 1;
		}
	}
	
	return 1 if $count;
}


1;

