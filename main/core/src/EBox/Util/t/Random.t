# Copyright (C) 2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
use strict;
use warnings;

use Test::Exception;
use Test::More tests => 4;
use EBox::Util::Random;

throws_ok {
    EBox::Util::Random::generate(-1);
} 'EBox::Exceptions::Internal', 'Bad length argument';

my $random = EBox::Util::Random::generate(10);
cmp_ok(length($random), '==', 10, 'The length of the random string is set properly');
ok($random =~ m{^[a-zA-Z0-9@/=]+$}g,
   'The random strings have the proper values');

ok(EBox::Util::Random::generate(8, [qw(a b)]) =~ m{^[ab]+$}, 'Only valid string is returned');

1;
