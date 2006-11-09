use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply(qr/a/, qr/a/, "regexp ref eq");
		},
		{
			name => "regexp ref eq",
			actual_ok => 1,
			diag => "",
		}
	);
	check_test(
		sub {
			cmp_deeply(qr/a/, qr/b/, "regexp ref not eq");
		},
		{
			name => "regexp ref not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared m/\$data/
   got : (?-xism:a)
expect : (?-xism:b)
EOM
		}
	);
}
