# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::RemoteServices::CGI::Backup::RestoreRemoteBackup;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_);
    bless($self, $class);
    return $self;
}

sub requiredParameters
{
    return [qw(uuid)];
}

sub optionalParameters
{
    return [qw(ok cancel popup)];
}

sub actuate
{
    my ($self) = @_;

    $self->param('cancel') and return;

    my $backup =  EBox::RemoteServices::Backup->new();
    my $uuid   = $self->param('uuid');

    my $progress = $backup->prepareRestoreRemoteBackup($uuid);
    $self->showRestoreProgress($progress);
}

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Zentyal.Dialog.close(); window.location='/RemoteServices/Backup/Index'; return false",
);

sub showRestoreProgress
{
    my ($self, $progressIndicator) = @_;

    my @params = (
            progressIndicator  => $progressIndicator,
            title              => __('Restoring remote backup'),
            text               => __('Restoring modules from remote backup'),
            currentItemCaption => __('Module') ,
            itemsLeftMessage   => __('modules left to restore'),
            reloadInterval     => 4,
    );

    my $endNote = __('Restore successful');

    if ($self->param('popup')) {
        push (@params, @popupProgressParams);
    } 

    push (@params, 'endNote' => $endNote);

    $self->showProgress(@params);
}

sub _print
{
    my ($self) = @_;
    $self->_printPopup();
}

1;
