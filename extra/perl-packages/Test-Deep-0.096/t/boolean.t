use strict;
use warnings;

use t::std;

{
	check_tests(
		sub {
			cmp_deeply(1, bool(1), "num 1");
			cmp_deeply("abds", bool(1), "string");
			cmp_deeply(0, bool(0), "num 0");
			cmp_deeply("", bool(0), "string");
		},
		[
			({
				actual_ok => 1,
				diag => "",
			}) x 4
		],
		"ok"
	);

	check_tests(
		sub {
			cmp_deeply(1, bool(0), "num 1");
			cmp_deeply("abds", bool(0), "string");
			cmp_deeply(0, bool(1), "num 0");
			cmp_deeply("", bool(1), "string");
		},
		[
			{
				actual_ok => 0,
				diag => <<EOM,
Comparing \$data as a boolean
   got : true ('1')
expect : false ('0')
EOM
			},
			({
				actual_ok => 0,
			}) x 3,
		],
		"string not eq"
	);
}
