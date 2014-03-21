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

package EBox::Ldap::Test;
use base 'EBox::Test::LDAPClass';

use EBox::Global::TestStub;

use Test::More;
use Test::Exception;

sub class
{
    'EBox::Ldap'
}

sub instance : Test(3)
{
    my ($self) = @_;
    my $class = $self->class;

    can_ok($class, 'instance');

    my $ldapInstance = undef;
    ok($ldapInstance = $class->instance(), '... and the constructor should succeed');
    isa_ok($ldapInstance, $class, '... and the object it returns');
}

sub connection : Test(4)
{
    my ($self) = @_;
    my $class = $self->class;

    my $ldapInstance = $class->instance();

    can_ok($ldapInstance, 'connection');

    my $connection = undef;
    ok($connection = $ldapInstance->connection(), 'Got the LDAP connection');
    isa_ok($connection, 'Net::LDAP');
    isa_ok($connection, 'Test::Net::LDAP::Mock');
}

sub url : Test(1)
{
    my ($self) = @_;
    my $class = $self->class;

    cmp_ok($class->url(), 'eq', 'ldapi://%2fvar%2frun%2fslapd%2fldapi', "Getting the LDAP's URL");
}

sub checkSpecialChars : Test(18)
{
    my ($self) = @_;
    my $class = $self->class;

    throws_ok {
        $class->checkSpecialChars();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        $class->checkSpecialChars(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    lives_ok {
        $class->checkSpecialChars('');
    } 'Empty string';

    is($class->checkSpecialChars("foo"), undef, "Valid value string");

    my $expectedError = "cannot start or end with a space, and should not have any of the following characters: #,+\"\\=<>;";
    cmp_ok($class->checkSpecialChars(" foo"), 'eq', $expectedError, "Leading space");
    cmp_ok($class->checkSpecialChars("foo "), 'eq', $expectedError, "Trailing space");
    is($class->checkSpecialChars("foo bar"), undef, "Spaces between words");
    cmp_ok($class->checkSpecialChars("foo#"), 'eq', $expectedError, "Hash char");
    cmp_ok($class->checkSpecialChars(",foo"), 'eq', $expectedError, "Comma");
    cmp_ok($class->checkSpecialChars("foo+"), 'eq', $expectedError, "Plus");
    cmp_ok($class->checkSpecialChars("foo\""), 'eq', $expectedError, "Quote");
    cmp_ok($class->checkSpecialChars("foo\\"), 'eq', $expectedError, "Back slash");
    cmp_ok($class->checkSpecialChars("foo="), 'eq', $expectedError, "Equal");
    cmp_ok($class->checkSpecialChars("foo<"), 'eq', $expectedError, "Less-than");
    cmp_ok($class->checkSpecialChars("foo>"), 'eq', $expectedError, "Greater-than");
    cmp_ok($class->checkSpecialChars("foo;"), 'eq', $expectedError, "Semicolon");

    is($class->checkSpecialChars("Prä-Windows 2000 kompatibler Zugriff"), undef, "German characters");
    is($class->checkSpecialChars("Бухгалтерия"), undef, "Cyrillic characters");
}

1;

END {
    EBox::Ldap::Test->runtests();
}
