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

package EBox::CGI::EBox::ConfirmBackup;

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
				      'template' => '/confirm-backup.mas',
				      @_);
	bless($self, $class);
	return $self;
}




sub _process
{
  my ($self) = @_;

  $self->{errorchain} = "EBox/Backup";

  if (defined($self->param('download'))) {
    $self->{chain} = 'EBox/Backup';
    return;
  }

  foreach my $actionParam (qw(delete burn restoreFromId restoreFromDisc restoreFromFile )) {
    if ($self->param($actionParam)) {
      my $actionSub = $self->can($actionParam . 'Action');
      my ($backupAction, $backupActionText, $backupDetails) = $actionSub->($self);
      $self->{params} = [action => $backupAction, actiontext => $backupActionText, backup => $backupDetails];
      return;
    }
  }


  # otherwise...
  $self->{redirect} = "EBox/Backup";
  return;
}


sub deleteAction
{
  my ($self) = @_;

  $self->{msg} = __('Please confirm that you want to delete the following backup file:');

  return ('delete', __('Delete'), $self->backupDetailsFromId());
}

sub  restoreFromIdAction
{
  my ($self) = @_;

  $self->{msg} = __('Please confirm that you want to restore the configuration from this backup file:');

  return ('restoreFromId', __('Restore'), $self->backupDetailsFromId());
} 


sub restoreFromDiscAction
{
  my ($self) = @_;
  
  my $backup = new EBox::Backup;
  my $backupfileInfo = $backup->searchBackupFileInDiscs();
  defined $backupfileInfo or throw EBox::Exceptions::External(__('Unable to find a correct backup disc. Please insert a backup disc and retry')); # XXX TODO: discriminate between no disc and disc with no backup
  

  my $details =  $backup->backupDetailsFromFile($backupfileInfo->{file});

  $self->{msg} = __('Please confirm that you want to restore the configuration from this backup disc:');

  return ('restoreFromDisc', __('Restore'), $details);
} 


sub  restoreFromFileAction
{
  my ($self) = @_;

  my $backup = new EBox::Backup;
  my $dir = EBox::Config::tmp;

  my $upfile = $self->cgi->upload('backupfile');
  my ($fh, $filename) = tempfile("backupXXXXXX", DIR=>$dir);

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

  my $details = $backup->backupDetailsFromFile($filename);

  $self->{msg} = __('Please confirm that you want to restore the configuration from this backup file:');

  return ('restoreFromFile', __('Restore'), $details);
} 


sub  burnAction
{
  my ($self) = @_;

  $self->{msg} = __('Please confirm that you want to write this backup file to a CD or DVD disc:');

  return ('writeBackupToDisc', __('Write to disc'), $self->backupDetailsFromId());
} 


sub backupDetailsFromId
{
  my ($self) = @_;
  my $backup = new EBox::Backup;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
				     __("The input contains invalid characters"));
  }

  return $backup->backupDetails($id);
}

1;
