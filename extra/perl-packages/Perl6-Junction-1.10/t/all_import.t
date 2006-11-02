use strict;
use Test::More tests => 81;

BEGIN {
	use_ok('Perl6::Junction', 'all');
}


ok( all(3,3.0) == 3,          '==');
ok( all(3,3) == 3,            '==');
ok( all(3,3.0,3) == 3,        '==');
ok( not( all(2,3.0) == 3 ),   '== negated');
ok( not( all(2,2.0,3) == 3 ), '== negated');
ok( not( all(2,3,3.0) == 3 ), '== negated');

ok( all(3,4,5) != 2,        '!=');
ok( all(3,3,5) != 2,        '!=');
ok( all(3,3,3.0) != 2,      '!=');
ok( not( all(3,4,5) != 3 ), '!= negated');
ok( not( all(3,3.0) != 3 ), '!= negated');

ok( all(3,4,5) >= 2,        '>=');
ok( all(3,4,5) >= 3,        '>=');
ok( not( all(3,4,5) >= 4 ), '>= negated');
ok( not( all(3,4,5) >= 5 ), '>= negated');
ok( not( all(3,5,6) >= 4 ), '>= negated');
ok( 6 >= all(3,4,5),        '>= switched');
ok( 5 >= all(3,4,5),        '>= switched');
ok( not( 2 >= all(3,4,5) ), '>= negated switched');
ok( not( 3 >= all(3,4,5) ), '>= negated switched');
ok( not( 4 >= all(3,4,5) ), '>= negated switched');
ok( not( 4 >= all(3,5,6) ), '>= negated switched');

ok( all(3,4,5) > 2,        '>');
ok( not( all(3,4,5) > 4 ), '> negated');
ok( not( all(3,4,5) > 5 ), '> negated');
ok( not( all(3,4,5) > 6 ), '> negated');
ok( 6 > all(3,4,5),        '> switched');
ok( not( 5 > all(3,4,5) ), '> negated switched');
ok( not( 4 > all(3,4,5) ), '> negated switched');
ok( not( 3 > all(3,4,5) ), '> negated switched');
ok( not( 2 > all(3,4,5) ), '> negated switched');

ok( all(3,4,5) <= 5,        '<=');
ok( all(3,4,5) <= 6,        '<=');
ok( not( all(3,4,5) <= 2 ), '<= negated');
ok( 2 <= all(3,4,5),        '<= switched');
ok( 3 <= all(3,4,5),        '<= switched');
ok( not( 6 <= all(3,4,5) ), '<= negated switched');

ok( all(3,4,5) < 6,        '<');
ok( not( all(3,4,5) < 5 ), '< negated');
ok( not( all(3,4,5) < 2 ), '< negated');
ok( 2 < all(3,4,5),        '< switched');
ok( not( 5 < all(3,4,5) ), '< negated switched');
ok( not( 6 < all(3,4,5) ), '< negated switched');

ok( all('g', 'g') eq 'g',        'eq');
ok( not( all('g', 'h') eq 'g' ), 'eq negated');

ok( all('h', 'i') ne 'g',        'ne');
ok( not( all('h', 'i') ne 'i' ), 'ne negated');

ok( all('g', 'h') ge 'g',        'ge');
ok( all('g', 'h') ge 'f',        'ge');
ok( not( all('g', 'h') ge 'i' ), 'ge negated');
ok( 'i' ge all('g', 'h'),        'ge switched');
ok( 'h' ge all('g', 'h'),        'ge switched');
ok( not( 'f' ge all('g', 'h') ), 'ge negated switched');

ok( all('g', 'h') gt 'f',        'gt');
ok( not( all('a', 'h') gt 'e' ), 'gt negated');
ok( not( all('g', 'h') gt 'g' ), 'gt negated');
ok( 'i' gt all('g', 'h'),        'gt switched');
ok( not( 'f' gt all('g', 'h') ), 'gt negated switched');
ok( not( 'g' gt all('g', 'h') ), 'gt negated switched');

ok( all('g', 'h') le 'i',        'le');
ok( all('g', 'h') le 'h',        'le');
ok( not( all('g', 'h') le 'f' ), 'le negated');
ok( 'f' le all('g', 'h'),        'le switched');
ok( 'g' le all('g', 'h'),        'le switched');
ok( not( 'i' le all('g', 'h') ), 'le negated switched');

ok( all('g', 'h') lt 'i',        'lt');
ok( not( all('b', 'h') lt 'a' ), 'lt negated');
ok( not( all('g', 'h') lt 'f' ), 'lt negated');
ok( 'f' lt all('g', 'h'),        'lt switched');
ok( not( 'h' lt all('g', 'h') ), 'lt negated switched');
ok( not( 'i' lt all('g', 'h') ), 'lt negated switched');

ok( all(3,40) == qr/\d+/,               '== regex');
ok( qr/^[ab]$/ == all('a','b'),         '== regex');
ok( not( all(2,3,'c') == qr/\d+/ ),       '== regex negated');
ok( not( qr/\d/ == all(2,3,'c')),       '== regex negated');
ok( not( qr/[a-z]+/ == all('a','b',3)), '== regex negated');

ok( all(3,4,5) != qr/[a-z]/,          '!= regex');
ok( all('a','b','c') != qr/\d/,       '!= regex');
ok( not( all(3,4,5) != qr/4/ ),       '!= regex negated');
ok( not( all(3,4,'a') != qr/[a-z]/ ), '!= regex negated');

