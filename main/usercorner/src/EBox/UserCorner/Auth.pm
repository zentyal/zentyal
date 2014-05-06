# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::UserCorner::Auth;

use base qw(EBox::ThirdParty::Apache2::AuthCookie);

use EBox;
use EBox::CGI::Run;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Ldap;
use EBox::UserCorner;
use Crypt::Rijndael;
use Apache2::Connection;
use Apache2::RequestUtil;
use Apache2::Const qw(:common HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);

use MIME::Base64;
use Digest::MD5;
use Error qw(:try);
use Fcntl qw(:flock);
use File::Basename;

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds

# Init logger at the loading of this class
EBox::initLogger('usercorner-log.conf');

# Method: _savesession
#
# Parameters:
#
#   - user name
#   - password
#   - user DN
#   - session id: if the id is undef, it creates a new one
#   - key: key for rijndael, if sid is undef creates a new one
# Exceptions:
#       - Internal
#               - When session file cannot be opened to write
sub _savesession
{
    my ($user, $passwd, $userDN, $sid, $key) = @_;

    if(not defined($sid)) {
        my $rndStr;
        for my $i (1..64) {
            $rndStr .= rand (2**32);
        }

        my $md5 = Digest::MD5->new();
        $md5->add($rndStr);
        $sid = $md5->hexdigest();

        for my $i (1..64) {
            $rndStr .= rand (2**32);
        }
        $md5 = Digest::MD5->new();
        $md5->add($rndStr);

        $key = $md5->hexdigest();
    }

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $len = length($passwd);
    my $newlen = (int(($len-1)/16) + 1) * 16;

    $passwd = $passwd . ("\0" x ($newlen - $len));

    my $cryptedpass = $cipher->encrypt($passwd);
    my $encodedcryptedpass = MIME::Base64::encode($cryptedpass, '');
    my $sidFile;
    my $filename = EBox::UserCorner::usersessiondir() . $user;
    unless  ( open ( $sidFile, '>', $filename )){
        throw EBox::Exceptions::Internal(
                "Could not open to write ".  $filename);
    }
    # Lock the file in exclusive mode
    flock($sidFile, LOCK_EX)
        or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');
    # Truncate the file after locking
    truncate($sidFile, 0);
        print $sidFile $sid . "\t" . $encodedcryptedpass . "\t" . $userDN . "\t" . time if defined $sid;
    # Release the lock
    flock($sidFile, LOCK_UN);
        close($sidFile);

    return $sid . $key;
}

sub _updatesession
{
    my ($user) = @_;

    my $sidFile;
    my $sess_file = EBox::UserCorner::usersessiondir() . $user;
    unless (open ($sidFile, '+<', $sess_file)) {
        throw EBox::Exceptions::Internal("Could not open $sess_file");
    }
    # Lock in exclusive
    flock($sidFile, LOCK_EX)
        or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');

    my $sess_info = <$sidFile>;
    my ($sid, $cryptedpass, $userDN, $lastime) = split (/\t/, $sess_info) if defined $sess_info;

    # Truncate the file
    truncate($sidFile, 0);
    seek($sidFile, 0, 0);
    print $sidFile $sid . "\t" . $cryptedpass . "\t" . $userDN . "\t" . time if defined $sid;
    # Release the lock
    flock($sidFile, LOCK_UN);
    close($sidFile);
}

# Method: checkPassword
#
#       Check if a given password matches the stored one after md5 it
#
# Parameters:
#
#       user - string containing the user name
#       passwd - string containing the plain password
#
# Returns:
#
#       string - the user's DN identified, or undef
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - when password's file cannot be opened
sub checkPassword # (user, password)
{
    my ($self, $user, $password) = @_;

    # We connect to the LDAP with a read only account to lookup the user.
    my $usersMod = EBox::Global->modInstance('users');

    # We require an LDAP connection to query the LDAP database. That connection MUST be closed after the validation.
    my $ldap = EBox::Ldap->instance();
    my $connection = $ldap->connection();

    my $userDN = undef;
    my $userObject = $usersMod->userByUID($user);

    if ($userObject) {
        try {
            $userDN = $userObject->dn();
            EBox::Ldap::safeBind($ldap->anonymousLdapCon(), $userDN, $password);
        } otherwise {
            # exception == auth failed
            $userDN = undef;
        };
    }

    # Force the LDAP connection clean up to prevent any other privileged query that may happen.
    $ldap->clearConn();
    return $userDN;
}

