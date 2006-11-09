use strict;

use Test::Tester;

use Test::More qw(no_plan);

use Test::NoWarnings qw( had_no_warnings warnings clear_warnings );

Test::NoWarnings::builder(Test::Tester::capture());

sub a
{
	&b;
}

sub b
{
	warn shift;
}

{
	check_test(
		sub {
			had_no_warnings("check warns");
		},
		{
			actual_ok => 1,
		},
		"no warns"
	);

	my ($prem, $result) = check_test(
		sub {
			a("hello there");
			had_no_warnings("check warns");
		},
		{
			actual_ok => 0,
		},
		"1 warn"
	);

	like($result->{diag}, '/^There were 1 warning\\(s\\)/', "1 warn diag");
	like($result->{diag}, "/Previous test 0 ''/", "1 warn diag test num");
	like($result->{diag}, '/hello there/', "1 warn diag has warn");

	my ($warn) = warnings();

	# 5.8.5 changed Carp's behaviour when the string ends in a \n
	my $base = $Carp::VERSION >= 1.03; 

	my @carp = split("\n", $warn->getCarp);

	like($carp[$base+1], '/main::b/', "carp level b");
	like($carp[$base+2], '/main::a/', "carp level a");

	SKIP: {
		my $has_st = eval "require Devel::StackTrace" || 0;

		skip("Devel::StackTrace not installed", 1) unless $has_st;
		isa_ok($warn->getTrace, "Devel::StackTrace");
	}
}

{
	clear_warnings();
	check_test(
		sub {
			had_no_warnings("check warns");
		},
		{
			actual_ok => 1,
		},
		"clear warns"
	);

	my ($prem, $empty_result, $result) = check_tests(
		sub {
			had_no_warnings("check warns empty");
			warn "hello once";
			warn "hello twice";
			had_no_warnings("check warns");
		},
		[
			{
				actual_ok => 1,
			},
			{
				actual_ok => 0,
			},
		],
		"2 warn"
	);

	like($result->{diag}, '/^There were 2 warning\\(s\\)/', "2 warn diag");
	like($result->{diag}, "/Previous test 1 'check warns empty'/", "2 warn diag test num");
	like($result->{diag}, '/hello once.*hello twice/s', "2 warn diag has warn");
}

