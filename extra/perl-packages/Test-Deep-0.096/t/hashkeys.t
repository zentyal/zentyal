use strict;
use warnings;

use t::std;

{
	check_tests(
		sub {
			cmp_deeply({}, hashkeys(), "0");
			cmp_deeply({1 => 2, 3 => 4, 5 => 6}, hashkeys(1, 3, 5), "3");
		},
		[
			{
				name => "0",
				actual_ok => 1,
				diag => "",
			},
			{
				name => "3",
				actual_ok => 1,
				diag => "",
			}
		],
		"keys ok"
	);
	check_tests(
		sub {
			cmp_deeply({a => 2, b => 4}, hashkeys("a", "c"));
		},
		[
			{
				actual_ok => 0,
				diag => <<EOM,
Comparing hash keys of \$data
Missing: 'c'
Extra: 'b'
EOM
			},
		],
		"bad length"
	);
	check_tests(
		sub {
			cmp_deeply("a", hashkeys(1), "string");
			cmp_deeply([], hashkeys(1), "array");
		},
		[
			{
				name => "string",
				actual_ok => 0,
				diag => <<EOM,
Compared reftype(\$data)
   got : undef
expect : 'HASH'
EOM
			},
			{
				name => "array",
				actual_ok => 0,
				diag => <<EOM,
Compared reftype(\$data)
   got : 'ARRAY'
expect : 'HASH'
EOM
			},
		],
		"not array"
	);
}
