# Copyright (C) 2008 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::RemoteServices::Backup::ProxyBase;

use strict;
use warnings;

use base qw(EBox::CGI::ClientBase);

use Error qw(:try);

use EBox::RemoteServices::ProxyBackup;
use EBox::Gettext;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use MIME::Base64;


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift @_;
	my $self = $class->SUPER::new( @_);

	bless($self, $class);
	return $self;
}



sub optionalParameters
{
  my ($self) = @_;

  return [qw(user password) ];
}


sub backupService
{
  my ($self) = @_;

  if (exists $self->{backupService}) {
    return $self->{backupService}
  }


  my $user = $self->user();
  if (not $user) {
    return undef;
  }

  my $password = $self->password();
  if (not $password) {
    return undef;
  }


  
  $self->{backupService} =  new EBox::RemoteServices::ProxyBackup(
								user => $user,
								password => $password
							       );
  
  return $self->{backupService}
}


sub user
{
  my ($self) = @_;

  my $user = $self->param('user');
  $user or
    return undef;

  return $user;
}


sub password
{
  my ($self) = @_;

  if (exists $self->{password}) {
    return $self->{password};
  }

  my $password = undef;


  $password = $self->unsafeParam('password');

  $password = decode_base64($password);

  if ($password) {
    $self->{password} = $password;
    return $password;
  }

  return undef;
}




sub encodedPassword
{
  my ($self) = @_;

  my $password = $self->password();
  $password or
    return undef;

  return $self->encodePassword($password);
}


sub encodePassword
{
  my ($self, $password) = @_;

  return encode_base64($password);
}

sub actuate
{
  my ($self) = @_;

  throw EBox::Exceptions::NotImplemented('Abstract base class for CGI');
}






1;
