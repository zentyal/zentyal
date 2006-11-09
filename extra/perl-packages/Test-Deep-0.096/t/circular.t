use strict;
use warnings;

use t::std;

{
	my $a1 = gen_layers(2);
	my $a2 = gen_layers(2);

	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"2 layers"
	);

	push(@$a1, "break");
	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared array length of \$data
   got : array with 4 element(s)
expect : array with 3 element(s)
EOM
		},
		"2 layers broken"
	);
	push(@$a2, "break");
	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"2 layers fixed"
	);
}

{
	my $a1 = gen_layers(2);
	my $a2 = gen_layers(3);

	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"2 and 3 layers"
	);
	push(@$a1, "break");
	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared array length of \$data
   got : array with 4 element(s)
expect : array with 3 element(s)
EOM
		},
		"2 and 3 layers broken"
	);
	push(@$a2, "break");
	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared array length of \$data->[2][2]
   got : array with 4 element(s)
expect : array with 3 element(s)
EOM
		},
		"2 and 3 layers not fixed"
	);
}

{
	my $a1 = gen_interleave();
	my $a2 = gen_interleave();

	check_test(
		sub {
			cmp_deeply($a1, $a2);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"interleave"
	);
}

sub gen_layers
{
	my $num = shift;

	my $first = ['text', gen_circle()];
	$num--;
	my $last = $first;
	while ($num--)
	{
		my $next = ['text', gen_circle()];
		push(@$last, $next);
		$last = $next;
	}

	push(@$last, $first);
	return $first
}

sub gen_circle
{
	my $a = ['circle'];
	push(@$a, $a);
	return $a
}

sub gen_interleave
{
	my $a = [];
	my $b = [];
	
	push(@$a, $b, $a);
	push(@$b, $a, $b);
	
	return $a;
}
