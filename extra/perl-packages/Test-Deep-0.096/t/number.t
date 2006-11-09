use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply(1, num(1));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"number eq"
	);

	check_test(
		sub {
			cmp_deeply(1, num(2))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a number
   got : 1
expect : 2
EOM
		},
		"number not eq"
	);

	check_test(
		sub {
			cmp_deeply("1a", num("1"))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"funny number eq"
	);

	check_test(
		sub {
			cmp_deeply("1a", num(2))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a number
   got : 1 ('1a')
expect : 2
EOM
		},
		"funny number not eq"
	);

}

{
	check_test(
		sub {
			cmp_deeply(1, num(1, 1));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"number tolerance eq"
	);

	check_test(
		sub {
			cmp_deeply(1, num(2, .5))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a number
   got : 1
expect : 2 +/- 0.5
EOM
		},
		"number tolerance not eq"
	);
}

{
	require "t/over.pm";

	my $o = Over->new(1);

	check_test(
		sub {
			cmp_deeply($o, num(1))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"over number eq"
	);

	check_test(
		sub {
			cmp_deeply($o, num(2))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a number
   got : 1
expect : 2
EOM
		},
		"over number not eq"
	);
}
