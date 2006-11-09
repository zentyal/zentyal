use strict;
use warnings;

use t::std;

{
	my $bless_a = bless {}, "A::Class";
	my $bless_b = bless {}, "B::Class";
	my $nobless = {};

	check_test(
		sub {
			cmp_deeply([$bless_a], [noclass($bless_b)]);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"no class eq"
	);

	check_test(
		sub {
			cmp_deeply([$bless_a], [noclass($nobless)]);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"no class eq unblessed"
	);

	check_test(
		sub {
			cmp_deeply([$bless_a], [$bless_b]);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared blessed(\$data->[0])
   got : 'A::Class'
expect : 'B::Class'
EOM
		},
		"class not eq"
	);

	check_test(
		sub {
			cmp_deeply([$bless_a], [$nobless]);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared blessed(\$data->[0])
   got : 'A::Class'
expect : undef
EOM
		},
		"class not eq unblessed"
	);

	my $bless_c = bless [$bless_a], "C::Class";

	check_test(
		sub {
			cmp_deeply(
				$bless_c,
				bless([noclass($nobless)], "C::Class")
			);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"class eq on/off"
	);

	my $bless_d = bless [$bless_c], "D::Class";

	check_test(
		sub {
			cmp_deeply(
				$bless_d,
				bless([noclass(bless([useclass(bless({}, "NotA::Class"))], "NotC::Class"))], "D::Class"),
			);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared blessed(\$data->[0]->[0])
   got : 'A::Class'
expect : 'NotA::Class'
EOM
		},
		"class eq on/off/on"
	);
}
