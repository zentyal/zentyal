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

use Test::More tests => 10;
use Test::Exception;
use TryCatch;

use EBox::Exceptions::MissingArgument;
use EBox::Util::Version;


is (EBox::Util::Version::compare('1.2', '1.2'), 0, 'Same version (1.2 == 1.2)');
is (EBox::Util::Version::compare('1.3', '1.3.1'), -1, 'Newer version (1.3.1 > 1.3)');
is (EBox::Util::Version::compare('2.0', '1.9.9'), 1, 'Older version (1.9.9 < 2.0)');

# New development versions
is (EBox::Util::Version::compare('3.0~1', '3.0~1'), 0, 'Same version (3.0~1 == 3.0~1)');
is (EBox::Util::Version::compare('3.0.4', '3.1~1'), -1, 'Newer version (3.1~1 > 3.0.4)');
is (EBox::Util::Version::compare('3.1~2', '3.1'), -1, 'Newer version (3.1 > 3.1~2');
is (EBox::Util::Version::compare('3.1', '3.1~1'), 1, 'Older version (3.1~1 < 3.1~1)');

throws_ok {
    EBox::Util::Version::compare('3.1');
} 'EBox::Exceptions::MissingArgument', 'Missing second argument';
throws_ok {
    EBox::Util::Version::compare();
} 'EBox::Exceptions::MissingArgument', 'Missing all arguments';
throws_ok {
    EBox::Util::Version::compare(undef, '3.1');
} 'EBox::Exceptions::MissingArgument', 'Missing first argument';


1;
