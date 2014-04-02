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

sub generatedFullname : Test(18)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXFULLNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname();
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname(foo => 'bar');
    } 'EBox::Exceptions::MissingArgument', 'No required arguments';

    my $maxLenFirstname = EBox::Users::InetOrgPerson::MAXFIRSTNAMELENGTH();
    my $longerFirstname = 'l' x ($maxLenFirstname + 1);
    cmp_ok(length $longerFirstname, 'gt', $maxLenFirstname, "Test firstname string is longer than $maxLenFirstname");
    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname(givenname => $longerFirstname);
    } 'EBox::Exceptions::InvalidData', "Checking that '$longerFirstname' throws exception as invalid firstname";

    my $exactLengthFirstname = 'l' x $maxLenFirstname;
    cmp_ok(length $exactLengthFirstname, '==', $maxLenFirstname, "Test firstname string is exactly $maxLenFirstname characters long");
    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(givenname => $exactLengthFirstname),
        'eq', $exactLengthFirstname, 'Fullname is exactly the givenname');

    my $maxLenInitials = EBox::Users::InetOrgPerson::MAXINITIALSLENGTH();
    my $longerInitials = 'l' x ($maxLenInitials + 1);
    cmp_ok(length $longerInitials, 'gt', $maxLenInitials, "Test initials string is longer than $maxLenInitials");
    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname(initials => $longerInitials);
    } 'EBox::Exceptions::InvalidData', "Checking that '$longerInitials' throws exception as invalid initials";

    my $exactLengthInitials = 'l' x $maxLenInitials;
    cmp_ok(length $exactLengthInitials, '==', $maxLenInitials, "Test initials string is exactly $maxLenInitials characters long");
    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(initials => $exactLengthInitials),
        'eq', "$exactLengthInitials.", 'Fullname is initials ended with a dot');

    my $maxLenSurname = EBox::Users::InetOrgPerson::MAXSURNAMELENGTH();
    my $longerSurname = 'l' x ($maxLenSurname + 1);
    cmp_ok(length $longerSurname, 'gt', $maxLenSurname, "Test surname string is longer than $maxLenSurname");
    throws_ok {
        EBox::Users::InetOrgPerson->generatedFullname(surname => $longerSurname);
    } 'EBox::Exceptions::InvalidData', "Checking that '$longerSurname' throws exception as invalid surname";

    my $exactLengthSurname = 'l' x $maxLenSurname;
    cmp_ok(length $exactLengthSurname, '==', $maxLenSurname, "Test surname string is exactly $maxLenSurname characters long");
    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(surname => $exactLengthSurname),
        'eq', $exactLengthSurname, 'Fullname is exactly the firstname');

    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(
            givenname => 'first name', initials => '123456', surname => 'surname'),
        'eq', 'first name 123456. surname', 'Well generated fullname with all input parameters');

    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(
            givenname => $exactLengthFirstname, initials => $exactLengthInitials, surname => $exactLengthSurname),
        'eq', $exactLengthFirstname, 'Fullname is exactly the firstname, we had to truncate it');

    cmp_ok(
        EBox::Users::InetOrgPerson->generatedFullname(
            initials => $exactLengthInitials, surname => $exactLengthSurname),
        'eq', "$exactLengthInitials. " . substr($exactLengthSurname, 0, $maxLen - $maxLenInitials - 2), 'Fullname is initials + a truncated long surname');
}

sub checkFirstnameFormat : Test(10)
{
    my ($self) = @_;

    my $maxLen = EBox::Users::InetOrgPerson::MAXFIRSTNAMELENGTH();

    throws_ok {
        EBox::Users::InetOrgPerson->checkFirstnameFormat();
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkFirstnameFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkInitialsFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkSurnameFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkFullnameFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkDisplaynameFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkDescriptionFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
    } 'EBox::Exceptions::MissingArgument', 'Without passing any argument';

    throws_ok {
        EBox::Users::InetOrgPerson->checkMailFormat(undef);
    } 'EBox::Exceptions::MissingArgument', 'Passing an undef argument';

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
