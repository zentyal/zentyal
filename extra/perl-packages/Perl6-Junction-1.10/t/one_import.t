use strict;
use Test::More tests => 90;

BEGIN {
	use_ok('Perl6::Junction', 'one');
}


ok( one(2,3) == 2,          '==');
ok( one(2,3.0) == 3,        '==');
ok( one(1,2,3,4,5) == 2,    '==');
ok( not( one(2,3.0) == 4 ), '== negated');
ok( not( one(3,3.0) == 3 ), '== negated');

ok( one(3,4) != 4,          '!=');
ok( not( one(3,3.0) != 3 ), '!= negated');
ok( not( one(3,4) != 5 ),   '!= negated');

ok( one(3,4,5) >= 5,        '>=');
ok( one(3,4,6) >= 5,        '>=');
ok( one(1,2,3,4,6) >= 5,    '>=');
ok( not( one(3,4,5) >= 6 ), '>= negated');
ok( not( one(3,4,5) >= 4 ), '>= negated');
ok( not( one(3,4,5) >= 2 ), '>= negated');
ok( 4 >= one(3),            '>= switched');
ok( 4 >= one(4),            '>= switched');
ok( 4 >= one(3,5),          '>= switched');
ok( not( 2 >= one(3,4,5) ), '>= negated switched');
ok( not( 4 >= one(3,4,5) ), '>= negated switched');

ok( one(3,4,5) > 4,        '>');
ok( one(3,5) > 4,          '>');
ok( not( one(3,4,5) > 6 ), '> negated');
ok( not( one(3,4,5) > 3 ), '> negated');
ok( 4 > one(3,4,5),        '> switched');
ok( 4 > one(3,5),          '> switched');
ok( not( 2 > one(3,4,5) ), '> negated switched');
ok( not( 5 > one(3,4,5) ), '> negated switched');

ok( one(3,4,5) <= 3,        '<=');
ok( one(3,5) <= 4,          '<=');
ok( not( one(3,4,5) <= 2 ), '<= negated');
ok( not( one(3,4,5) <= 6 ), '<= negated');
ok( 5 <= one(3,4,5),        '<= switched');
ok( not( 6 <= one(3,4,5) ), '<= negated switched');
ok( not( 3 <= one(3,4,5) ), '<= negated switched');

ok( one(3,4,5) < 4,        '<');
ok( one(5,4,3) < 4,        '<');
ok( not( one(3,4,5) < 2 ), '< negated');
ok( not( one(3,4,5) < 6 ), '< negated');
ok( 4 < one(3,4,5),        '< switched');
ok( 4 < one(3,3,5),        '< switched');
ok( not( 6 < one(3,4,5) ), '< negated switched');
ok( not( 3 < one(3,4,5) ), '< negated switched');

ok( one('g', 'h') eq 'g',        'eq');
ok( not( one('g', 'h') eq 'f' ), 'eq negated');
ok( not( one('g', 'g') eq 'g' ), 'eq negated');

ok( one('g', 'h') ne 'g',        'ne');
ok( one('g', 'h', 'g') ne 'g',   'ne');
ok( not( one('i', 'i') ne 'i' ), 'ne negated');
ok( not( one('g', 'h') ne 'i' ), 'ne negated');

ok( one('g', 'h') ge 'h',        'ge');
ok( one('g') ge 'g',             'ge');
ok( not( one('g', 'h') ge 'i' ), 'ge negated');
ok( not( one('g', 'g') ge 'g' ), 'ge negated');
ok( 'h' ge one('g', 'i'),        'ge switched');
ok( 'g' ge one('g', 'h'),        'ge switched');
ok( not( 'f' ge one('g', 'h') ), 'ge negated switched');
ok( not( 'h' ge one('g', 'h') ), 'ge negated switched');

ok( one('g', 'h') gt 'g',        'gt');
ok( one('g', 'i') gt 'h',        'gt');
ok( not( one('g', 'h') gt 'f' ), 'gt negated');
ok( 'h' gt one('g', 'h'),        'gt switched');
ok( 'h' gt one('h', 'g'),        'gt switched');
ok( not( 'g' gt one('g', 'h') ), 'gt negated switched');
ok( not( 'i' gt one('g', 'h') ), 'gt negated switched');

ok( one('g', 'i') le 'h',        'le');
ok( not( one('g', 'h') le 'f' ), 'le negated');
ok( not( one('g', 'g') le 'f' ), 'le negated');
ok( 'g' le one('f', 'h'),        'le switched');
ok( not( 'i' le one('g', 'h') ), 'le negated switched');
ok( not( 'g' le one('g', 'h') ), 'le negated switched');

ok( one('g', 'h') lt 'h',        'lt');
ok( one('h', 'g') lt 'h',        'lt');
ok( not( one('g', 'h') lt 'i' ), 'lt negated');
ok( not( one('g', 'h') lt 'f' ), 'lt negated');
ok( 'g' lt one('g', 'h'),        'lt switched');
ok( 'g' lt one('h', 'g'),        'lt switched');
ok( not( 'f' lt one('g', 'h') ), 'lt negated switched');
ok( not( 'i' lt one('g', 'h') ), 'lt negated switched');

ok( one(3,4,'a') == qr/[a-z]/,          '== regex');
ok( qr/\d/ == one('a','b',5),           '== regex');
ok( not( one(2,3,'c') == qr/\d/ ),      '== regex negated');
ok( not( qr/\d/ == one(2,3,'c')),       '== regex negated');
ok( not( qr/[a-z]+/ == one('a','b',3)), '== regex negated');

ok( one(3,4,'a') != qr/[0-9]/,      '!= regex');
ok( qr/[0-9] != one(3,4,'a') /,     '!= regex');
ok( one(3,'a','c') != qr/[a-z]/,    '!= regex');
ok( qr/[a-z] != one(3,'a','c')/,    '!= regex');
ok( not( one(3,4,5) != qr/\d/ ),    '!= regex negated');
ok( not( one(3,4,5) != qr/[a-z]/ ), '!= regex negated');

