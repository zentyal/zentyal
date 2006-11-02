use strict;
use Test::More tests => 69;

BEGIN {
	use_ok('Perl6::Junction');
}


ok( Perl6::Junction::any(2,3.0) == 2,        '==');
ok( Perl6::Junction::any(2,3.0) == 3,        '==');
ok( not( Perl6::Junction::any(2,3.0) == 4 ), '== negated');

ok( Perl6::Junction::any(3,4.0) != 4,        '!=');
ok( Perl6::Junction::any(4,5.0) != 4,        '!=');
ok( not( Perl6::Junction::any(3,3.0) != 3 ), '!= negated');

ok( Perl6::Junction::any(3,4,5) >= 5,        '>=');
ok( Perl6::Junction::any(3,4,5) >= 2,        '>=');
ok( not( Perl6::Junction::any(3,4,5) >= 6 ), '>= negated');
ok( 6 >= Perl6::Junction::any(3,4,5),        '>= switched');
ok( 3 >= Perl6::Junction::any(3,4,5),        '>= switched');
ok( not( 2 >= Perl6::Junction::any(3,4,5) ), '>= negated switched');

ok( Perl6::Junction::any(3,4,5) > 2,        '>');
ok( Perl6::Junction::any(3,4,5) > 3,        '>');
ok( not( Perl6::Junction::any(3,4,5) > 6 ), '> negated');
ok( 6 > Perl6::Junction::any(3,4,5),        '> switched');
ok( 4 > Perl6::Junction::any(3,4,5),        '> switched');
ok( not( 2 > Perl6::Junction::any(3,4,5) ), '> negated switched');

ok( Perl6::Junction::any(3,4,5) <= 5,        '<=');
ok( Perl6::Junction::any(3,4,5) <= 6,        '<=');
ok( not( Perl6::Junction::any(3,4,5) <= 2 ), '<= negated');
ok( 5 <= Perl6::Junction::any(3,4,5),        '<= switched');
ok( 2 <= Perl6::Junction::any(3,4,5),        '<= switched');
ok( not( 6 <= Perl6::Junction::any(3,4,5) ), '<= negated switched');

ok( Perl6::Junction::any(3,4,5) < 6,        '<');
ok( Perl6::Junction::any(5,4,3) < 4,        '<');
ok( not( Perl6::Junction::any(3,4,5) < 2 ), '< negated');
ok( 2 < Perl6::Junction::any(3,4,5),        '< switched');
ok( 4 < Perl6::Junction::any(3,4,5),        '< switched');
ok( not( 6 < Perl6::Junction::any(3,4,5) ), '< negated switched');

ok( Perl6::Junction::any('g', 'h') eq 'g',        'eq');
ok( Perl6::Junction::any('g', 'g') eq 'g',        'eq');
ok( not( Perl6::Junction::any('g', 'h') eq 'i' ), 'eq negated');

ok( Perl6::Junction::any('g', 'h') ne 'g',        'ne');
ok( not( Perl6::Junction::any('i', 'i') ne 'i' ), 'ne negated');

ok( Perl6::Junction::any('g', 'h') ge 'f',        'ge');
ok( Perl6::Junction::any('g', 'h') ge 'g',        'ge');
ok( not( Perl6::Junction::any('g', 'h') ge 'i' ), 'ge negated');
ok( 'i' ge Perl6::Junction::any('g', 'h'),        'ge switched');
ok( 'g' ge Perl6::Junction::any('g', 'f'),        'ge switched');
ok( not( 'f' ge Perl6::Junction::any('g', 'h') ), 'ge negated switched');

ok( Perl6::Junction::any('g', 'h') gt 'f',        'gt');
ok( Perl6::Junction::any('g', 'h') gt 'g',        'gt');
ok( not( Perl6::Junction::any('g', 'h') gt 'i' ), 'gt negated');
ok( 'i' gt Perl6::Junction::any('h', 'g'),        'gt switched');
ok( 'h' gt Perl6::Junction::any('h', 'g'),        'gt switched');
ok( not( 'g' gt Perl6::Junction::any('g', 'h') ), 'gt negated switched');
ok( not( 'f' gt Perl6::Junction::any('g', 'h') ), 'gt negated switched');

ok( Perl6::Junction::any('g', 'h') le 'i',        'le');
ok( Perl6::Junction::any('g', 'f') le 'g',        'le');
ok( not( Perl6::Junction::any('g', 'h') le 'f' ), 'le negated');
ok( 'f' le Perl6::Junction::any('g', 'h'),        'le switched');
ok( 'g' le Perl6::Junction::any('h', 'g'),        'le switched');
ok( not( 'i' le Perl6::Junction::any('g', 'h') ), 'le negated switched');

ok( Perl6::Junction::any('g', 'h') lt 'i',        'lt');
ok( Perl6::Junction::any('h', 'g') lt 'h',        'lt');
ok( not( Perl6::Junction::any('g', 'h') lt 'f' ), 'lt negated');
ok( 'f' lt Perl6::Junction::any('g', 'h'),        'lt switched');
ok( 'g' lt Perl6::Junction::any('h', 'g'),        'lt switched');
ok( not( 'i' lt Perl6::Junction::any('g', 'h') ), 'lt negated switched');

ok( Perl6::Junction::any(3,'b') == qr/\d+/,              '== regex');
ok( qr/^[ab]$/ == Perl6::Junction::any('a',4),           '== regex');
ok( not( Perl6::Junction::any('a','b','c') == qr/\d+/ ), '== regex negated');
ok( not( qr/\d/ == Perl6::Junction::any('a','b','c')),   '== regex negated');
ok( not( qr/[a-z]/ == Perl6::Junction::any(3,4,5)),      '== regex negated');

ok( Perl6::Junction::any(3,4,'a') != qr/\d/,      '!= regex');
ok( Perl6::Junction::any(3,4,'5.0') != qr/^\d+$/, '!= regex');
ok( not( Perl6::Junction::any(3,4,5) != qr/\d/ ), '!= regex negated');

