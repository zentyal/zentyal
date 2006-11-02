use strict;
use Test::More tests => 90;

BEGIN {
	use_ok('Perl6::Junction');
}


ok( Perl6::Junction::one(2,3) == 2,          '==');
ok( Perl6::Junction::one(2,3.0) == 3,        '==');
ok( Perl6::Junction::one(1,2,3,4,5) == 2,    '==');
ok( not( Perl6::Junction::one(2,3.0) == 4 ), '== negated');
ok( not( Perl6::Junction::one(3,3.0) == 3 ), '== negated');

ok( Perl6::Junction::one(3,4) != 4,          '!=');
ok( not( Perl6::Junction::one(3,3.0) != 3 ), '!= negated');
ok( not( Perl6::Junction::one(3,4) != 5 ),   '!= negated');

ok( Perl6::Junction::one(3,4,5) >= 5,        '>=');
ok( Perl6::Junction::one(3,4,6) >= 5,        '>=');
ok( Perl6::Junction::one(1,2,3,4,6) >= 5,    '>=');
ok( not( Perl6::Junction::one(3,4,5) >= 6 ), '>= negated');
ok( not( Perl6::Junction::one(3,4,5) >= 4 ), '>= negated');
ok( not( Perl6::Junction::one(3,4,5) >= 2 ), '>= negated');
ok( 4 >= Perl6::Junction::one(3),            '>= switched');
ok( 4 >= Perl6::Junction::one(4),            '>= switched');
ok( 4 >= Perl6::Junction::one(3,5),          '>= switched');
ok( not( 2 >= Perl6::Junction::one(3,4,5) ), '>= negated switched');
ok( not( 4 >= Perl6::Junction::one(3,4,5) ), '>= negated switched');

ok( Perl6::Junction::one(3,4,5) > 4,        '>');
ok( Perl6::Junction::one(3,5) > 4,          '>');
ok( not( Perl6::Junction::one(3,4,5) > 6 ), '> negated');
ok( not( Perl6::Junction::one(3,4,5) > 3 ), '> negated');
ok( 4 > Perl6::Junction::one(3,4,5),        '> switched');
ok( 4 > Perl6::Junction::one(3,5),          '> switched');
ok( not( 2 > Perl6::Junction::one(3,4,5) ), '> negated switched');
ok( not( 5 > Perl6::Junction::one(3,4,5) ), '> negated switched');

ok( Perl6::Junction::one(3,4,5) <= 3,        '<=');
ok( Perl6::Junction::one(3,5) <= 4,          '<=');
ok( not( Perl6::Junction::one(3,4,5) <= 2 ), '<= negated');
ok( not( Perl6::Junction::one(3,4,5) <= 6 ), '<= negated');
ok( 5 <= Perl6::Junction::one(3,4,5),        '<= switched');
ok( not( 6 <= Perl6::Junction::one(3,4,5) ), '<= negated switched');
ok( not( 3 <= Perl6::Junction::one(3,4,5) ), '<= negated switched');

ok( Perl6::Junction::one(3,4,5) < 4,        '<');
ok( Perl6::Junction::one(5,4,3) < 4,        '<');
ok( not( Perl6::Junction::one(3,4,5) < 2 ), '< negated');
ok( not( Perl6::Junction::one(3,4,5) < 6 ), '< negated');
ok( 4 < Perl6::Junction::one(3,4,5),        '< switched');
ok( 4 < Perl6::Junction::one(3,3,5),        '< switched');
ok( not( 6 < Perl6::Junction::one(3,4,5) ), '< negated switched');
ok( not( 3 < Perl6::Junction::one(3,4,5) ), '< negated switched');

ok( Perl6::Junction::one('g', 'h') eq 'g',        'eq');
ok( not( Perl6::Junction::one('g', 'h') eq 'f' ), 'eq negated');
ok( not( Perl6::Junction::one('g', 'g') eq 'g' ), 'eq negated');

