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

package EBox::CGI::RemoteServices::Backup::Proxy;

use strict;
use warnings;

use base qw(EBox::CGI::RemoteServices::Backup::ProxyBase);

use Error qw(:try);

use EBox::RemoteServices::ProxyBackup;
use EBox::Gettext;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;


sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Remote system backups proxy'),
                                  'template' => '/backupTabs.mas',
                                  @_);

    $self->setMenuNamespace('EBox/Backup');

    bless($self, $class);
    return $self;
}



sub optionalParameters
{
  my ($self) = @_;

  return [qw(selected user password newPassword submitAuth cn name)];
}




sub actuate
{
    my ($self) = @_;

    try {
        my $backup = $self->backupService();
        if ($backup) {
            $self->{backups} =  $backup->listRemoteBackups();
        }

    }
    otherwise {
        my $ex = shift;
        $self->setErrorFromException($ex);
        $self->setChain('RemoteServices/NoConnection');
    };

}




sub masonParameters
{
  my ($self) = @_;
  my @params = ();


  my $password = $self->unsafeParam('password');
  if ($password) {
    push @params, (password => $password);
  }

  my $user = $self->param('user');
  if ($user) {
    push @params, (user => $user);
  }

  if (exists $self->{backups}) {
    my $backups = $self->{backups};
    push @params, (backups => $backups);
  }

  push @params, (selected => 'proxy');


  my $remoteServicesActive = EBox::RemoteServices::Base->remoteServicesActive(); 
  # my $user               = EBox::RemoteServices::Base->user();

  push @params, (
		 remoteServicesActive =>  $remoteServicesActive,
		);

  return \@params;
}




1;
