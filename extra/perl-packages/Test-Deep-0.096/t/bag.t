use strict;
use warnings;

use t::std;

{
	check_test(
		sub {
			cmp_deeply([], bag());
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"empty eq"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'b', 'b', ['c', 'd']], bag('b', 'a', ['c', 'd'], 'b'));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"elem eq"
	);

	check_test(
		sub {
			cmp_deeply(['a', [], 'b', 'b'], bag());
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Bag
Extra: 'a', 'b', 'b', 1 reference
EOM
		},
		"empty extra"
	);

	check_test(
		sub {
			cmp_deeply([], bag('a', [], 'a', 'b'));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Bag
Missing: 'a', 'a', 'b', 1 reference
EOM
		},
		"empty missing"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'a', 'b', [\"c"], "d", []], bag({}, 'a', [\"c"], 'd', 'd', "e"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Bag
Missing: 'd', 'e', 1 reference
Extra: 'a', 'b', 1 reference
EOM
		},
		"extra and missing"
	);

	check_test(
		sub {
			cmp_deeply("a", bag());
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Bag
got    : 'a'
expect : An array to use as a Bag
EOM
		},
		"no array"
	);

	check_test(
		sub {
			cmp_deeply(['a', ['a', 'b', 'b'], ['c', 'd', 'c'], ['a', 'b', 'a']],
				bag(bag('c', 'c', 'd'), bag('a', 'b', 'a'), bag('a', 'b', 'b'), 'a')
			);
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"bag of bags eq"
	);

	check_test(
		sub {
			cmp_deeply(['a', ['a', 'b', 'b'], ['c', 'd', 'c'], ['a', 'b', 'a']],
				bag(bag('c', 'd', 'd'), bag('a', 'b', 'a'), bag('a', 'b', 'b'), 'a')
			);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Comparing \$data as a Bag
Missing: 1 reference
Extra: 1 reference
EOM
		},
		"bag of bags not eq"
	);

	my $b1 = bag('a');
	my $b2 = [bag('b')];
	$b1->add($b2, $b1);
	$b2->[0]->add($b1, $b2);

	my $v1 = ['a'];
	my $v2 = [['b']];
	push(@$v1, $v2, $v1);
	push(@{$v2->[0]}, $v1, $v2);

	check_test(
		sub {
			cmp_deeply($v1, $b1);
		},
		{
			actual_ok => 1,
			diag => '',
		},
		"circular double bag eq"
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
Comparing \$data as a Bag
Missing: 'b', 'b'
Extra: 'c', 'c'
EOM
		},
		"circular double set not eq"
	);

	check_test(
		sub {
			cmp_bag([1, 2, 2], [2, 1, 2]);
		},
		{
			actual_ok => 1,
		},
		"cmp_bag eq"
	);
		
	check_test(
		sub {
			cmp_bag([1, 2, 2], [1, 2, 1, 2]);
		},
		{
			actual_ok => 0,
		},
		"cmp_bag not eq"
	);

	check_test(
		sub {
			cmp_bag([1], [1], 'name1');
		},
		{
			actual_ok => 1,
			name => 'name1',
		},
		"cmp_bag returns name"
	);

	check_test(
		sub {
			cmp_bag([1], [2], 'name2');
		},
		{
			actual_ok => 0,
			name => 'name2',
		},
		"cmp_bag returns name"
	);
		
	check_test(
		sub {
			cmp_deeply(['a', 'b', 'c', 'a', 'a', 'b'], superbagof('b', 'a', 'b'));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"superbagof yes"
	);

	check_test(
		sub {
			cmp_deeply(['a', 'b', 'c', 'a'], superbagof('d', 'b', 'd', 'b'));
		},
		{
			actual_ok => 0,
			diag => <<'EOM',
Comparing $data as a SuperBag
Missing: 'b', 'd', 'd'
EOM
		},
		"superbagof no"
	);

	check_test(
		sub {
			cmp_deeply(['b', 'a', 'b'], subbagof('a', 'b', 'c', 'a', 'a', 'b' ));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"subbagof yes"
	);

	check_test(
		sub {
			cmp_deeply(['d', 'b', 'd','b'], subbagof('a', 'b', 'c', 'a'));
		},
		{
			actual_ok => 0,
			diag => <<'EOM',
Comparing $data as a SubBag
Extra: 'b', 'd', 'd'
EOM
		},
		"subbagof no"
	);
}
