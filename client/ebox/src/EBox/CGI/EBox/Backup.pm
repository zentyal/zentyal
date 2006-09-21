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

use base 'EBox::CGI::ClientBase';

use EBox::Config;
use File::Temp qw(tempfile);
use EBox::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Configuration backups'),
				      'template' => '/backup.mas',
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
  elsif ($self->param('backupToDisc')) {
    return [qw(backupToDisc description mode)];
  }
  elsif ($self->param('restore')) {
    return [qw(restore backupfile mode)];
  }
  elsif ($self->param('restoreFromDisc')) {
    return [qw(restoreFromDisc backupfile mode)];
  }
  elsif ($self->param('download')) {
    return [qw(download id download.x download.y)];
  }
  elsif ($self->param('writeBackupToDisc')) {
    return [qw(writeBackupToDisc id)];
  }
  elsif ($self->param('delete')) {
    return [qw(delete id)];
  }
  elsif ($self->param('restoreId')) {
    return [qw(restoreId id mode)];
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
    return [qw(cancel mode id restoreId download delete writeBackupToDisc)];
  }   

      return [];
}


sub actuate
{
  my ($self) = @_;

  $self->param('cancel') and return;

  if ($self->param('backup')) {
    $self->_backupAction(directlyToDisc => 0);
  } 
  elsif ($self->param('backupToDisc')) {
    $self->_backupAction(directlyToDisc => 1);
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
  elsif ($self->param('restoreId')) {
    $self->_restoreIdAction();
  } 
  elsif ($self->param('restore')) {
    $self->_restoreAction();
  }
  elsif ($self->param('writeBackupToDisc')) {
    $self->_writeBackupToDiscAction();
  }
  elsif ($self->param('restoreFromDisc')) {
    $self->_restoreFromDiscAction();
  }
}



sub masonParameters
{
  my ($self) = @_;

  my $backup = EBox::Backup->new();

  my @params = ();
  push @params, (backups => $backup->listBackups());
  
  return \@params;
}


sub  _backupAction
{
  my ($self, %params) = @_;
  exists $params{directlyToDisc} or throw EBox::Exceptions::MissingArgument('directlyToDisc');

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


  my $backup = EBox::Backup->new();
  $backup->makeBackup(description => $description, fullBackup => $fullBackup, directlyToDisc => $params{directlyToDisc});

  $self->setMsg(__('Backup done'));
} 


sub _writeBackupToDiscAction
{
  my ($self) = @_;

  my $backup = new EBox::Backup;
  my $id     = $self->param('id');
  
  $backup->writeBackupToDisc($id);

  $self->setMsg(__('Backup was written to disc'));
}

sub  _restoreAction
{
  my ($self) = @_;


  my $dir = EBox::Config::tmp;
  my ($fh, $filename) = tempfile("backupXXXXXX", DIR=>$dir);

  my $upfile = $self->cgi->upload('backupfile');
  unless ($upfile) {
    close $fh;
    `rm -f $filename`;
    throw EBox::Exceptions::External(
				     __('Invalid backup file.'));
  }
  while (<$upfile>) {
    print $fh $_;
  }

  close $fh;
  close $upfile;

  $self->_restoreFromFile($filename);
} 

sub _restoreIdAction
{
  my ($self) = @_;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
				     __("The input contains invalid characters"));
  }

  $self->_restoreFromFile(EBox::Config::conf ."/backups/$id.tar");
}  

sub _restoreFromDiscAction
{
  my ($self) = @_;
  
  my $fullRestore = $self->_fullRestoreMode;

  my $backup = new EBox::Backup;
  $backup->restoreBackupFromDisc(fullRestore => $fullRestore);
  $self->_afterRestoreMsg();
}

sub _restoreFromFile
{
  my ($self, $filename) = @_;

  my $fullRestore = $self->_fullRestoreMode;

  my $backup = new EBox::Backup;
  $backup->restoreBackup($filename, fullRestore => $fullRestore);
  `rm -f $filename`;

  $self->_afterRestoreMsg();
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

sub _afterRestoreMsg
{
  my ($self) =@_;
  $self->setMsg( __('Configuration restored succesfully, '.
		    'you should now review it and save it if you want '.
		    'to keep it.'));
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
