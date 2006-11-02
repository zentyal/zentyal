use strict;
use Test::More tests => 76;

BEGIN {
	use_ok('Perl6::Junction');
}


ok( Perl6::Junction::none(2,3.0) == 4,        '==');
ok( not( Perl6::Junction::none(2,3.0) == 3 ), '== negated');

ok( Perl6::Junction::none(4,4.0) != 4,        '!=');
ok( not( Perl6::Junction::none(3,4,5) != 6 ), '!= negated');

ok( Perl6::Junction::none(3,4,5) >= 6,        '>=');
ok( not( Perl6::Junction::none(3,4,5) >= 4 ), '>= negated');
ok( not( Perl6::Junction::none(3,4,5) >= 2 ), '>= negated');
ok( 2 >= Perl6::Junction::none(3,4,5),        '>= switched');
ok( not( 6 >= Perl6::Junction::none(3,4,5) ), '>= negated switched');
ok( not( 3 >= Perl6::Junction::none(3,4,5) ), '>= negated switched');

ok( Perl6::Junction::none(3,4,5) > 6,        '>');
ok( Perl6::Junction::none(3,4,5) > 5,        '>');
ok( not( Perl6::Junction::none(3,4,5) > 3 ), '> negated');
ok( not( Perl6::Junction::none(3,4,5) > 2 ), '> negated');
ok( 2 > Perl6::Junction::none(3,4,5),        '> switched');
ok( 3 > Perl6::Junction::none(3,4,5),        '> switched');
ok( not( 5 > Perl6::Junction::none(3,4,5) ), '> negated switched');
ok( not( 6 > Perl6::Junction::none(3,4,5) ), '> negated switched');

ok( Perl6::Junction::none(3,4,5) <= 2,        '<=');
ok( not( Perl6::Junction::none(3,4,5) <= 5 ), '<= negated');
ok( not( Perl6::Junction::none(3,4,5) <= 6 ), '<= negated');
ok( 6 <= Perl6::Junction::none(3,4,5),        '<= switched');
ok( not( 2 <= Perl6::Junction::none(3,4,5) ), '<= negated switched');
ok( not( 4 <= Perl6::Junction::none(3,4,5) ), '<= negated switched');
ok( not( 5 <= Perl6::Junction::none(3,4,5) ), '<= negated switched');

ok( Perl6::Junction::none(3,4,5) < 3,        '<');
ok( Perl6::Junction::none(3,4,5) < 2,        '<');
ok( not( Perl6::Junction::none(3,4,5) < 5 ), '< negated');
ok( not( Perl6::Junction::none(3,4,5) < 6 ), '< negated');
ok( 6 < Perl6::Junction::none(3,4,5),        '< switched');
ok( 5 < Perl6::Junction::none(3,4,5),        '< switched');
ok( not( 2 < Perl6::Junction::none(3,4,5) ), '< negated switched');
ok( not( 3 < Perl6::Junction::none(3,4,5) ), '< negated switched');
ok( not( 4 < Perl6::Junction::none(3,4,5) ), '< negated switched');

ok( Perl6::Junction::none('g', 'h') eq 'i',        'eq');
ok( not( Perl6::Junction::none('g', 'h') eq 'g' ), 'eq negated');
ok( not( Perl6::Junction::none('g', 'g') eq 'g' ), 'eq negated');

ok( Perl6::Junction::none('h', 'h') ne 'h',        'ne');
ok( not( Perl6::Junction::none('h', 'i') ne 'i' ), 'ne negated');
ok( not( Perl6::Junction::none('i', 'i') ne 'j' ), 'ne negated');

ok( Perl6::Junction::none('g', 'h') ge 'i',        'ge');
ok( not( Perl6::Junction::none('g', 'h') ge 'g' ), 'ge negated');
ok( not( Perl6::Junction::none('g', 'g') ge 'g' ), 'ge negated');
ok( 'f' ge Perl6::Junction::none('g', 'h'),        'ge switched');
ok( not( 'i' ge Perl6::Junction::none('g', 'h') ), 'ge negated switched');
ok( not( 'g' ge Perl6::Junction::none('g', 'h') ), 'ge negated switched');

ok( Perl6::Junction::none('g', 'h') gt 'h',        'gt');
ok( Perl6::Junction::none('g', 'h') gt 'i',        'gt');
ok( not( Perl6::Junction::none('g', 'h') gt 'f' ), 'gt negated');
ok( not( Perl6::Junction::none('g', 'h') gt 'g' ), 'gt negated');
ok( 'f' gt Perl6::Junction::none('g', 'h'),        'gt switched');
ok( not( 'h' gt Perl6::Junction::none('g', 'h') ), 'gt negated switched');
ok( not( 'i' gt Perl6::Junction::none('g', 'h') ), 'gt negated switched');

ok( Perl6::Junction::none('g', 'h') le 'f',        'le');
ok( not( Perl6::Junction::none('g', 'h') le 'h' ), 'le negated');
ok( not( Perl6::Junction::none('g', 'h') le 'i' ), 'le negated');
ok( 'i' le Perl6::Junction::none('g', 'h'),        'le switched');
ok( not( 'f' le Perl6::Junction::none('g', 'h') ), 'le negated switched');
ok( not( 'g' le Perl6::Junction::none('g', 'h') ), 'le negated switched');

ok( Perl6::Junction::none('g', 'h') lt 'f',        'lt');
ok( not( Perl6::Junction::none('g', 'h') lt 'i' ), 'lt negated');
ok( not( Perl6::Junction::none('g', 'h') lt 'h' ), 'lt negated');
ok( 'i' lt Perl6::Junction::none('g', 'h'),        'lt switched');
ok( not( 'f' lt Perl6::Junction::none('g', 'h') ), 'lt negated switched');
ok( not( 'g' lt Perl6::Junction::none('g', 'h') ), 'lt negated switched');

ok( Perl6::Junction::none('a','b') == qr/\d+/,          '== regex');
ok( qr/^[ab]$/ == Perl6::Junction::none(3,4,5),         '== regex');
ok( not( Perl6::Junction::none(3,4,'b') == qr/[a-z]/ ), '== regex negated');
ok( not( qr/\d/ == Perl6::Junction::none('a','b',5)),   '== regex negated');

ok( Perl6::Junction::none(3,4,5) != qr/[0-9]/,         '!= regex');
ok( qr/[0-9]/ != Perl6::Junction::none(3,4,5),         '!= regex');
ok( Perl6::Junction::none(3,3,5) != qr/./,             '!= regex');
ok( qr/./ != Perl6::Junction::none(3,3,5),             '!= regex');
ok( not( Perl6::Junction::none('a','b',5) != qr/\d/ ), '!= regex negated');
ok( not( qr/\d/ != Perl6::Junction::none('a','b',5) ), '!= regex negated');

