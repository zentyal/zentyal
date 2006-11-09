use strict;
use warnings;

package Over;

use overload '""' => \&val, '0+' => \&val, fallback => 1;

sub new
{
	my $pkg = shift;
	my $val = shift;

	return bless \$val, $pkg;
}

sub val
{
	my $self = shift;
	return $$self;
}

1;
