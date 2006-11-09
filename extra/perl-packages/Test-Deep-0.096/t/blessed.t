use strict;
use warnings;

use t::std;

{
	my $b = bless [], "class";
	check_test(
		sub {
			cmp_deeply($b, blessed("class"));
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"Same"
	);

	check_test(
		sub {
			cmp_deeply($b, blessed("other"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared blessed(\$data)
   got : 'class'
expect : 'other'
EOM
		},
		"Same"
	);
}

{
	check_test(
		sub {
			cmp_deeply([], blessed());
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"Same"
	);

	check_test(
		sub {
			cmp_deeply([], blessed("class"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared blessed(\$data)
   got : undef
expect : 'class'
EOM
		},
		"Same"
	);
}
