use strict;
use warnings;

use t::std;

{
	my $obj = fake->new;

	check_test(
		sub {
			cmp_deeply($obj, methods(meth1 => "val1", meth2 => ['a', 'b']));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"methods eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, methods(meth1 => "val1", meth2 => ['a', 'c']));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->meth2->[1]
   got : 'b'
expect : 'c'
EOM
		},
		"methods not eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, methods(['plus1', 2] => 3));
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"methods arg eq"
	);
	check_test(
		sub {
			cmp_deeply($obj, methods(['plus1', 2] => 2));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->plus1(2)
   got : '3'
expect : '2'
EOM
		},
		"methods arg not eq"
	);

	check_test(
		sub {
			cmp_deeply($obj, methods(meth1 => "val1", meth3 => "val3"));
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \$data->meth3
   got : Does not exist
expect : 'val3'
EOM
		},
		"methods DNE"
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
						\"a", \["b"], \(methods(meth1 => "val1", meth2 => ['a', 'b']))
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
						\"a", \["b"], \(methods(meth1 => "val1", meth2 => ['a', 'c']))
					]
				}
			);
		},
		{
			actual_ok => 0,
			diag => <<EOM,
Compared \${\$data->{"key"}[2]}->meth2->[1]
   got : 'b'
expect : 'c'
EOM
		},
		"complex not eq"
	);

	check_test(
		sub {
			cmp_methods($obj, [meth1 => "val1", meth2 => ['a', 'b']]);
		},
		{
			actual_ok => 1,
			diag => "",
		},
		"methods eq"
	);
	check_test(
		sub {
			cmp_methods($obj, [meth1 => "val1", meth2 => ['a', 'c']]);
		},
		{
			actual_ok => 0,
		},
		"methods not eq"
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
	return ['a', 'b'];
}

sub plus1
{
	my $self = shift;
	my $arg = shift;
	return $arg + 1;
}
