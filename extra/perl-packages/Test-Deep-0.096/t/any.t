use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply("wine", any("beer", "wine"))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"any eq"
	);

	check_test(
		sub {
			cmp_deeply("whisky", any("beer", "wine"))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data with Any
got      : 'whisky'
expected : Any of ( 'beer', 'wine' )
EOM
		},
		"any not eq"
	);

	check_test(
		sub {
			cmp_deeply("whisky", any("beer") | "wine")
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data with Any
got      : 'whisky'
expected : Any of ( 'beer', 'wine' )
EOM
		},
		"any with |"
	);

	check_tests(
		sub {
			cmp_deeply("whisky", re("isky") | "wine", "pass");
			cmp_deeply("whisky", re("iskya") | "wine", "fail")
		},
		[
			{ actual_ok => 1 },
			{ actual_ok => 0 }
		],
		"| without any"
	);

}
