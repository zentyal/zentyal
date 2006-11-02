use strict;
use Test::More tests => 69;

BEGIN {
	use_ok('Perl6::Junction', 'any');
}


ok( any(2,3.0) == 2,        '==');
ok( any(2,3.0) == 3,        '==');
ok( not( any(2,3.0) == 4 ), '== negated');

ok( any(3,4.0) != 4,        '!=');
ok( any(4,5.0) != 4,        '!=');
ok( not( any(3,3.0) != 3 ), '!= negated');

ok( any(3,4,5) >= 5,        '>=');
ok( any(3,4,5) >= 2,        '>=');
ok( not( any(3,4,5) >= 6 ), '>= negated');
ok( 6 >= any(3,4,5),        '>= switched');
ok( 3 >= any(3,4,5),        '>= switched');
ok( not( 2 >= any(3,4,5) ), '>= negated switched');

ok( any(3,4,5) > 2,        '>');
ok( any(3,4,5) > 3,        '>');
ok( not( any(3,4,5) > 6 ), '> negated');
ok( 6 > any(3,4,5),        '> switched');
ok( 4 > any(3,4,5),        '> switched');
ok( not( 2 > any(3,4,5) ), '> negated switched');

ok( any(3,4,5) <= 5,        '<=');
ok( any(3,4,5) <= 6,        '<=');
ok( not( any(3,4,5) <= 2 ), '<= negated');
ok( 5 <= any(3,4,5),        '<= switched');
ok( 2 <= any(3,4,5),        '<= switched');
ok( not( 6 <= any(3,4,5) ), '<= negated switched');

ok( any(3,4,5) < 6,        '<');
ok( any(5,4,3) < 4,        '<');
ok( not( any(3,4,5) < 2 ), '< negated');
ok( 2 < any(3,4,5),        '< switched');
ok( 4 < any(3,4,5),        '< switched');
ok( not( 6 < any(3,4,5) ), '< negated switched');

ok( any('g', 'h') eq 'g',        'eq');
ok( any('g', 'g') eq 'g',        'eq');
ok( not( any('g', 'h') eq 'i' ), 'eq negated');

ok( any('g', 'h') ne 'g',        'ne');
ok( not( any('i', 'i') ne 'i' ), 'ne negated');

ok( any('g', 'h') ge 'f',        'ge');
ok( any('g', 'h') ge 'g',        'ge');
ok( not( any('g', 'h') ge 'i' ), 'ge negated');
ok( 'i' ge any('g', 'h'),        'ge switched');
ok( 'g' ge any('g', 'f'),        'ge switched');
ok( not( 'f' ge any('g', 'h') ), 'ge negated switched');

ok( any('g', 'h') gt 'f',        'gt');
ok( any('g', 'h') gt 'g',        'gt');
ok( not( any('g', 'h') gt 'i' ), 'gt negated');
ok( 'i' gt any('h', 'g'),        'gt switched');
ok( 'h' gt any('h', 'g'),        'gt switched');
ok( not( 'g' gt any('g', 'h') ), 'gt negated switched');
ok( not( 'f' gt any('g', 'h') ), 'gt negated switched');

ok( any('g', 'h') le 'i',        'le');
ok( any('g', 'f') le 'g',        'le');
ok( not( any('g', 'h') le 'f' ), 'le negated');
ok( 'f' le any('g', 'h'),        'le switched');
ok( 'g' le any('h', 'g'),        'le switched');
ok( not( 'i' le any('g', 'h') ), 'le negated switched');

ok( any('g', 'h') lt 'i',        'lt');
ok( any('h', 'g') lt 'h',        'lt');
ok( not( any('g', 'h') lt 'f' ), 'lt negated');
ok( 'f' lt any('g', 'h'),        'lt switched');
ok( 'g' lt any('h', 'g'),        'lt switched');
ok( not( 'i' lt any('g', 'h') ), 'lt negated switched');

ok( any(3,'b') == qr/\d+/,              '== regex');
ok( qr/^[ab]$/ == any('a',4),           '== regex');
ok( not( any('a','b','c') == qr/\d+/ ), '== regex negated');
ok( not( qr/\d/ == any('a','b','c')),   '== regex negated');
ok( not( qr/[a-z]/ == any(3,4,5)),      '== regex negated');

ok( any(3,4,'a') != qr/\d/,      '!= regex');
ok( any(3,4,'5.0') != qr/^\d+$/, '!= regex');
ok( not( any(3,4,5) != qr/\d/ ), '!= regex negated');

