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

package EBox::CGI::RemoteServices::Backup::RestoreRemoteBackup;
use base qw(EBox::CGI::ClientBase  EBox::CGI::ProgressClient);

use strict;
use warnings;

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new( @_);
    $self->{errorchain} = "RemoteServices/Backup/Index";
    $self->{redirect} = "RemoteServices/Backup/Index";
    bless($self, $class);
    return $self;
}


sub requiredParameters
{
  return [qw(name)];
}

sub optionalParameters
{
  return [qw(ok cancel)];
}


sub actuate
{
  my ($self) = @_;

  $self->param('cancel') and return;

  my $backup =  new EBox::RemoteServices::Backup;
  my $name   = $self->param('name');

  my $progress = $backup->prepareRestoreRemoteBackup($name);


  $self->showRestoreProgress($progress);
}


sub showRestoreProgress
{
  my ($self, $progressIndicator) = @_;
  $self->showProgress(
		      progressIndicator => $progressIndicator,
		      title              => __('Restoring remote backup'),
		      text               =>   __('Restoring modules from remote backup'),
		      currentItemCaption =>   __('Module') ,
		      itemsLeftMessage   =>   __('modules left to restore'),
		      endNote            =>   __('Restore successful'),

		      reloadInterval  => 4,
		     );
}

1;
