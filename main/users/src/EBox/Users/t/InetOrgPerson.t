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

package EBox::Users::InetOrgPerson::Test;
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
    use_ok('EBox::Users::InetOrgPerson') or die;
}

sub checkFirstnameFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXFIRSTNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkFirstnameFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkFirstnameFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkFirstnameFormat($valid);
        } "Checking that '$valid' is a correct first name";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkFirstnameFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid first name";
    }
}

sub checkInitialsFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXINITIALSLENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkInitialsFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkInitialsFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkInitialsFormat($valid);
        } "Checking that '$valid' is a correct initials";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkInitialsFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid initials";
    }
}

sub checkSurnameFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXSURNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkSurnameFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkSurnameFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkSurnameFormat($valid);
        } "Checking that '$valid' is a correct surname";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkSurnameFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid surname";
    }
}

sub checkFullnameFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXFULLNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkFullnameFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkFullnameFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkFullnameFormat($valid);
        } "Checking that '$valid' is a correct fullname";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkFullnameFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid fullname";
    }
}

sub checkDisplaynameFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXDISPLAYNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkDisplaynameFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkDisplaynameFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkDisplaynameFormat($valid);
        } "Checking that '$valid' is a correct displayname";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkDisplaynameFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid displayname";
    }
}

sub checkDescriptionFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXDESCRIPTIONLENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkDescriptionFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkDescriptionFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkDescriptionFormat($valid);
        } "Checking that '$valid' is a correct description";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkDescriptionFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid description";
    }
}

sub checkMailFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXMAILLENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkMailFormat();
    } 'EBox::Exceptions::InvalidArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkMailFormat(undef);
    } 'EBox::Exceptions::InvalidArgument', 'Passing an undef argument';

    my @validList = ();

    my @invalidList = ();

    my $longer = 'l' x ($maxLen + 1);
    cmp_ok(length $longer, 'gt', $maxLen, "Test string is longer than $maxLen");
    push (@invalidList, $longer);
    my $exactLength = 'l' x $maxLen;
    cmp_ok(length $exactLength, '==', $maxLen, "Test string is exactly $maxLen characters long");
    push (@validList, $exactLength);
    my $nonascii = ('l' x ($maxLen - 1)) . 'á';
    utf8::decode($nonascii);
    ok(utf8::is_utf8($nonascii), "It's a UTF-8 string");
    cmp_ok(length $nonascii, '==', $maxLen, "Test string is exactly $maxLen characters long even with non ascii characters");
    {
        use bytes;
        cmp_ok(bytes::length($nonascii), '==', $maxLen + 1, "Test string is exactly " . ($maxLen + 1) . " bytes long due to the non ascii character");
    }
    push (@validList, $nonascii);

    foreach my $valid (@validList) {
        lives_ok {
            EBox::Users::InetOrgPerson->checkMailFormat($valid);
        } "Checking that '$valid' is a correct mail";
    }
    foreach my $invalid (@invalidList) {
        throws_ok {
            EBox::Users::InetOrgPerson->checkMailFormat($invalid);
        } 'EBox::Exceptions::InvalidData', "Checking that '$invalid' throws exception as invalid mail";
    }
}

1;

END {
    EBox::Users::InetOrgPerson::Test->runtests();
}
