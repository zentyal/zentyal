use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply([], reftype("ARRAY"));
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"ARRAY ok"
	);

	check_test(
		sub {
			cmp_deeply([], reftype("HASH"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared reftype(\$data)
   got : 'ARRAY'
expect : 'HASH'
EOM
		},
		"ARRAY"
	);
}
