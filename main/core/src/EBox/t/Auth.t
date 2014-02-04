use strict;
use warnings;

use Test::More tests => 11;
use Test::Exception;
use Test::MockTime();
use Test::Differences;

use Test::MockObject;

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
*EBox::Auth::setPassword = sub {
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
# FIXME: this needs to be fixed
#authen_cred_test();
#authen_ses_key_test();
simultaneousLoginTest();

sub useOkTest
{
    eval 'use EBox::Auth';
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
    dies_ok { EBox::Auth->setPassword($user, '12345')  } "Checking for error with a short password";

    my @passwds = qw(pipadao macaco34 mandril34 ed463fg);
    foreach my $pass (@passwds) {
        lives_ok { EBox::Auth->setPassword($user, $pass) } 'Trying to set new password';
        ok (EBox::Auth->checkValidUser($user, $pass), 'Checking new password');
    }
}

sub authen_cred_test
{
    setUp();
    my $request = _newRequest();

    my $user = 'foo';
    my $passwd = 'macaco';
    EBox::Auth->setPassword($user, $passwd);

    my $badPasswd = $passwd . 'iAmBad';
    ok (!EBox::Auth->authen_cred($request, $badPasswd), 'authen_cred with bad password');

    ok (EBox::Auth->authen_cred($request, $passwd), 'authen_cred with the correct password');
}

sub authen_ses_key_test
{
    setUp();
    my $user = 'admin';

    my $request = _newRequest();
    my $passwd = 'macaco';
    EBox::Auth->setPassword($user, $passwd);
    my $sessionKey = EBox::Auth->authen_cred($request, $passwd);

    $request = _newRequest();
    is (EBox::Auth->authen_ses_key($request, $sessionKey), $user, 'Checking user returned by authen_cred');
    ok (!$request->subprocess_env, 'Checking apache request subprocess_env field is clear ');

    # retry authen_ses after a while
    Test::MockTime::set_relative_time(+NOEXPIRE_TIME);
    $request = _newRequest();
    is (EBox::Auth->authen_ses_key($request, $sessionKey), $user, 'Checking authen_cred again after a while');
    ok (!$request->subprocess_env, 'Checking apache request subprocess_env field is clear ');

    # expiration test
    Test::MockTime::set_relative_time(+EXPIRE_TIME+NOEXPIRE_TIME);
    $request = _newRequest();
    ok !EBox::Auth->authen_ses_key($request, $sessionKey), 'Trying a expired login';
    eq_or_diff $request->subprocess_env(), [LoginReason => 'Expired'], 'See if apache request subprocess_env field marks the login error as expired';

    Test::MockTime::restore();
}

sub simultaneousLoginTest
{
    my $user = 'admin';

    my $request = _newRequest();
    my $passwd = 'macaco';
    EBox::Auth->setPassword($user, $passwd);

    # log first user
    my $firstSessionKey = EBox::Auth->authen_cred($request, $passwd);
    $request = _newRequest();
    EBox::Auth->authen_ses_key($request, $firstSessionKey);

    # try simultaneous login
    $request = _newRequest();
    my $secondSessionKey = EBox::Auth->authen_cred($request, $passwd);
    ok(EBox::Auth->authen_ses_key($request, $secondSessionKey), 'Trying a simultaneous login');
}

sub _newRequest
{
    my ($host) = @_;
    defined $host or $host = '10.0.0.2';

    my $r = Test::MockObject->new();
    $r->mock(headers_in => sub { return { 'X-Real-IP' => $host } });
    $r->mock(subprocess_env =>  sub {
                my $self = shift;
                if (@_) {
                    $self->{subprocess_env} = [@_];
                } else {
                    return $self->{subprocess_env};
                }
            }
    );
    $r->mock(user => sub { return $loggedUser });

    return $r;
}

sub setUp
{
    foreach my $f (EBox::Config::passwd EBox::Config::sessionid) {
        system "rm -f $f";
        ($? == 0) or die $!;
    }
}

1;
