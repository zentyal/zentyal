use strict;
use warnings;

use Test::More 'no_plan';
use Test::Tester;

Test::Tester::cmp_result(
	{diag => "abcd    \nabcd", name => ''},
	{diag => "abcd\t\nabcd", name => ''},
"diag");
