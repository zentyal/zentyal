use strict;
use warnings;

use Test::More tests => 26;
use Test::Exception;
use Test::MockTime();
use Test::Differences;

use Test::MockObject;

use lib '../..';
use EBox::TestStub;
use EBox::Global::TestStub;
use EBox::Config::TestStub;
use Apache2::Connection;


use constant {
    EXPIRE_TIME   => 3601,
    NOEXPIRE_TIME => 3000,
};

use lib '../..';

useOkTest();
globalSetUp();
setAndCheckPasswdTest();
authen_cred_test();
authen_ses_key_test();
alreadyLoggedTest();
simultaneousLoginTest();
defaultPasswdChangedTest();

sub useOkTest
{
 Test::MockObject->fake_module('EBox::LogAdmin',
				logAdminNow      => sub {},
				logAdminDeferred => sub {},
				commitPending    => sub {},
				rollbackPending  => sub {},
				pendingActions   => sub {},
			       );

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
  EBox::Config::TestStub::fake(passwd => $passwd, sessionid => $sessionid );

  EBox::TestStub::fake();
  EBox::Global::TestStub::fake();

}


sub setAndCheckPasswdTest
{
    setUp();
    my $auth        = new EBox::Auth;  

    # passwd too short
    dies_ok { $auth->setPassword('12345')  } "Checking for error with a short password";

    my @passwds     = qw(pipadao macaco34 mandril34 ed463fg);
    foreach my $pass (@passwds) {
	lives_ok {  $auth->setPassword($pass) } 'Trying to set new password';
	ok $auth->checkPassword($pass, $pass), 'Checking new password';
    }

}

sub authen_cred_test
{
    setUp();
  my $auth        = new EBox::Auth;
  my $request = _newRequest();

  my $passwd = 'macaco';
  $auth->setPassword($passwd);

  my $badPasswd = $passwd . 'iAmBad';
  ok !$auth->authen_cred($request, $badPasswd), 'authen_cred with bad password';
  
  ok $auth->authen_cred($request, $passwd), 'authen_cred with the correct password';

}


sub authen_ses_key_test
{
    setUp();
  my $auth        = new EBox::Auth;
  my $user        = 'admin';

  my $request = _newRequest();
  my $passwd = 'macaco';
  $auth->setPassword($passwd);
  my $sessionKey = $auth->authen_cred($request, $passwd);

  $request = _newRequest();
  is $auth->authen_ses_key($request, $sessionKey), $user, 'Checking user returned by authen_cred';
  ok !$request->subprocess_env, 'Checking apache request subprocess_env field is clear ';


    # retry authen_ses after a while
    Test::MockTime::set_relative_time(+NOEXPIRE_TIME);
  $request = _newRequest();
  is $auth->authen_ses_key($request, $sessionKey), $user, 'Checking authen_cred again after a while';
  ok !$request->subprocess_env, 'Checking apache request subprocess_env field is clear ';

  # expiration test
  Test::MockTime::set_relative_time(+EXPIRE_TIME+NOEXPIRE_TIME);
  $request = _newRequest();
  ok !$auth->authen_ses_key($request, $sessionKey), 'Trying a expired login';
  eq_or_diff $request->subprocess_env(), [LoginReason => 'Expired'], 'See if apache request subprocess_env field marks the login error as expired';
  
    Test::MockTime::restore();
}


sub alreadyLoggedTest
{
    setUp();

    my $auth        = new EBox::Auth;

    ok !$auth->alreadyLogged(), 'alreadyLogged when no login has happened';


    my $passwd = 'macaco';
    $auth->setPassword($passwd);
    my $request = _newRequest();

    # unsuccessful login
    $auth->authen_cred($request, $passwd . 'bad'); 
    ok !$auth->alreadyLogged(), 'alreadyLogged after a unsuccessful login';

    # successful login..
    $auth->authen_cred($request, $passwd); 
    ok $auth->alreadyLogged(), 'alreadyLogged after a successful login';

    # retry after a while..
    Test::MockTime::set_relative_time(+NOEXPIRE_TIME);
    ok $auth->alreadyLogged(), 'alreadyLogged after a while since login';

    # expired session
    Test::MockTime::set_relative_time(+EXPIRE_TIME+NOEXPIRE_TIME);
    ok !$auth->alreadyLogged(), 'alreadyLogged with a expired session';


}

sub simultaneousLoginTest
{
  my $auth        = new EBox::Auth;
  my $user        = 'admin';

  my $request = _newRequest();
  my $passwd = 'macaco';
  $auth->setPassword($passwd);

  # log first user ..
  my $firstSessionKey = $auth->authen_cred($request, $passwd);
  $request = _newRequest();
  $auth->authen_ses_key($request, $firstSessionKey); 

  # try simultaneous login

  $request = _newRequest();
  my $secondSessionKey = $auth->authen_cred($request, $passwd);
  ok $auth->authen_ses_key($request, $secondSessionKey), 'Trying a simultaneous login';
 }



sub defaultPasswdChangedTest
{
    setUp();

    my $auth        = new EBox::Auth;

    resetDefaultPasswd();
    is $auth->defaultPasswdChanged(), undef, 'Checking defaultPasswdChanged with default password';

    $auth->setPassword('12345678');
    is $auth->defaultPasswdChanged(), 1, 'Checking defaultPasswdChanged after changig default passwd';


}

sub _newRequest
{
  my ($host) = @_;
  defined $host or $host = '10.0.0.2';

  my $r = Test::MockObject->new();
  $r->mock(connection => mock(get_remote_host => sub { return $host }  ));
  $r->mock(subprocess_env =>  sub {
	     my $self = shift;
	     if (@_) {
	       $self->{subprocess_env} = [@_];
	     }
	     else {
	        return $self->{subprocess_env};
	     }
	   } );

  return $r;
}


sub setUp
{
    foreach my $f (EBox::Config::passwd EBox::Config::sessionid) {
	system "rm -f $f";
	($? == 0) or die $!;
    }
}

sub resetDefaultPasswd
  {
    my $passwd = 'ebox';
    open(my $PASSWD_F, "> ". EBox::Config->passwd) or die ('Could not open passwd file');
    
    my $md5 = Digest::MD5->new;
    $md5->add($passwd);
    my $encpasswd = $md5->hexdigest;

    print $PASSWD_F $encpasswd;
    close($PASSWD_F);
}
1;
