use strict;
use warnings;

use t::std;

{
	my $a = [];
	check_test(
		sub {
			cmp_deeply($a."", $a);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared reftype(\$data)
   got : undef
expect : 'ARRAY'
EOM
		},
		"stringified ref not eq"
	);

	check_test(
		sub {
			cmp_deeply(undef, "");
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data
   got : undef
expect : ''
EOM
		},
		"undef ne ''"
	);

	check_test(
		sub {
			cmp_deeply([$a."", ["b"]], [shallow($a), ["b"]]);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->[0]
   got : '$a'
expect : $a
EOM
		},
		"shallow not eq"
	);

	check_test(
		sub {
			cmp_deeply([$a, ["b"]], [shallow($a), ["a"]]);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->[1][0]
   got : 'b'
expect : 'a'
EOM
		},
		"deep after shallow not eq"
	);
}
