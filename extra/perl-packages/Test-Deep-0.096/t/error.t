use strict;
use warnings;

use t::std;

{
	my ($prem, @res) = eval {
		run_tests(
			sub {
				cmp_deeply([shallow([])], [[]], "bad special");
			}
		);
	};

	like($@, qr/^Found a special comparison in \$data->\[0\]\nYou can only the specials in the expects structure/,
		"bad special");
}
