use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply(\"a", \"a", "scalar ref eq");
		},
		{
			name => "scalar ref eq",
			actual_ok => 1,
			diag => "",
		}
	);
	check_test(
		sub {
			cmp_deeply(\"a", \"b", "scalar ref not eq");
		},
		{
			name => "scalar ref not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared \${\$data}
   got : 'a'
expect : 'b'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply({}, \"a", "scalar ref not ref");
		},
		{
			name => "scalar ref not ref",
			actual_ok => 0,
			diag => <<EOM,
Compared reftype(\$data)
   got : 'HASH'
expect : 'SCALAR'
EOM
		}
	);
}

