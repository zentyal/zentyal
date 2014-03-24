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

package EBox::Samba::Group::Test;
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
    use_ok('EBox::Samba::Group') or die;
}

sub checkGroupNameLimitations : Test(42)
{
    my ($self) = @_;

    my $maxLen = EBox::Samba::Group::MAXGROUPLENGTH();
    throws_ok {
        EBox::Samba::Group->_checkGroupNameLimitations();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Samba::Group->_checkGroupNameLimitations(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @valid = (
        'foo',
        'foo bar',
        'Prä-Windows 2000 kompatibler Zugriff',
        'Бухгалтерия',
        'user-slash_',
        '-startslash',
        'problematic&characters'
    );

    my @invalid = (
        '',
        ' foo',
        'foo ',
        'foo#',
        ',foo',
        'foo+',
        'foo"',
        'foo\\',
        'foo=',
        'foo<',
        'foo>',
        'foo;',
        'foo/',
        'foo[',
        'foo]',
        'foo:',
        'foo|',
        'foo*',
        'foo?',
        '12345',
        '...',
        '   ',
        '1234 5.45',
        'enddot.'
    );

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalid, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@valid, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@valid, $nonascii);

    foreach my $validName (@valid) {
        lives_ok {
            EBox::Samba::Group->_checkGroupNameLimitations($validName);
        } "Checking that '$validName' is a correct group account name";
    }
    foreach my $invalidName (@invalid) {
        throws_ok {
            EBox::Samba::Group->_checkGroupNameLimitations($invalidName);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalidName' throws exception as invalid group account name";
    }

}

1;

END {
    EBox::Samba::Group::Test->runtests();
}
