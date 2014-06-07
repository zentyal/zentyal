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

package EBox::Samba::LdapObject::Test;

use EBox::Global::TestStub;
use base 'EBox::Test::LDAPClass';

use Test::More;

sub class
{
    'EBox::Samba::LdapObject'
}

sub _objectGUIDToString : Test(1)
{
    my ($self) = @_;
    my $class = $self->class;

    my $exampleBinary = pack('H*', '09f976995c580548915e4976ab3a4317');
    my $expectedOutput = '9976f909-585c-4805-915e-4976ab3a4317';

    my $stringObjectGUID = $class->_objectGUIDToString($exampleBinary);
    cmp_ok($stringObjectGUID, 'eq', $expectedOutput, "_objectGUIDToString");
}

sub _stringToObjectGUID : Test(1)
{
    my ($self) = @_;
    my $class = $self->class;

    my $exampleString = '9976f909-585c-4805-915e-4976ab3a4317';
    my $expectedOutput = pack('H*', '09f976995c580548915e4976ab3a4317');

    my $objectGUID = $class->_stringToObjectGUID($exampleString);
    cmp_ok($objectGUID, 'eq', $expectedOutput, '_stringToObjectGUID');
}

1;

END {
    EBox::Samba::LdapObject::Test->runtests();
}
