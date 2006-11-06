# $Id: load.t,v 1.2 2004/07/04 17:56:42 comdog Exp $
BEGIN {
	@classes = qw(Test::File);
	}

use Test::More tests => scalar @classes;

foreach my $class ( @classes )
	{
	print "bail out! $class did not compile!" unless use_ok( $class );
	}
