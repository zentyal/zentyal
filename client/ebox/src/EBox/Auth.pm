# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Auth;

use strict;
use warnings;

use base qw(Apache2::AuthCookie);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::LogAdmin;
use Apache2::Connection;

use Digest::MD5;
use Fcntl qw(:flock);

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a SOAP session
use constant MAX_SOAP_SESSION => 10; # In seconds

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Parameters:
#
#   - session id : if the id is undef, it truncates the session file
# Exceptions:
# 	- Internal
# 		- When session file cannot be opened to write
sub _savesession # (session_id)
{
	my $sid = shift;
	my $sidFile;
        my $openMode = '>';
        if ( -f EBox::Config->sessionid() ) {
            $openMode = '+<';
        }
	unless  ( open ( $sidFile, $openMode, EBox::Config->sessionid() )){
            throw EBox::Exceptions::Internal(
         		      "Could not open to write ".
	                      EBox::Config->sessionid);
      	}
        # Lock the file in exclusive mode
        flock($sidFile, LOCK_EX)
          or throw EBox::Exceptions::Lock('EBox::Auth');
        # Truncate the file after locking
        truncate($sidFile, 0);
	print $sidFile $sid . "\t" . time if defined $sid;
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
#       password - string containing the plain password
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - when password's file cannot be opened
sub checkPassword # (password) 
{
    my ($self, $passwd) = @_;

    open(my $PASSWD_F, EBox::Config->passwd) or
	throw EBox::Exceptions::Internal('Could not open passwd file');

    my @lines = <$PASSWD_F>;
    close($PASSWD_F);

    my $filepasswd = $lines[0];
    $filepasswd =~ s/[\n\r]//g;

    my $md5 = Digest::MD5->new;
    $md5->add($passwd);

    my $encpasswd = $md5->hexdigest;
    if ($encpasswd eq $filepasswd) {
	return 1;
    } else {
	return undef;
    }
}


# Method: setPassword
#
#   	Store the given password
#
# Parameters:
#
#       password - string containing the plain password
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - when password's file cannot be
#       opened
#	<EBox::Exceptions::External> - when password length is no
#	longer than 6 characters
sub setPassword # (password) 
{
    my ($self, $passwd) = @_;

    unless (length($passwd) > 5) {
	throw EBox::Exceptions::External('The password must be at least 6 characters long');
    }

    open(my $PASSWD_F, "> ". EBox::Config->passwd) or
	throw EBox::Exceptions::Internal('Could not open passwd file');

    my $md5 = Digest::MD5->new;
    $md5->add($passwd);
    my $encpasswd = $md5->hexdigest;

    print $PASSWD_F $encpasswd;
    close($PASSWD_F);
    EBox::LogAdmin::logAdminNow('ebox',__n('Password changed'),'');
}


# Method: authen_cred
#
#   	Overriden method from <Apache2::AuthCookie>.
#
sub authen_cred  # (request, password)
{
    my ($self, $r, $passwd) = @_;

    # If there's a SOAP session opened, give it priority to the
    # Web interface session
    if ( $self->_activeSOAPSession() ){
      EBox::warn('Failed login since a SOAP session is opened');
      $r->subprocess_env(LoginReason => 'SOAP active');
      return;
    }

    unless ($self->checkPassword($passwd)) {
	my $log = EBox->logger;
	my $ip  = $r->connection->remote_host();
	$log->warn("Failed login from: $ip");
	return;
    }

    my $md5 = Digest::MD5->new;
    $md5->add(time() . rand((2**50)));
    my $sid = $md5->hexdigest;
    _savesession($sid);

    my $global = EBox::Global->getInstance();
    $global->revokeAllModules;

    return $sid;
}


# Method: authen_ses_key
#
#   	Overriden method from <Apache2::AuthCookie>.
#
sub authen_ses_key  # (request, session_key)
{
    my ($self, $r, $session_key) = @_;

    my ($sid, $lastime) = _currentSessionId();

    my $expired =  _timeExpired($lastime);

    if ( $self->_activeSOAPSession() ) {
      $r->subprocess_env(LoginReason => 'SOAP active');
      _savesession(undef);
    }
    elsif(($session_key eq $sid) and (!$expired )){
	_savesession($sid);
	return "admin";
    }
    elsif ($expired) {
	$r->subprocess_env(LoginReason => "Expired");
	_savesession(undef);
    }
    else {
	$r->subprocess_env(LoginReason => "Already");
    }

    return;
}

# XXX not sure if this will be useful, if not remove
sub alreadyLogged
{
    my ($self) = @_;
    my ($sid, $lastime) = _currentSessionId();
    
    return 0 if !defined $sid;
    return 0 if _timeExpired($lastime);

    return 1;
}

#
# Method: defaultPasswdChanged
#
# Returns:
#
#     boolean - signal whether the default eBox password were
#               changed or not
#
sub defaultPasswdChanged
{
  my ($self) = @_;
  return EBox::Auth->checkPassword('ebox') ? undef : 1;
}

# scalar mode: return the sessionid
# list mode:   return (sessionid, lastime)
sub _currentSessionId
{
    my $SID_F; # sid file handle

    unless( -e EBox::Config->sessionid){
	unless  (open ($SID_F,  ">". EBox::Config->sessionid)){
	    throw EBox::Exceptions::Internal(
					     "Could not create  ". 
					     EBox::Config->sessionid);
	}
	close($SID_F);
	return;
    }
    unless   (open ($SID_F,  EBox::Config->sessionid)){
	throw EBox::Exceptions::Internal(
					 "Could not open ".
					 EBox::Config->sessionid);
    }

    # Lock in shared mode for reading
    flock($SID_F, LOCK_SH)
      or throw EBox::Exceptions::Lock('EBox::Auth');

    $_ = <$SID_F>;
    my ($sid, $lastime);
    ($sid, $lastime) = split /\t/ if defined $_;

    # Release the lock
    flock($SID_F, LOCK_UN);
    close($SID_F);

    if (wantarray()) {
	return ($sid, $lastime) ;
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

# Method: _activeSOAPSession
#
#       Check whether a SOAP session is already opened or not
#
# Returns:
#
#       Boolean - indicate if a SOAP session is already opened
#
sub _activeSOAPSession
  {

    my ($self) = @_;

    # The SOAP session filehandle
    my $soapSessionFile;

    unless ( -e EBox::Config->soapSession() ){
      return undef;
    }

    # Trying to open the soap sid
    open( $soapSessionFile, '<', EBox::Config->soapSession() ) or
      throw EBox::Exceptions::Internal('Could not open ' .
				       EBox::Config->soapSession());

    # Lock in shared mode
    flock($soapSessionFile, LOCK_SH)
      or throw EBox::Exceptions::Lock($self);

    # The file structure is the following:
    # TIMESTAMP
    my ($timeStamp) = <$soapSessionFile>;

    # Release the lock and close the file
    flock($soapSessionFile, LOCK_UN);
    close($soapSessionFile);

    # time() return the # of seconds since an epoch (1 Jan 1970
    # typically)

    my $expireTime = $timeStamp + MAX_SOAP_SESSION;
    return ( $expireTime >= time() );

  }


1;
