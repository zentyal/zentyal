use strict;
use warnings;

use t::std;

{
	my $str = "ferg";
	my $re = qr/$str/;
	check_test(
		sub {
			cmp_deeply("fergal", re($re));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"re eq"
	);

	check_test(
		sub {
			cmp_deeply("feargal", re($re));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Using Regexp on \$data
   got : 'feargal'
expect : $re
EOM
		},
		"re not eq"
	);

	check_test(
		sub {
			cmp_deeply("fergal", re($str));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"string re eq"
	);

	check_test(
		sub {
			cmp_deeply("feargal", re($str));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Using Regexp on \$data
   got : 'feargal'
expect : $re
EOM
		},
		"string runre not eq"
	);
}
{
	my $re = qr/([ac])/;
	check_test(
		sub {
			cmp_deeply("abc", re($re, [qw( a )]));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"matches re eq"
	);

	check_test(
		sub {
			cmp_deeply("abc", re($re, [qw( a c )], "g"));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"matches global re eq"
	);

	check_test(
		sub {
			cmp_deeply("abc", re($re, [qw( a b )], "g"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared [\$data =~ (?-xism:([ac]))]->[1]
   got : 'c'
expect : 'b'
EOM
		},
		"matches global not eq"
	);

}

{
	my $re = qr/(..)/;
	check_test(
		sub {
			cmp_deeply("abababcdcdefef", re($re, set(qw( ab cd ef )), "g"));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"matches re and set eq"
	);

	check_test(
		sub {
			cmp_deeply("cat=2,dog=67,sheep=3,goat=2,dog=5",
					re(qr/(\D+)=\d+,?/, set(qw( cat sheep dog )), "g"))
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing [\$data =~ (?-xism:(\\D+)=\\d+,?)] as a Set
Extra: 'goat'
EOM
		},
		"string runre not eq"
	);

}
