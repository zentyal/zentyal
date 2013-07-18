# Copyright (C) 2013 Zentyal S.L.
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

# class: EBox::Test::LDBClass
#
#  This class is intended to use as base, replacing Test:Class and EBox::Test::Class, to build LDAP's test classes
#
package EBox::Test::LDBClass;
use base 'EBox::Test::LDAPClass';

use EBox::Config;

use Test::More;

# Method: _testStubsSetFiles
#
#   Initialises some status files required to test LDB based code.
#
# Overrides: EBox::Test::LDAPClass::_testStubsSetFiles
#
sub _testStubsSetFiles
{
    # Created empty s4sync ignore files.
    my $etcDir = EBox::Config::etc();
    system ("touch $etcDir/s4sync-sids.ignore");
    system ("touch $etcDir/s4sync-groups.ignore");
}

1;
