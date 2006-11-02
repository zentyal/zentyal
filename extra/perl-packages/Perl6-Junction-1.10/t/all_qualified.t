use strict;
use Test::More tests => 81;

BEGIN {
	use_ok('Perl6::Junction');
}


ok( Perl6::Junction::all(3,3.0) == 3,          '==');
ok( Perl6::Junction::all(3,3) == 3,            '==');
ok( Perl6::Junction::all(3,3.0,3) == 3,        '==');
ok( not( Perl6::Junction::all(2,3.0) == 3 ),   '== negated');
ok( not( Perl6::Junction::all(2,2.0,3) == 3 ), '== negated');
ok( not( Perl6::Junction::all(2,3,3.0) == 3 ), '== negated');

ok( Perl6::Junction::all(3,4,5) != 2,        '!=');
ok( Perl6::Junction::all(3,3,5) != 2,        '!=');
ok( Perl6::Junction::all(3,3,3.0) != 2,      '!=');
ok( not( Perl6::Junction::all(3,4,5) != 3 ), '!= negated');
ok( not( Perl6::Junction::all(3,3.0) != 3 ), '!= negated');

ok( Perl6::Junction::all(3,4,5) >= 2,        '>=');
ok( Perl6::Junction::all(3,4,5) >= 3,        '>=');
ok( not( Perl6::Junction::all(3,4,5) >= 4 ), '>= negated');
ok( not( Perl6::Junction::all(3,4,5) >= 5 ), '>= negated');
ok( not( Perl6::Junction::all(3,5,6) >= 4 ), '>= negated');
ok( 6 >= Perl6::Junction::all(3,4,5),        '>= switched');
ok( 5 >= Perl6::Junction::all(3,4,5),        '>= switched');
ok( not( 2 >= Perl6::Junction::all(3,4,5) ), '>= negated switched');
ok( not( 3 >= Perl6::Junction::all(3,4,5) ), '>= negated switched');
ok( not( 4 >= Perl6::Junction::all(3,4,5) ), '>= negated switched');
ok( not( 4 >= Perl6::Junction::all(3,5,6) ), '>= negated switched');

ok( Perl6::Junction::all(3,4,5) > 2,        '>');
ok( not( Perl6::Junction::all(3,4,5) > 4 ), '> negated');
ok( not( Perl6::Junction::all(3,4,5) > 5 ), '> negated');
ok( not( Perl6::Junction::all(3,4,5) > 6 ), '> negated');
ok( 6 > Perl6::Junction::all(3,4,5),        '> switched');
ok( not( 5 > Perl6::Junction::all(3,4,5) ), '> negated switched');
ok( not( 4 > Perl6::Junction::all(3,4,5) ), '> negated switched');
ok( not( 3 > Perl6::Junction::all(3,4,5) ), '> negated switched');
ok( not( 2 > Perl6::Junction::all(3,4,5) ), '> negated switched');

ok( Perl6::Junction::all(3,4,5) <= 5,        '<=');
ok( Perl6::Junction::all(3,4,5) <= 6,        '<=');
ok( not( Perl6::Junction::all(3,4,5) <= 2 ), '<= negated');
ok( 2 <= Perl6::Junction::all(3,4,5),        '<= switched');
ok( 3 <= Perl6::Junction::all(3,4,5),        '<= switched');
ok( not( 6 <= Perl6::Junction::all(3,4,5) ), '<= negated switched');

ok( Perl6::Junction::all(3,4,5) < 6,        '<');
ok( not( Perl6::Junction::all(3,4,5) < 5 ), '< negated');
ok( not( Perl6::Junction::all(3,4,5) < 2 ), '< negated');
ok( 2 < Perl6::Junction::all(3,4,5),        '< switched');
ok( not( 5 < Perl6::Junction::all(3,4,5) ), '< negated switched');
ok( not( 6 < Perl6::Junction::all(3,4,5) ), '< negated switched');

ok( Perl6::Junction::all('g', 'g') eq 'g',        'eq');
ok( not( Perl6::Junction::all('g', 'h') eq 'g' ), 'eq negated');

ok( Perl6::Junction::all('h', 'i') ne 'g',        'ne');
ok( not( Perl6::Junction::all('h', 'i') ne 'i' ), 'ne negated');

ok( Perl6::Junction::all('g', 'h') ge 'g',        'ge');
ok( Perl6::Junction::all('g', 'h') ge 'f',        'ge');
ok( not( Perl6::Junction::all('g', 'h') ge 'i' ), 'ge negated');
ok( 'i' ge Perl6::Junction::all('g', 'h'),        'ge switched');
ok( 'h' ge Perl6::Junction::all('g', 'h'),        'ge switched');
ok( not( 'f' ge Perl6::Junction::all('g', 'h') ), 'ge negated switched');

ok( Perl6::Junction::all('g', 'h') gt 'f',        'gt');
ok( not( Perl6::Junction::all('a', 'h') gt 'e' ), 'gt negated');
ok( not( Perl6::Junction::all('g', 'h') gt 'g' ), 'gt negated');
ok( 'i' gt Perl6::Junction::all('g', 'h'),        'gt switched');
ok( not( 'f' gt Perl6::Junction::all('g', 'h') ), 'gt negated switched');
ok( not( 'g' gt Perl6::Junction::all('g', 'h') ), 'gt negated switched');

ok( Perl6::Junction::all('g', 'h') le 'i',        'le');
ok( Perl6::Junction::all('g', 'h') le 'h',        'le');
ok( not( Perl6::Junction::all('g', 'h') le 'f' ), 'le negated');
ok( 'f' le Perl6::Junction::all('g', 'h'),        'le switched');
ok( 'g' le Perl6::Junction::all('g', 'h'),        'le switched');
ok( not( 'i' le Perl6::Junction::all('g', 'h') ), 'le negated switched');

ok( Perl6::Junction::all('g', 'h') lt 'i',        'lt');
ok( not( Perl6::Junction::all('b', 'h') lt 'a' ), 'lt negated');
ok( not( Perl6::Junction::all('g', 'h') lt 'f' ), 'lt negated');
ok( 'f' lt Perl6::Junction::all('g', 'h'),        'lt switched');
ok( not( 'h' lt Perl6::Junction::all('g', 'h') ), 'lt negated switched');
ok( not( 'i' lt Perl6::Junction::all('g', 'h') ), 'lt negated switched');

ok( Perl6::Junction::all(3,40) == qr/\d+/,               '== regex');
ok( qr/^[ab]$/ == Perl6::Junction::all('a','b'),         '== regex');
ok( not( Perl6::Junction::all(2,3,'c') == qr/\d+/ ),       '== regex negated');
ok( not( qr/\d/ == Perl6::Junction::all(2,3,'c')),       '== regex negated');
ok( not( qr/[a-z]+/ == Perl6::Junction::all('a','b',3)), '== regex negated');

ok( Perl6::Junction::all(3,4,5) != qr/[a-z]/,          '!= regex');
ok( Perl6::Junction::all('a','b','c') != qr/\d/,       '!= regex');
ok( not( Perl6::Junction::all(3,4,5) != qr/4/ ),       '!= regex negated');
ok( not( Perl6::Junction::all(3,4,'a') != qr/[a-z]/ ), '!= regex negated');

