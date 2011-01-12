# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::CGI::RemoteServices::Backup::OverwriteRemoteBackup;
use base qw(EBox::CGI::ClientBase);

use strict;
use warnings;

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;


sub new 
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
  return [qw(name newName description)];
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
  my $oldName   = $self->param('name');

  # remove old backup
  $backup->removeRemoteBackup($oldName);


  my $newName = $self->param('newName');
  my $description = $self->param('description');

  # go to make backup CGI with appropiate parameters
  my $cgi = $self->{cgi};
  $cgi->delete_all();
  $cgi->param('name', $newName);
  $cgi->param('description', $description);
  $cgi->param('backup', 1);

  $self->keepParam('name');
  $self->keepParam('description');
  $self->keepParam('backup');

  $self->setChain("RemoteServices/Backup/MakeRemoteBackup");
}

1;
