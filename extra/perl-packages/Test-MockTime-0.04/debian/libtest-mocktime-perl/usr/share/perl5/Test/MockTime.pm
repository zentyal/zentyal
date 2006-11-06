package Test::MockTime;

use strict;
use warnings;
use Carp();
use Time::Piece();
use Exporter 'import';
our @EXPORT_OK = qw(
    set_relative_time
    set_absolute_time
    set_fixed_time
    restore_time
);
our %EXPORT_TAGS = (
    'all' => \@EXPORT_OK,
);
our ($VERSION) = '0.04';
our ($offset) = 0;
our ($fixed) = undef;

BEGIN {
	*CORE::GLOBAL::time = \&Test::MockTime::time;
	*CORE::GLOBAL::localtime = \&Test::MockTime::localtime;
	*CORE::GLOBAL::gmtime = \&Test::MockTime::gmtime;
}

sub set_relative_time {
	my ($relative) = @_;
	if (($relative eq __PACKAGE__) || (UNIVERSAL::isa($relative, __PACKAGE__))) {
		Carp::carp("Test::MockTime::set_relative_time called incorrectly\n");
	}
	$offset = $_[-1]; # last argument. might have been called in a OO syntax?
}

sub _time {
	my ($time, $spec) = @_;
	unless ($time =~ /\A -? \d+ \z/xms) {
		$spec ||= '%Y-%m-%dT%H:%M:%SZ';
	}
	if ($spec) {
		$time = Time::Piece->strptime($time, $spec)->epoch();
	}
	return $time;
}

sub set_absolute_time {
	my ($time, $spec) = @_;
	if (($time eq __PACKAGE__) || (UNIVERSAL::isa($time, __PACKAGE__))) {
		Carp::carp("Test::MockTime::set_absolute_time called incorrectly\n");
	}
	$time = _time($time, $spec);
	$offset = $time - CORE::time;
}

sub set_fixed_time {
	my ($time, $spec) = @_;
	if (($time eq __PACKAGE__) || (UNIVERSAL::isa($time, __PACKAGE__))) {
		Carp::carp("Test::MockTime::set_fixed_time called incorrectly\n");
	}
	$time = _time($time, $spec);
	$fixed = $time;
}

sub time { 
	if (defined $fixed) {
		return $fixed;
	} else {
		return (CORE::time + $Test::MockTime::offset);
	}
}

sub localtime {
	my ($time) = @_;
	unless (defined $time) {
		$time = Test::MockTime::time();
	}
	return CORE::localtime($time);
}

sub gmtime {
	my ($time) = @_;
	unless (defined $time) {
		$time = Test::MockTime::time();
	}
	return CORE::gmtime($time);;
}

sub restore {
	$offset = 0;
	$fixed = undef;
}
*restore_time = \&restore;
