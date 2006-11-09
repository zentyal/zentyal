use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply(["a", "b"], ["a", "b"], "array eq");
		},
		{
			name => "array eq",
			actual_ok => 1,
			diag => "",
		}
	);
	check_test(
		sub {
			cmp_deeply(["a", "b"], ["a", "c"], "array not eq");
		},
		{
			name => "array not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->[1]
   got : 'b'
expect : 'c'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply(["a", "b"], ["a"], "array got DNE");
		},
		{
			name => "array got DNE",
			actual_ok => 0,
			diag => <<EOM,
Compared array length of \$data
   got : array with 2 element(s)
expect : array with 1 element(s)
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply(["a"], ["a", "b"], "array expected DNE");
		},
		{
			name => "array expected DNE",
			actual_ok => 0,
			diag => <<EOM,
Compared array length of \$data
   got : array with 1 element(s)
expect : array with 2 element(s)
EOM
		}
	);
	check_tests(
		sub {
			cmp_deeply([[1]], [[1, 2]]);
		},
		[
			{
				actual_ok => 0,
				diag => <<EOM,
Compared array length of \$data->[0]
   got : array with 1 element(s)
expect : array with 2 element(s)
EOM
			},
		],
		"deep bad length"
	);
}
