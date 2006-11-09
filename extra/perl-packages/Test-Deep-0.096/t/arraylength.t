use strict;
use warnings;

use t::std;

{
	check_tests(
		sub {
			cmp_deeply([], arraylength(0), "0");
			cmp_deeply([1..3], arraylength(3), "3");
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
		"len ok"
	);
	check_tests(
		sub {
			cmp_deeply({}, arraylength(2));
		},
		[
			{
				actual_ok => 0,
				diag => <<EOM,
Compared reftype(\$data)
   got : 'HASH'
expect : 'ARRAY'
EOM
			},
		],
		"bad reftype"
	);
	check_tests(
		sub {
			cmp_deeply([1], arraylength(2));
		},
		[
			{
				actual_ok => 0,
				diag => <<EOM,
Compared array length of \$data
   got : array with 1 element(s)
expect : array with 2 element(s)
EOM
			},
		],
		"bad length"
	);
	check_tests(
		sub {
			cmp_deeply("a", arraylength(0), "string");
			cmp_deeply({}, arraylength(0), "hash");
		},
		[
			{
				name => "string",
				actual_ok => 0,
				diag => <<EOM,
Compared reftype(\$data)
   got : undef
expect : 'ARRAY'
EOM
			},
			{
				name => "hash",
				actual_ok => 0,
				diag => <<EOM,
Compared reftype(\$data)
   got : 'HASH'
expect : 'ARRAY'
EOM
			},
		],
		"not array"
	);

	check_tests(
		sub {
			cmp_deeply([[1]], [arraylength(2)]);
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
