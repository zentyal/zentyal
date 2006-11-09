use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply("wine", str("wine"))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"string eq"
	);

	check_test(
		sub {
			cmp_deeply("wine", str("wind"))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a string
   got : 'wine'
expect : 'wind'
EOM
		},
		"string not eq"
	);
}

{
	require "t/over.pm";

	my $o = Over->new("wine");

	check_test(
		sub {
			cmp_deeply($o, str("wine"))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"over string eq"
	);

	check_test(
		sub {
			cmp_deeply($o, str("wind"))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a string
   got : 'wine'
expect : 'wind'
EOM
		},
		"over string not eq"
	);
}
