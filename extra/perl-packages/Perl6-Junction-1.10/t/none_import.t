use strict;
use Test::More tests => 76;

BEGIN {
	use_ok('Perl6::Junction', 'none');
}


ok( none(2,3.0) == 4,        '==');
ok( not( none(2,3.0) == 3 ), '== negated');

ok( none(4,4.0) != 4,        '!=');
ok( not( none(3,4,5) != 6 ), '!= negated');

ok( none(3,4,5) >= 6,        '>=');
ok( not( none(3,4,5) >= 4 ), '>= negated');
ok( not( none(3,4,5) >= 2 ), '>= negated');
ok( 2 >= none(3,4,5),        '>= switched');
ok( not( 6 >= none(3,4,5) ), '>= negated switched');
ok( not( 3 >= none(3,4,5) ), '>= negated switched');

ok( none(3,4,5) > 6,        '>');
ok( none(3,4,5) > 5,        '>');
ok( not( none(3,4,5) > 3 ), '> negated');
ok( not( none(3,4,5) > 2 ), '> negated');
ok( 2 > none(3,4,5),        '> switched');
ok( 3 > none(3,4,5),        '> switched');
ok( not( 5 > none(3,4,5) ), '> negated switched');
ok( not( 6 > none(3,4,5) ), '> negated switched');

ok( none(3,4,5) <= 2,        '<=');
ok( not( none(3,4,5) <= 5 ), '<= negated');
ok( not( none(3,4,5) <= 6 ), '<= negated');
ok( 6 <= none(3,4,5),        '<= switched');
ok( not( 2 <= none(3,4,5) ), '<= negated switched');
ok( not( 4 <= none(3,4,5) ), '<= negated switched');
ok( not( 5 <= none(3,4,5) ), '<= negated switched');

ok( none(3,4,5) < 3,        '<');
ok( none(3,4,5) < 2,        '<');
ok( not( none(3,4,5) < 5 ), '< negated');
ok( not( none(3,4,5) < 6 ), '< negated');
ok( 6 < none(3,4,5),        '< switched');
ok( 5 < none(3,4,5),        '< switched');
ok( not( 2 < none(3,4,5) ), '< negated switched');
ok( not( 3 < none(3,4,5) ), '< negated switched');
ok( not( 4 < none(3,4,5) ), '< negated switched');

ok( none('g', 'h') eq 'i',        'eq');
ok( not( none('g', 'h') eq 'g' ), 'eq negated');
ok( not( none('g', 'g') eq 'g' ), 'eq negated');

ok( none('h', 'h') ne 'h',        'ne');
ok( not( none('h', 'i') ne 'i' ), 'ne negated');
ok( not( none('i', 'i') ne 'j' ), 'ne negated');

ok( none('g', 'h') ge 'i',        'ge');
ok( not( none('g', 'h') ge 'g' ), 'ge negated');
ok( not( none('g', 'g') ge 'g' ), 'ge negated');
ok( 'f' ge none('g', 'h'),        'ge switched');
ok( not( 'i' ge none('g', 'h') ), 'ge negated switched');
ok( not( 'g' ge none('g', 'h') ), 'ge negated switched');

ok( none('g', 'h') gt 'h',        'gt');
ok( none('g', 'h') gt 'i',        'gt');
ok( not( none('g', 'h') gt 'f' ), 'gt negated');
ok( not( none('g', 'h') gt 'g' ), 'gt negated');
ok( 'f' gt none('g', 'h'),        'gt switched');
ok( not( 'h' gt none('g', 'h') ), 'gt negated switched');
ok( not( 'i' gt none('g', 'h') ), 'gt negated switched');

ok( none('g', 'h') le 'f',        'le');
ok( not( none('g', 'h') le 'h' ), 'le negated');
ok( not( none('g', 'h') le 'i' ), 'le negated');
ok( 'i' le none('g', 'h'),        'le switched');
ok( not( 'f' le none('g', 'h') ), 'le negated switched');
ok( not( 'g' le none('g', 'h') ), 'le negated switched');

ok( none('g', 'h') lt 'f',        'lt');
ok( not( none('g', 'h') lt 'i' ), 'lt negated');
ok( not( none('g', 'h') lt 'h' ), 'lt negated');
ok( 'i' lt none('g', 'h'),        'lt switched');
ok( not( 'f' lt none('g', 'h') ), 'lt negated switched');
ok( not( 'g' lt none('g', 'h') ), 'lt negated switched');

ok( none('a','b') == qr/\d+/,          '== regex');
ok( qr/^[ab]$/ == none(3,4,5),         '== regex');
ok( not( none(3,4,'b') == qr/[a-z]/ ), '== regex negated');
ok( not( qr/\d/ == none('a','b',5)),   '== regex negated');

ok( none(3,4,5) != qr/[0-9]/,         '!= regex');
ok( qr/[0-9]/ != none(3,4,5),         '!= regex');
ok( none(3,3,5) != qr/./,             '!= regex');
ok( qr/./ != none(3,3,5),             '!= regex');
ok( not( none('a','b',5) != qr/\d/ ), '!= regex negated');
ok( not( qr/\d/ != none('a','b',5) ), '!= regex negated');

