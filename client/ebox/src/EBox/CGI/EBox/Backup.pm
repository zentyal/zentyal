# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::EBox::Backup;

use strict;
use warnings;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use Error qw(:try);
use EBox::Config;
use EBox::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('System backups'),
				      'template' => '/backupTabs.mas',
				      @_);
	$self->{errorchain} = "EBox/Backup";
	bless($self, $class);
	return $self;
}

sub _print
{
	my $self = shift;
	if ($self->{error} || not defined($self->{downfile})) {
		$self->SUPER::_print;
		return;
	}
	open(BACKUP,$self->{downfile}) or
		throw EBox::Exceptions::Internal('Could not open backup file.');
	print($self->cgi()->header(-type=>'application/octet-stream',
				   -attachment=>$self->{downfilename}));
	while (<BACKUP>) {
		print $_;
	}
	close BACKUP;
}

sub requiredParameters
{
  my ($self) = @_;

  if ($self->param('backup')) {
    return [qw(backup description mode)];
  }
  elsif ($self->param('bugreport')) {
    return [qw(bugreport )];
  }
  elsif ($self->param('restoreFromFile')) {
    return [qw(restoreFromFile backupfile mode)];
  }
  elsif ($self->param('restoreFromId')) {
    return [qw(restoreFromId id mode)];
  }
  elsif ($self->param('download')) {
    return [qw(download id download.x download.y)];
  }
  elsif ($self->param('delete')) {
    return [qw(delete id)];
  }
  elsif ($self->param('bugReport')) {
    return [qw(bugReport)];
  }
  else {
    return [];
  }
}

sub optionalParameters
{
  my ($self) = @_;

  if ($self->param('cancel')) {
    return ['.*'];
  }   

  return ['selected'];
}


sub actuate
{
  my ($self) = @_;

  $self->param('cancel') and return;

  if ($self->param('backup')) {
    $self->_backupAction();
  } 
  elsif ($self->param('bugreport')) {
    $self->_bugreportAction();
    } 
  elsif ($self->param('delete')) {
      $self->_deleteAction();
    } 
  elsif ($self->param('download')) {
    $self->_downloadAction();
  } 
  elsif ($self->param('restoreFromId')) {
    $self->_restoreFromIdAction();
  } 
  elsif ($self->param('restoreFromFile')) {
    $self->_restoreFromFileAction();
  }
}



sub masonParameters
{
  my ($self) = @_;
  my @params = ();
 
  my $backup = EBox::Backup->new();
  push @params, (backups => $backup->listBackups());

  my $global = EBox::Global->getInstance();
  my $modulesChanged = grep { $global->modIsChanged($_) } @{ $global->modNames() };
  push @params, (modulesChanged => $modulesChanged);
  push @params, (selected => 'local');


  return \@params;
}


sub  _backupAction
{
  my ($self, %params) = @_;

  my $fullBackup;
  my $mode = $self->param('mode');
  if ($mode eq 'fullBackup') {
    $fullBackup = 1;
  }
  elsif ($mode eq 'configurationBackup') {
    $fullBackup = 0;
  }
  else {
    throw EBox::Exceptions::External(__x('Unknown backup mode: {mode}', mode => $mode));
  }

  my $description = $self->param('description');

  my $progressIndicator;

  my $backup = EBox::Backup->new();
  $progressIndicator= $backup->prepareMakeBackup(description => $description, fullBackup => $fullBackup);

  $self->_showBackupProgress($progressIndicator);
} 



sub  _restoreFromFileAction
{
  my ($self) = @_;

  my $filename = $self->unsafeParam('backupfile');
  # poor man decode html entity for '/'
  $filename =~ s{%2F}{/}g;
  $self->_restore($filename);
} 

sub _restoreFromIdAction
{
  my ($self) = @_;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
				     __("The input contains invalid characters"));
  }

  $self->_restore(EBox::Config::conf ."/backups/$id.tar");
}  


sub _restore
{
  my ($self, $filename) = @_;

  my $fullRestore = $self->_fullRestoreMode;

  my $backup = new EBox::Backup;

  my $progressIndicator = 
    $backup->prepareRestoreBackup($filename, fullRestore => $fullRestore);

  $self->_showRestoreProgress($progressIndicator);
}

sub _fullRestoreMode
{
  my ($self) = @_;

  my $fullRestore;
  my $mode = $self->param('mode');
  if ($mode eq 'fullRestore') {
    $fullRestore = 1;
  }
  elsif ($mode eq 'configurationRestore') {
    $fullRestore = 0;
  }
  else {
    throw EBox::Exceptions::External(__x('Unknown restore mode: {mode}', mode => $mode));
  }

  return $fullRestore;
}


sub _showBackupProgress
{
  my ($self, $progressIndicator) =@_;
  $self->showProgress(
		      progressIndicator => $progressIndicator,

		      title    => __('Backing up'),
		      text               =>  __('Backing up modules'),
		      currentItemCaption =>  __('Operation') ,
		      itemsLeftMessage   =>  __('operations left to finish backup'),
		      endNote            =>  __('Backup successful'),
		      reloadInterval     =>  2,
		     );
}

sub _showRestoreProgress
{
  my ($self, $progressIndicator) =@_;
  $self->showProgress(
		      progressIndicator  => $progressIndicator,

		      title              => __('Restoring backup'),
		      text               =>   __('Restoring modules'),
		      currentItemCaption =>   __('Module') ,
		      itemsLeftMessage   =>   __('modules left to restore'),
		      endNote            =>   __('Restore successful'),
		      reloadInterval     =>   4,
);
}




sub  _downloadAction
{
  my ($self) = @_;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
				     __("The input contains invalid characters"));
  }
  $self->{downfile} = EBox::Config::conf . "/backups/$id.tar";
  $self->{downfilename} = 'eboxbackup.tar';
}

sub  _deleteAction
{
  my ($self) = @_;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
				     __("The input contains invalid characters"));
  }
  my $backup = EBox::Backup->new();
  $backup->deleteBackup($id);
} 

sub  _bugreportAction
{
  my ($self) = @_;

  my $backup = EBox::Backup->new();
  $self->{errorchain} = "EBox/Bug";
  $self->{downfile} = $backup->makeBugReport();
  $self->{downfilename} = 'eboxbugreport.tar';
} 

1;
