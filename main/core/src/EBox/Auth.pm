# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Auth;
use base qw(Apache2::AuthCookie);

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::Lock;

use Apache2::Connection;
use Apache2::Const qw(:common HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);

use Authen::Simple::PAM;
use Digest::MD5;
use Fcntl qw(:flock);

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds

# Remote access constants
use constant CC_USER => '__remote_access__';

# Method: _savesession
#
# Parameters:
#
#   - session id : if the id is undef, it truncates the session file
# Exceptions:
#   - Internal
#       - When session file cannot be opened to write
sub _savesession # (session_id)
{
    my ($sid, $user) = @_;

    my $sessionPath = EBox::Config->sessionid();

    my $sidFile;
    my $openMode = '>';
    if (-f $sessionPath) {
        $openMode = '+<';
    }
    unless (open ($sidFile, $openMode, $sessionPath)) {
        throw EBox::Exceptions::Internal( "Could not open to write ".  EBox::Config->sessionid);
    }
    # Lock the file in exclusive mode
    flock($sidFile, LOCK_EX)
        or throw EBox::Exceptions::Lock('EBox::Auth');
    # Truncate the file after locking
    truncate($sidFile, 0);
    my $time = time();
    print $sidFile "$sid\t$time\t$user" if defined $sid;
    # Release the lock
    flock($sidFile, LOCK_UN);
    close($sidFile);
}

# Method: checkValidUser
#
#       Check with PAM if the user/password provided is of a valid admin
#
# Parameters:
#
#       username - string containing the user name
#       password - string containing the plain password
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
sub checkValidUser
{
    my ($self, $username, $password) = @_;

    my $pam = new Authen::Simple::PAM(service => 'zentyal');

    return $pam->authenticate($username, $password);
}

# Method: setPassword
#
#       Changes the password of the given username
#
# Parameters:
#
#       username - username to change the password
#       password - string containing the plain password
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - when password cannot be changed
#   <EBox::Exceptions::External> - when password length is no
#                                  longer than 6 characters
sub setPassword
{
    my ($self, $username, $password) = @_;

    unless (length($password) > 5) {
        throw EBox::Exceptions::External('The password must be at least 6 characters long');
    }

    open(my $pipe, "|/usr/bin/sudo /usr/sbin/chpasswd") or
        throw EBox::Exceptions::Internal("Could not change password: $!");

    print $pipe "$username:$password\n";
    close($pipe);
}

# Method: authen_cred
#
#       Overriden method from <Apache2::AuthCookie>.
#
sub authen_cred  # (request, $user, password, fromCC)
{
    my ($self, $r, $user, $passwd, $fromCC) = @_;

    # If there's a script session opened, give it priority to the
    # Web interface session
    if ($self->_actionScriptSession()) {
        EBox::warn('Failed login since a script session is opened');
        $r->subprocess_env(LoginReason => 'Script active');
        return;
    }

    my $ip = $r->headers_in->{'X-Real-IP'};
    my $audit = $self->_global()->modInstance('audit');
    # Unless it is a CC session or password does
    unless ($fromCC) {
        unless ($self->checkValidUser($user, $passwd)) {
            my $log = EBox->logger();
            $log->warn("Failed login from: $ip");
            $audit->logSessionEvent($user, $ip, 'fail');
            return;
        }
    }
    $r->user($user);
    $audit->logSessionEvent($user, $ip, 'login');

    my $rndStr;
    for my $i (1..64) {
        $rndStr .= rand (2**32);
    }
    my $md5 = Digest::MD5->new();
    $md5->add($rndStr);
    my $sid = $md5->hexdigest();
    _savesession($sid, $user);

    return $sid;
}

# Method: authen_ses_key
#
#       Overriden method from <Apache2::AuthCookie>.
#
sub authen_ses_key  # (request, session_key)
{
    my ($self, $r, $session_key) = @_;

    my $global = $self->_global();

    my ($sid, $lastime, $user) = _currentSessionId();

    my $expired =  _timeExpired($lastime);

    if ($self->_actionScriptSession()) {
        $r->subprocess_env(LoginReason => 'Script active');
        _savesession(undef);
    }
    elsif (($session_key eq $sid) and (!$expired)) {
        my $audit = $global->modInstance('audit');
        $audit->setUsername($user);

        _savesession($sid, $user);
        return $user;
    }
    elsif ($expired) {
        my $audit = $global->modInstance('audit');
        my $ip = $r->headers_in->{'X-Real-IP'};
        $audit->logSessionEvent($user, $ip, 'expired');

        $r->subprocess_env(LoginReason => "Expired");
        _savesession(undef);
    }
    else {
        $r->subprocess_env(LoginReason => "Already");
    }

    return;
}

