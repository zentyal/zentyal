# Copyright (C) 2010-2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::RemoteServices::CGI::Backup::OverwriteRemoteBackup;

use base qw(EBox::CGI::ClientBase);

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

sub new 
{
    my $class = shift;
    my $self = $class->SUPER::new( @_);
    bless($self, $class);
    return $self;
}

sub requiredParameters
{
  return [qw(uuid label)];
}

sub optionalParameters
{
  return [qw(ok cancel popup)];
}

sub actuate
{
  my ($self) = @_;

  $self->param('cancel') and return;

  my $oldUuid = $self->param('uuid');
  my $label   = $self->param('label');

  my $backup =  new EBox::RemoteServices::Backup;
  # remove old backup
  $backup->removeRemoteBackup($oldUuid);


  # Go to make backup CGI with the proper parameters

  # Delete all CGI parameters
  my $request = $self->request();
  my $parameters = $request->parameters();
  $parameters->clear();

  $parameters->add('label' => $label);
  $parameters->add('backup' => 1);
  $parameters->add('popup' => 1);

  $self->setChain("RemoteServices/Backup/MakeRemoteBackup");
}

1;
