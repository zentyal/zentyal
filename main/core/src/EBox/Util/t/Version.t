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

use Test::More tests => 7;
use TryCatch::Lite;

use EBox::Util::Version;


is (EBox::Util::Version::compare('1.2', '1.2'), 0, 'Equal version');
is (EBox::Util::Version::compare('1.3', '1.3.1'), -1, 'Major version');
is (EBox::Util::Version::compare('2.0', '1.9.9'), 1, 'Minor version');

# New development versions
is (EBox::Util::Version::compare('3.0~1', '3.0~1'), 0, 'Equal version');
is (EBox::Util::Version::compare('3.0.4', '3.1~1'), -1, 'Major version');
is (EBox::Util::Version::compare('3.1~2', '3.1'), -1, 'Major version');
is (EBox::Util::Version::compare('3.1', '3.1~1'), 1, 'Minor version');

1;
