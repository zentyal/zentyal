# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::UserCorner::Auth;

use strict;
use warnings;

use base qw(Apache2::AuthCookie);

use EBox;
use EBox::CGI::Run;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::LogAdmin;
use EBox::UserCorner;
use Crypt::Rijndael;
use Apache2::Connection;
use Apache2::RequestUtil;
use Apache2::Const qw(:common HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);

use Digest::MD5;
use Fcntl qw(:flock);
use File::Basename;

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Parameters:
#
#   - user name
#   - session id : if the id is undef, it truncates the session file
# Exceptions:
# 	- Internal
# 		- When session file cannot be opened to write
sub _savesession # (user, session_id)
{
	my ($user, $sid, $cryptedpass) = @_;
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
	print $sidFile $sid . "\t" . $cryptedpass . "\t" . time if defined $sid;
    # Release the lock
    flock($sidFile, LOCK_UN);
	close($sidFile);
}

# Method: checkPassword
#
#   	Check if a given password matches the stored one after md5 it
#
# Parameters:
#
#       user - string containing the user name
#       passwd - string containing the plain password
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - when password's file cannot be opened
sub checkPassword # (user, password) 
{
    my ($self, $user, $passwd) = @_;

    my $users = EBox::Global->modInstance('users');
    return $users->authUser($user, $passwd);
}

# Method: authen_cred
#
#   	Overriden method from <Apache2::AuthCookie>.
#
sub authen_cred  # (request, user, password)
{
    my ($self, $r, $user, $passwd) = @_;

    unless ($self->checkPassword($user, $passwd)) {
        EBox::initLogger('user-eboxlog.conf');
        my $log = EBox->logger();
        my $ip  = $r->connection->remote_host();
        $log->warn("Failed login from: $ip");
        return;
    }

    my $rndStr;
    for my $i (1..64) {
        $rndStr .= rand (2**32);
    }

    my $md5 = Digest::MD5->new();
    $md5->add($rndStr);
    my $sid = $md5->hexdigest();

    for my $i (1..64) {
        $rndStr .= rand (2**32);
    }
    $md5 = Digest::MD5->new();
    $md5->add($rndStr);

    my $key = $md5->hexdigest();

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $len = length($passwd);
    my $newlen = (int(($len-1)/16) + 1) * 16;

    $passwd = $passwd . ("\0" x ($newlen - $len));

    my $cryptedpass = $cipher->encrypt($passwd);
    _savesession($user, $sid, $cryptedpass);

    return $sid . $key;
}

# Method: credentials
#
#   gets the current user and password
#
sub credentials
{
    my $r = Apache2::RequestUtil->request();

    my $user = $r->user();

    my $session_info = EBox::UserCorner::Auth->key($r);
    my $key = substr($session_info, 32, 32);

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $SID_F;
    my $sess_file  = EBox::UserCorner::usersessiondir() . $user;
    unless (open ($SID_F,  $sess_file)) {
        throw EBox::Exceptions::Internal("Could not open $sess_file");
    }
    # Lock in shared mode for reading
    flock($SID_F, LOCK_SH)
        or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');

    my $sess_info = <$SID_F>;
    my ($sid, $cryptedpass, $lastime);
    ($sid, $cryptedpass, $lastime) = split (/\t/, $sess_info) if defined $sess_info;

    # Release the lock
    flock($SID_F, LOCK_UN);
    close($SID_F);

    my $pass = $cipher->decrypt($cryptedpass);
    $pass =~ s/\x00+$//;

    return $pass;
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
        unless (open ($SID_F,  $sess_file)) {
            throw EBox::Exceptions::Internal("Could not open $sess_file");
        }
        # Lock in shared mode for reading
        flock($SID_F, LOCK_SH)
          or throw EBox::Exceptions::Lock('EBox::UserCorner::Auth');

        my $sess_info = <$SID_F>;
        my ($sid, $cryptedpass, $lastime);
        ($sid, $cryptedpass, $lastime) = split (/\t/, $sess_info) if defined $sess_info;

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
        return $user;
    } elsif (defined($user) and $expired) {
        $r->subprocess_env(LoginReason => "Expired");
        unlink(EBox::UserCorner::usersessiondir() . $user);
    } else {
        $r->subprocess_env(LoginReason => "Already");
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
