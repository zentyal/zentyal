use strict;
use warnings;

use Test::More qw(no_plan);

use Test::NoWarnings;

use Test::Deep qw( cmp_deeply descend render_stack methods deep_diag class_base );

{
	my $a = [];

	my ($class, $base) = class_base($a);
	is($class, "", "class_base class ref");
	is($base, "ARRAY", "class_base base ref");
}

{
	my $a = bless [], "A::Class";

	my ($class, $base) = class_base($a);
	is($class, "A::Class", "class_base class obj");
	is($base, "ARRAY", "class_base base obj");
}

{
	my $a = qr/a/;

	my ($class, $base) = class_base($a);
	is($class, "Regexp", "class_base class regexp");
	is($base, "Regexp", "class_base base regexp");
}
