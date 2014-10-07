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

use Test::More tests => 5;

use_ok('EBox::Util::FileSize');

cmp_ok(EBox::Util::FileSize::printableSize(12), 'eq', '12 B');
cmp_ok(EBox::Util::FileSize::printableSize(1035), 'eq', '1.01 KB');
cmp_ok(EBox::Util::FileSize::printableSize(103523232), 'eq', '98.73 MB');
cmp_ok(EBox::Util::FileSize::printableSize(1232323211111), 'eq', '1147.69 GB');

1;
