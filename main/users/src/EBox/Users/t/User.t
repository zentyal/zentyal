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

package EBox::Users::User::Test;
use base 'EBox::Test::Class';

use EBox::Global::TestStub;

use Encode;
use Test::More;
use Test::Exception;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub users_group_use_ok : Test(startup => 1)
{
    use_ok('EBox::Users::User') or die;
}

sub checkUserNameLimitations : Test(38)
{
    my ($self) = @_;

    throws_ok {
        EBox::Users::User::_checkUserNameLimitations();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::User::_checkUserNameLimitations(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    lives_ok {
        EBox::Users::User::_checkUserNameLimitations('');
    } 'Empty string';

    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("foo");
    } 'Valid value string';

    throws_ok {
        EBox::Users::User::_checkUserNameLimitations(" foo");
    } 'EBox::Exceptions::InvalidData', 'Leading space';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo ");
    } 'EBox::Exceptions::InvalidData', 'Trailing space';
    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("foo bar");
    } 'Spaces between words';
    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("foo#");
    } 'Hash char';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations(",foo");
    } 'EBox::Exceptions::InvalidData', 'Comma';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo+");
    } 'EBox::Exceptions::InvalidData', 'Plus';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo\"");
    } 'EBox::Exceptions::InvalidData', 'Quote';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo\\");
    } 'EBox::Exceptions::InvalidData', 'Back slash';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo=");
    } 'EBox::Exceptions::InvalidData', 'Equal';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo<");
    } 'EBox::Exceptions::InvalidData', 'Less-than';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo>");
    } 'EBox::Exceptions::InvalidData', 'Greater-than';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo;");
    } 'EBox::Exceptions::InvalidData', 'Semicolon';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo/");
    } 'EBox::Exceptions::InvalidData', 'Slash';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo[");
    } 'EBox::Exceptions::InvalidData', 'Open square bracket';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo]");
    } 'EBox::Exceptions::InvalidData', 'Closing square bracket';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo:");
    } 'EBox::Exceptions::InvalidData', 'Colon';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo|");
    } 'EBox::Exceptions::InvalidData', 'Pipe';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo*");
    } 'EBox::Exceptions::InvalidData', 'Asterisk';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("foo?");
    } 'EBox::Exceptions::InvalidData', 'Question mark';

    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("Prä-Windows 2000 kompatibler Zugriff");
    } 'German characters';
    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("Бухгалтерия");
    } 'Cyrillic characters';

    lives_ok {
        EBox::Users::User::_checkUserNameLimitations("12345");
    } 'Only numbers';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("...");
    } 'EBox::Exceptions::InvalidData', 'Only periods (.)';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("  ");
    } 'EBox::Exceptions::InvalidData', 'Only spaces';
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations("1234  5.");
    } 'EBox::Exceptions::InvalidData', 'Ends with a period (.)';

    my $longer = "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";
    cmp_ok(length $longer, 'gt', 104, "Test string is longer than 104");
    throws_ok {
        EBox::Users::User::_checkUserNameLimitations($longer);
    } 'EBox::Exceptions::InvalidData', 'No names longer than 104 characters';
    my $limit = substr ($longer, 0, 104);
    cmp_ok(length $limit, '==', 104, "Test string is exactly 104 characters long");
    lives_ok {
        EBox::Users::User::_checkUserNameLimitations($limit);
    } 'Exactly 104 characters';
    my $nonascii = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012á";
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', 104, "Test string is exactly 104 characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', 105, "Test string is exactly 105 bytes long due to the non ascii character");
    }
    lives_ok {
        EBox::Users::User::_checkUserNameLimitations($nonascii);
    } 'Accept 104 characters with non ascii chars, even if it is 105 bytes long';
}

1;

END {
    EBox::Users::User::Test->runtests();
}
