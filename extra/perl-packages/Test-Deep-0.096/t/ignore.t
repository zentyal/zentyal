use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply([[{}, "argh"], ["b"]], [ignore(), ["b"]]);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"ignore"
	);
}