# Method: loginCC
#
#      Login from Control Center, which is different if the
#      passwordless option is activated
#
# Parameters:
#
#      request - <Apache2::RequestRec> the HTTP request
#
# Return:
#
#     the same response as <Apache2::AuthCookie::login> gives back
#
sub loginCC
{
    my ($self, $req) = @_;

    if ( $self->recognize_user($req) == OK ) {
        my $retVal = $self->authenticate($req);
        if ($req->uri() =~ m:^/ebox:) {
            $req->headers_out()->set('Location' => '/');
            return HTTP_MOVED_TEMPORARILY;
        }
        return $retVal;
    } else {
        my $global = $self->_global();
        if ($global->modExists('remoteservices')) {
            my $remoteServMod = $global->modInstance('remoteservices');
            if ( $remoteServMod->eBoxSubscribed()
                 and $remoteServMod->model('AccessSettings')->passwordlessValue()) {
                # Do what login does
                my $sessionKey = $self->authen_cred($req, CC_USER, '', 1);
                $self->send_cookie($req, $sessionKey);
                $self->handle_cache($req);
                $req->headers_out()->set('Location' => '/');
                return HTTP_MOVED_TEMPORARILY;
            }
        }
        EBox::initLogger('eboxlog.conf');
        EBox::CGI::Run->run('/Login/Index', 'EBox');
        return OK;
    }
}

# Method: logout
#
#       Overriden method from <Apache2::AuthCookie>.
#
sub logout
{
    my ($self,$r) = @_;

    $self->SUPER::logout($r);

    my $audit = $self->_global()->modInstance('audit');
    my $ip = $r->headers_in->{'X-Real-IP'};
    my $user = $r->user();
    $audit->logSessionEvent($user, $ip, 'logout');
}

# scalar mode: return the sessionid
# list mode:   return (sessionid, lastime)
sub _currentSessionId
{
    my $SID_F; # sid file handle
    my $sessionPath = EBox::Config->sessionid();
    unless(-e $sessionPath) {
        unless (open ($SID_F,  ">". $sessionPath)) {
            throw EBox::Exceptions::Internal("Could not create  " . EBox::Config->sessionid);
        }
        close($SID_F);
        return;
    }
    unless (open ($SID_F, $sessionPath)) {
        throw EBox::Exceptions::Internal("Could not open ".  EBox::Config->sessionid);
    }

    # Lock in shared mode for reading
    flock($SID_F, LOCK_SH)
        or throw EBox::Exceptions::Lock('EBox::Auth');

    $_ = <$SID_F>;
    my ($sid, $lastime, $user) = split /\t/ if defined $_;

    # Release the lock
    flock($SID_F, LOCK_UN);
    close($SID_F);

    if (wantarray()) {
        return ($sid, $lastime, $user);
    }
    else {
        return $sid;
    }
}

sub _timeExpired
{
    my ($lastime) = @_;

    my $expires = $lastime + EXPIRE;

    my $expired = (time() > $expires);
    return $expired;
}

# Method: _actionScriptSession
#
#       Check whether a script session is already opened or not
#
# Returns:
#
#       Boolean - indicate if a script session is already opened
#
sub _actionScriptSession
{

    my ($self) = @_;

    # The script session filehandle
    my $scriptSessionFile;

    unless (-e EBox::Config->scriptSession()) {
        return undef;
    }

    # Trying to open the script sid
    open ($scriptSessionFile, '<', EBox::Config->scriptSession()) or
      throw EBox::Exceptions::Internal('Could not open ' .  EBox::Config->scriptSession());

    # Lock in shared mode
    flock ($scriptSessionFile, LOCK_SH)
      or throw EBox::Exceptions::Lock($self);

    # The file structure is the following:
    # TIMESTAMP
    my ($timeStamp) = <$scriptSessionFile>;

    # Release the lock and close the file
    flock ($scriptSessionFile, LOCK_UN);
    close ($scriptSessionFile);

    # time() return the # of seconds since an epoch (1 Jan 1970
    # typically)

    my $expireTime = $timeStamp + MAX_SCRIPT_SESSION;
    return ($expireTime >= time());
}

# FIXME: workaround to avoid apache segfault after TryCatch migration
#        when importing EBox::Global directly on EBox::Auth
#
#        EBox::Global is Apache::Singleton::Process so it must be
#        related with that
#
sub _global
{
    eval 'use EBox::Global';
    return EBox::Global->getInstance();
}

1;
