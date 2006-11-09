use strict;
use warnings;

use t::std;

sub cmp
{
	my $str = shift;

	if ($str eq "fergal")
	{
		return 1;
	}
	else
	{
		return (0, "your names not down, you're not coming in");
	}
}

{
	check_test(
		sub {
			cmp_deeply("fergal", code(\&cmp));
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"code ok"
	);

	my ($prem, $res) = check_test(
		sub {
			cmp_deeply("feargal", code(\&cmp));
		},
		{
			actual_ok => 0,
		},
		"code not ok"
	);

	like($res->{diag}, "/your names not down/", "diagnostics");
}
