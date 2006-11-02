use strict;
use Test::More tests => 22;

BEGIN {
	use_ok('Perl6::Junction', 'all', 'any', 'none', 'one');
}


ok( all(3,3.0) == all(3,3.0),     '==');
ok( all(3,3.0) == any(3,3.0),     '==');
ok( any(3,3.0) == all(3,3.0),     '==');
ok( all(1,3.0) == none(2,4,5),    '==');
ok( none(5,6,8) == all(5,6,8),    '==');
ok( all(1,3.0) == one(1,3),       '==');
ok( one(5,6) == all(5,5,5),       '==');
ok( not( all(2,3) == all(2,3) ),  '== negated');
ok( not( all(2,3) == any(4,5) ),  '== negated');
ok( not( any(2,3) == all(2,3) ),  '== negated');
ok( not( all(2,3) == none(2,3) ), '== negated');
ok( not( none(2,3) == all(2,2) ), '== negated');
ok( not( all(2,3) == one(2,2) ),  '== negated');
ok( not( one(2,3) == all(2,3) ),  '== negated');

ok( all(3,4,5) >= all(2,3),       '>=');
ok( all(5,10,15) > any(3,5,-1,2), '>=');
ok( any(3,4,5) >= all(3,4,5),     '>=');
ok( all(1,3.0) >= none(4,5,6),    '>=');
ok( none(5,6,8) >= all(9,10),     '>=');
ok( all(3,4) >= one(3,6),         '>=');
ok( one(4,5) >= all(5,5,5),       '>=');

