use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply({key1 => "a", key2 => "b"}, {key1 => "a", key2 => "b"},
				"hash eq");
		},
		{
			name => "hash eq",
			actual_ok => 1,
			diag => "",
		}
	);
	check_test(
		sub {
			cmp_deeply({key1 => "a", key2 => "b"}, {key1 => "a", key2 => "c"},
				"hash not eq");
		},
		{
			name => "hash not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->{"key2"}
   got : 'b'
expect : 'c'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply({key1 => "a"}, {key1 => "a", key2 => "c"},
				"hash got DNE");
		},
		{
			name => "hash got DNE",
			actual_ok => 0,
			diag => <<EOM,
Comparing hash keys of \$data
Missing: 'key2'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply({key1 => "a", key2 => "c"}, {key1 => "a"},
				"hash expected DNE");
		},
		{
			name => "hash expected DNE",
			actual_ok => 0,
			diag => <<EOM,
Comparing hash keys of \$data
Extra: 'key2'
EOM
		}
	);

	check_test(
		sub {
			cmp_deeply({key1 => "a", key2 => "c"}, superhashof({key1 => "a"}),
				"superhash ok");
		},
		{
			name => "superhash ok",
			actual_ok => 1,
			diag => "",
		}
	);

	check_test(
		sub {
			cmp_deeply({key1 => "a"}, subhashof({key1 => "a", key2 => "c"}),
				"subhash ok");
		},
		{
			name => "subhash ok",
			actual_ok => 1,
			diag => "",
		}
	);
}
