use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply([], set());
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"empty eq"
	);

	check_test(
		sub {
			cmp_deeply(["a"], set("a", "a"));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"empty eq"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'b', 'b', ['c', 'd']], set('b', 'a', ['c', 'd'], 'b'));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"3 elem eq"
	);

	check_test(
		sub {
			cmp_deeply(['a', [], 'b', 'b'], set());
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Extra: 'a', 'b', 1 reference
EOM
		},
		"empty extra"
	);

	check_test(
		sub {
			cmp_deeply([], set('a', [], 'a', 'b'));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Missing: 'a', 'b', 1 reference
EOM
		},
		"empty missing"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'a', 'b', [\"c"], "d", []], set({}, 'a', [\"c"], 'd', 'd', "e"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Missing: 'e', 1 reference
Extra: 'b', 1 reference
EOM
		},
		"extra and missing"
	);

	check_test(
		sub {
			cmp_deeply("a", set());
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
got    : 'a'
expect : An array to use as a Set
EOM
		},
		"no array"
	);

	check_test(
		sub {
			cmp_deeply(['a',['a', 'b', 'b'], ['c', 'd', 'c','d'], ['a', 'b', 'a']],
				set(set('c', 'd', 'd'), set('a', 'b', 'a'), set('c', 'c', 'd'), 'a')
			);
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"set of sets eq"
	);
	check_test(
		sub {
			cmp_deeply([['a', 'b', 'c'], ['c', 'd', 'c'], ['a', 'b', 'a']],
				set(set('c', 'd', 'c'), set('a', 'b', 'a'), set('b', 'b', 'a'))
			);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Extra: 1 reference
EOM
		},
		"set of sets not eq"
	);

	my $b1 = set('a');
	my $b2 = [set('b')];
	$b1->add($b1, $b2, $b1);
	$b2->[0]->add($b2, $b1, $b2);

	my $v1 = ['a'];
	my $v2 = [['b']];
	push(@$v1, $v2, $v1, $v2);
	push(@{$v2->[0]}, $v1, $v2, $v1);

	check_test(
		sub {
			cmp_deeply($v1, $b1);
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"circular double set eq"
	);

	$b1->add('b', 'b');
	push(@$v1, 'c', 'c');
	check_test(
		sub {
			cmp_deeply($v1, $b1);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Missing: 'b'
Extra: 'c'
EOM
		},
		"circular double set not eq"
	);

	check_test(
		sub {
			cmp_set([1, 2, 2], [1, 1, 2]);
		},
		{
			actual_ok => 1,
		},
		"cmp_set eq"
	);
		
	check_test(
		sub {
			cmp_set([1, 2, 2, 3], [1, 1, 2]);
		},
		{
			actual_ok => 0,
		},
		"cmp_set not eq"
	);
}

{
	my $a1 = \"a";
	my $b1 = \"b";
	my $a2 = \"a";
	my $b2 = \"b";

	TODO:
	{
	todo_skip(
		"Because I want to get it out the door see notes on bags and sets",
		5
	);
	check_test(
		sub {
			cmp_deeply([[\'a', \'b']], set(set($a2, $b1), set($b2, $a1)))
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"set compare()"
	);
	}

	check_test(
		sub {
			cmp_deeply(['a', 'b', 'c', 'a'], supersetof('b', 'a', 'b'));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"supersetof yes"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'b', 'c', 'a'], supersetof('d', 'b', 'd'));
		},
		{
			actual_ok => 0,
			diag => <<'EOM',
Comparing $data as a SuperSet
Missing: 'd'
EOM
		},
		"supersetof no"
	);

	check_test(
		sub {
			cmp_deeply(['b', 'a', 'b'], subsetof('a', 'b', 'c', 'a'));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"subsetof yes"
	);

	check_test(
		sub {
			cmp_deeply(['d', 'b', 'd'], subsetof('a', 'b', 'c', 'a'));
		},
		{
			actual_ok => 0,
			diag => <<'EOM',
Comparing $data as a SubSet
Extra: 'd'
EOM
		},
		"subsetof no"
	);
}

{
	check_test(
		sub {
			cmp_deeply([1, undef, undef], set(undef, 1, undef));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"undef warnings"
	);

	check_test(
		sub {
			cmp_deeply([1, undef], set(1));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Set
Extra: undef
EOM
		},
		"warnings extra"
	);
}
