#$Id: prereq.t,v 1.4 2005/06/05 13:23:56 comdog Exp $
use Test::More;
eval "use Test::Prereq 1.0";
plan skip_all => "Test::Prereq required to test dependencies" if $@;
prereq_ok( undef, undef, [ qw(t/setup_common) ] );
