use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply("a", "a", "scalar eq");
		},
		{
			name => "scalar eq",
			actual_ok => 1,
			diag => "",
		}
	);

	check_test(
		sub {
			cmp_deeply("a", "b", "scalar not eq");
		},
		{
			name => "scalar not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared \$data
   got : 'a'
expect : 'b'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply("a", undef, "def undef");
		},
		{
			name => "def undef",
			actual_ok => 0,
			diag => <<EOM,
Compared \$data
   got : 'a'
expect : undef
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply(undef, "a", "undef def");
		},
		{
			name => "undef def",
			actual_ok => 0,
			diag => <<EOM,
Compared \$data
   got : undef
expect : 'a'
EOM
		}
	);
	check_test(
		sub {
			cmp_deeply(undef, undef, "undef undef");
		},
		{
			name => "undef undef",
			actual_ok => 1,
			diag => '',
		}
	);
	check_test(
		sub {
			cmp_deeply("", undef);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data
   got : ''
expect : undef
EOM
		},
		"scalar undef and blank"
	);
}

{
	check_test(
		sub {
			cmp_deeply(\\"a", \\"a", "ref ref eq");
		},
		{
			name => "ref ref eq",
			actual_ok => 1,
			diag => "",
		}
	);
	check_test(
		sub {
			cmp_deeply(\\"a", \\"b", "ref ref not eq");
		},
		{
			name => "ref ref not eq",
			actual_ok => 0,
			diag => <<EOM,
Compared \${\${\$data}}
   got : 'a'
expect : 'b'
EOM
		}
	);
}

{
	my @a;
	check_test(
		sub {
			cmp_deeply(\@a, \@a);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"equal refs"
	);
}

{
	my @a;
	check_test(
		sub {
			cmp_deeply(undef, \@a);
		},
		{
			actual_ok => 0,
		},
		"not calling StrVal on undef"
	);
}
