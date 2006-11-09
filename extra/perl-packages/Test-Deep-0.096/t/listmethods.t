use strict;
use warnings;

use t::std;

{
	my $obj = fake->new;

	check_test(
		sub {
			cmp_deeply($obj, listmethods(meth1 => ["val1"], meth2 => ['a', 'b']));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"listmethods eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, listmethods(meth1 => ["val1"], meth2 => ['a', 'c']));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared [\$data->meth2]->[1]
   got : 'b'
expect : 'c'
EOM
		},
		"listmethods not eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, listmethods(['plus1', 2] => ["a", "a", "a"]));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"listmethods arg eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, listmethods(['plus1', 2] => ["a", "b", "a"]));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared [\$data->plus1(2)]->[1]
   got : 'a'
expect : 'b'
EOM
		},
		"listmethods arg not eq"
	);

	my $v3 = ['val3'];
	check_test(
		sub {
			cmp_deeply($obj, listmethods(meth1 => ["val1"], meth3 => $v3));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared [\$data->meth3]
   got : Does not exist
expect : $v3
EOM
		},
		"listmethods DNE"
	);
}

{
	my $obj = fake->new;

	check_test(
		sub {
			cmp_deeply(
				{
					key => [
						\"a", \["b"], \$obj
					]
				},
				{
					key => [
						\"a", \["b"], \(listmethods(meth1 => ["val1"], meth2 => ['a', 'b']))
					]
				}
			);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"complex eq"
	);
	check_test(
		sub {
			cmp_deeply(
				{
					key => [
						\"a", \["b"], \$obj
					]
				},
				{
					key => [
						\"a", \["b"], \(listmethods(meth1 => ["val1"], meth2 => ['a', 'c']))
					]
				}
			);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared [\${\$data->{"key"}[2]}->meth2]->[1]
   got : 'b'
expect : 'c'
EOM
		},
		"complex not eq"
	);
}

package fake;

sub new
{
	return bless {}, __PACKAGE__;
}

sub meth1
{
	return "val1";
}

sub meth2
{
	return ('a', 'b');
}

sub plus1
{
	my $self = shift;
	my $arg = shift;
	return ("a") x ($arg + 1);
}
