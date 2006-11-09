use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply(["wine"], all( [re(qr/^wi/)], [re(qr/ne$/)], ["wine"]) )
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"all eq"
	);

	check_test(
		sub {
			cmp_deeply(["wine"], all( [re(qr/^wi/)], [re(qr/ne$/)], ["wines"]) )
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared (Part 3 of 3 in \$data)->[0]
   got : 'wine'
expect : 'wines'
EOM
		},
		"all not eq"
	);

	check_tests(
		sub {
			cmp_deeply("wine", all(re("^wi")) & re('ne$'), "pass");
			cmp_deeply("wine", all(re("^wi")) & re('na$'), "fail");
		},
		[
			{actual_ok => 1},
			{actual_ok => 0}
		],
		"all with &"
	);

	check_tests(
		sub {
			cmp_deeply("wine", re("^wi") & re('ne$'), "pass");
			cmp_deeply("wine", re("^wi") & re('na$'), "fail");
		},
		[
			{actual_ok => 1, diag => ""},
			{actual_ok => 0}
		],
		"& without all"
	);
}
