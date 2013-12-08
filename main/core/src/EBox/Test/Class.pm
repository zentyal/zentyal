# Copyright (C) 2006-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::Test::Class;
# class: EBox::Test::Class
#
#  This class is intended to use as base, replacing Test:Class, to build eBox's test classes
#
use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::Exception;


use EBox::Test;;
use EBox::TestStubs;

sub _testStubsForFrameworkModules :  Test(startup) {
    EBox::TestStubs::activateTestStubs();
}






1;
