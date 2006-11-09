use strict;
use warnings;

use t::std;

{
	my $re = qr/^wi/;
	check_test(
		sub {
			cmp_deeply(
				{ a => 'wine', b => 'wind', c => 'wibble'},
				hash_each( re($re) )
			)
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"hash_each eq"
	);

	check_test(
		sub {
			cmp_deeply(
				{ a => 'wine', b => 'wand', c => 'wibble'},
				hash_each( re($re) )
			)
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Using Regexp on \$data->{"b"}
   got : 'wand'
expect : $re
EOM
		},
		"hash_each not eq"
	);
}