# Method: updatePassword
#
#   Updates the current session information with the new password
#
# Parameters:
#
#       passwd - string containing the plain password
#
sub updatePassword
{
    my ($self, $user, $passwd, $userDN) = @_;
    my $r = Apache2::RequestUtil->request();

    my $session_info = EBox::UserCorner::Auth->key($r);
    my $sid = substr($session_info, 0, 32);
    my $key = substr($session_info, 32, 32);
    _savesession($user, $passwd, $userDN, $sid, $key);
}

# Method: authen_cred
#
#       Overriden method from <Apache2::AuthCookie>.
#
sub authen_cred  # (request, user, password)
{
    my ($self, $r, $user, $passwd) = @_;

    my $userDN = $self->checkPassword($user, $passwd);
    unless ($userDN) {
        my $log = EBox->logger();
        my $ip = $r->hostname();
        $ip or $ ip ='unknown';
        $log->warn("Failed login from: $ip");
        return;
    }

    return _savesession($user, $passwd, $userDN);
}

# Method: credentials
#
#   gets the current user and password
#
# Throws:
#
#   EBox::Exceptions::DataNotFound - When the credentials are not available.
#
sub credentials
{
    my $r = Apache2::RequestUtil->request();

    my $user = $r->user();
    if (not $user) {
        throw EBox::Exceptions::DataNotFound(data => 'request', value => 'user');
    }

    my $session_info = EBox::UserCorner::Auth->key($r);
    if ($session_info) {
        return _credentials($user, $session_info);
    }

    throw EBox::Exceptions::DataNotFound(data => "session", value => $user);
}

sub _credentials
{
    my ($user, $session_info) = @_;

    my $key = substr($session_info, 32, 32);

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $SID_F;
    my $sess_file  = EBox::UserCorner::usersessiondir() . $user;
    unless (open ($SID_F,  '<', $sess_file)) {
        throw EBox::Exceptions::Internal("Could not open $sess_file");
    }
    # Lock in shared mode for reading
    flock($SID_F, LOCK_SH)
        or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');

    my $sess_info = <$SID_F>;
    my ($sid, $cryptedpass, $userDN, $lastime) = split (/\t/, $sess_info) if defined $sess_info;

    # Release the lock
    flock($SID_F, LOCK_UN);
    close($SID_F);

    my $decodedcryptedpass = MIME::Base64::decode($cryptedpass);
    my $pass = $cipher->decrypt($decodedcryptedpass);
    $pass =~ tr/\x00//d;

    return { 'user' => $user, 'pass' => $pass, 'userDN' => $userDN };
}

# Method: authen_ses_key
#
#   Overriden method from <Apache2::AuthCookie>.
#
sub authen_ses_key  # (request, session_key)
{
    my ($self, $r, $session_data) = @_;

    my $session_key = substr($session_data, 0, 32);

    my $SID_F; # sid file handle

    my $user = undef;
    my $expired;

    for my $sess_file (glob(EBox::UserCorner::usersessiondir() . '*')) {
        unless (open ($SID_F,  '<', $sess_file)) {
            EBox::error("Could not open '$sess_file|'");
            next;
        }
        # Lock in shared mode for reading
        flock($SID_F, LOCK_SH)
          or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');

        my $sess_info = <$SID_F>;
        my ($sid, $cryptedpass, $userDN, $lastime) = split (/\t/, $sess_info) if defined $sess_info;

        $expired = _timeExpired($lastime);
        if ($session_key eq $sid) {
            $user = basename($sess_file);
        }

        # Release the lock
        flock($SID_F, LOCK_UN);
        close($SID_F);

        defined($user) and last;
    }
    if(defined($user) and !$expired) {
        my $ldap = EBox::Ldap->instance();
        $ldap->refreshLdap();
        _updatesession($user);
        return $user;
    } elsif (defined($user) and $expired) {
        $r->subprocess_env(LoginReason => "Expired");
        unlink(EBox::UserCorner::usersessiondir() . $user);
    } else {
        $r->subprocess_env(LoginReason => "NotLoggedIn");
    }

    return;
}

sub _timeExpired
{
    my ($lastime) = @_;

    my $expires = $lastime + EXPIRE;

    my $expired = (time() > $expires);
    return $expired;
}

# Method: logout
#
#   Overriden method from <Apache2::AuthCookie>.
#
sub logout # (request)
{
    my ($self, $r) = @_;

    my $filename = EBox::UserCorner::usersessiondir() . $r->user;
    unlink($filename);

    $self->SUPER::logout($r);
}

1;
