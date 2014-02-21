use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use Test::MockTime();
use Test::Differences;

use lib '../..';
use EBox::TestStub;
use EBox::Global::TestStub;
use EBox::Config::TestStub;

*EBox::Config::modules = sub { return 'core/schemas/'; };

use constant {
    EXPIRE_TIME   => 3601,
    NOEXPIRE_TIME => 3000,
};

use lib '../..';

useOkTest();

# FIXME: this is really quick&dirty, proper mockups should be implemented
my %userPwds;
my $loggedUser;

*EBox::Middleware::AuthPAM::setPassword = sub {
    my ($self, $user, $pass) = @_;

    die if (length($pass) < 6);
    $userPwds{$user} = $pass;
};

*Authen::Simple::PAM::authenticate = sub {
    my ($self, $user, $pass) = @_;

    my $authOk = ($userPwds{$user} eq $pass);
    if ($authOk) {
        $loggedUser = $user;
    }
    return $authOk;
};

globalSetUp();
setAndCheckPasswdTest();

sub useOkTest
{
    eval 'use EBox::Middleware::AuthPAM';
    ok !$@, 'Module use test';
}

sub globalSetUp
{
    my $testDir = '/tmp/ebox.auth.test';
    system "rm -rf $testDir";
    ($? == 0) or die "Error deleting $testDir: $!";
    mkdir $testDir or die "Error creating $testDir";

    my $passwd = "$testDir/passwd";
    my $sessionid = "$testDir/sessionid";
    EBox::Config::TestStub::fake(passwd => $passwd, sessionid => $sessionid);

    EBox::TestStub::fake();
    EBox::Global::TestStub::fake();
}

sub setAndCheckPasswdTest
{
    setUp();

    my $user = 'foo';

    # passwd too short
    dies_ok { EBox::Middleware::AuthPAM->setPassword($user, '12345')  } "Checking for error with a short password";

    my @passwds = qw(pipadao macaco34 mandril34 ed463fg);
    foreach my $pass (@passwds) {
        lives_ok { EBox::Middleware::AuthPAM->setPassword($user, $pass) } 'Trying to set new password';
        ok (EBox::Middleware::AuthPAM->checkValidUser($user, $pass), 'Checking new password');
    }
}

sub setUp
{
    foreach my $f (EBox::Config::passwd EBox::Config::sessionid) {
        system "rm -f $f";
        ($? == 0) or die $!;
    }
}

1;
