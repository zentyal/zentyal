# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::CGI::RemoteServices::Backup::Confirm;
use base qw(EBox::CGI::RemoteServices::Backup::ProxyBase);

use strict;
use warnings;

use EBox::RemoteServices::Backup;
use EBox::RemoteServices::ProxyBackup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

my @extraParameters = qw(cn user password);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new( @_,
				       template => 'RemoteServices/Backup/confirm.mas',
				       title => __('Configuration backup'),
				     );

	bless($self, $class);

	$self->_setErrorChain();

	return $self;
}



sub _setErrorChain
{
  my ($self) = @_;
  
  my $errorchain;
  if ($self->param('action') eq 'restoreProxy') {
    $errorchain = "RemoteServices/Backup/Proxy";
  }
  else {
    $errorchain = "RemoteServices/Backup/Index";
  }

  $self->{errorchain} = $errorchain;
}

sub requiredParameters
{
  return [qw(action name)];
}


sub optionalParameters
{
  return \@extraParameters;
}

my %cgiByAction = (
		   delete  => 'DeleteRemoteBackup',
		   restore => 'RestoreRemoteBackup',
		   restoreProxy =>  'RestoreProxyRemoteBackup',
		  );



sub actuate
{
  my ($self) = @_;



}

sub restoreText
{
  my ($self) = @_;
  return __('Please confirm that you want to restore the configuraction using the following remote backup:')
}

sub restoreOkText
{
  my ($self) = @_;
  return __('Restore');
}


sub restoreProxyText
{
  my ($self) = @_;
  return __('Please confirm that you want to restore the configuraction using the following remote backup:')
}

sub restoreProxyOkText
{
  my ($self) = @_;
  return __('Restore');
}



sub deleteText
{
  my ($self) = @_;
  return __('Please confirm that you want to delete the following remote backup:')
}

sub deleteOkText
{
  my ($self) = @_;
  return __('Delete');
}


sub _backup
{
  my ($self, $action) = @_;

  if ($action eq 'restoreProxy') {
    return $self->_remoteProxyBackup();
  }

  return $self->_remoteBackup();
}


sub _remoteBackup
{
  my ($self) = @_;
  my $name   = $self->param('name');

  my $backupService =  new EBox::RemoteServices::Backup;
  return $backupService->remoteBackupInfo($name);
}

sub _remoteProxyBackup
{
  my ($self) = @_;



  my $backupService =  $self->backupService();

  my $cn   = $self->param('cn');
  my $name = $self->param('name');

  return $backupService->remoteBackupInfo($cn, $name);
}


sub masonParameters
{
  my ($self) = @_;


  my $action = $self->param('action');
  exists $cgiByAction{$action} or
    throw EBox::Exceptions::External(
		      __x('Inexistent action: {a}', a => $action)
				      );

  my $actionCGI = $cgiByAction{$action};


  my $backup = $self->_backup($action);

  my @parameters =(
		   backup => $backup,
		   actionCGI => $actionCGI,
		  );

  my $textMethod = $action . 'Text';
  if ($self->can($textMethod)) {
    push @parameters, (text => $self->$textMethod());
  }

  my $okTextMethod = $action . 'OkText';
  if ($self->can($okTextMethod)) {
    push @parameters, (okText => $self->$okTextMethod());
  }

  my @extraActionParams;
  foreach my $p (@extraParameters) {
    # need to use unsafeParam bz password parameter
    my $value = $self->unsafeParam($p);
    if ($value) {
      push @extraActionParams, ($p => $value);
    }
  }

  push @parameters, (extraActionParams => \@extraActionParams);

  return \@parameters;
}





1;