ok( Perl6::Junction::one('g', 'h') ne 'g',        'ne');
ok( Perl6::Junction::one('g', 'h', 'g') ne 'g',   'ne');
ok( not( Perl6::Junction::one('i', 'i') ne 'i' ), 'ne negated');
ok( not( Perl6::Junction::one('g', 'h') ne 'i' ), 'ne negated');

ok( Perl6::Junction::one('g', 'h') ge 'h',        'ge');
ok( Perl6::Junction::one('g') ge 'g',             'ge');
ok( not( Perl6::Junction::one('g', 'h') ge 'i' ), 'ge negated');
ok( not( Perl6::Junction::one('g', 'g') ge 'g' ), 'ge negated');
ok( 'h' ge Perl6::Junction::one('g', 'i'),        'ge switched');
ok( 'g' ge Perl6::Junction::one('g', 'h'),        'ge switched');
ok( not( 'f' ge Perl6::Junction::one('g', 'h') ), 'ge negated switched');
ok( not( 'h' ge Perl6::Junction::one('g', 'h') ), 'ge negated switched');

ok( Perl6::Junction::one('g', 'h') gt 'g',        'gt');
ok( Perl6::Junction::one('g', 'i') gt 'h',        'gt');
ok( not( Perl6::Junction::one('g', 'h') gt 'f' ), 'gt negated');
ok( 'h' gt Perl6::Junction::one('g', 'h'),        'gt switched');
ok( 'h' gt Perl6::Junction::one('h', 'g'),        'gt switched');
ok( not( 'g' gt Perl6::Junction::one('g', 'h') ), 'gt negated switched');
ok( not( 'i' gt Perl6::Junction::one('g', 'h') ), 'gt negated switched');

ok( Perl6::Junction::one('g', 'i') le 'h',        'le');
ok( not( Perl6::Junction::one('g', 'h') le 'f' ), 'le negated');
ok( not( Perl6::Junction::one('g', 'g') le 'f' ), 'le negated');
ok( 'g' le Perl6::Junction::one('f', 'h'),        'le switched');
ok( not( 'i' le Perl6::Junction::one('g', 'h') ), 'le negated switched');
ok( not( 'g' le Perl6::Junction::one('g', 'h') ), 'le negated switched');

ok( Perl6::Junction::one('g', 'h') lt 'h',        'lt');
ok( Perl6::Junction::one('h', 'g') lt 'h',        'lt');
ok( not( Perl6::Junction::one('g', 'h') lt 'i' ), 'lt negated');
ok( not( Perl6::Junction::one('g', 'h') lt 'f' ), 'lt negated');
ok( 'g' lt Perl6::Junction::one('g', 'h'),        'lt switched');
ok( 'g' lt Perl6::Junction::one('h', 'g'),        'lt switched');
ok( not( 'f' lt Perl6::Junction::one('g', 'h') ), 'lt negated switched');
ok( not( 'i' lt Perl6::Junction::one('g', 'h') ), 'lt negated switched');

ok( Perl6::Junction::one(3,4,'a') == qr/[a-z]/,          '== regex');
ok( qr/\d/ == Perl6::Junction::one('a','b',5),           '== regex');
ok( not( Perl6::Junction::one(2,3,'c') == qr/\d/ ),      '== regex negated');
ok( not( qr/\d/ == Perl6::Junction::one(2,3,'c')),       '== regex negated');
ok( not( qr/[a-z]+/ == Perl6::Junction::one('a','b',3)), '== regex negated');

ok( Perl6::Junction::one(3,4,'a') != qr/[0-9]/,      '!= regex');
ok( qr/[0-9] != Perl6::Junction::one(3,4,'a') /,     '!= regex');
ok( Perl6::Junction::one(3,'a','c') != qr/[a-z]/,    '!= regex');
ok( qr/[a-z] != Perl6::Junction::one(3,'a','c')/,    '!= regex');
ok( not( Perl6::Junction::one(3,4,5) != qr/\d/ ),    '!= regex negated');
ok( not( Perl6::Junction::one(3,4,5) != qr/[a-z]/ ), '!= regex negated');

