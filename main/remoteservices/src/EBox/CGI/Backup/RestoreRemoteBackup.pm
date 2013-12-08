# Copyright (C) 2008-2012 Zentyal S.L.
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
use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

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
    return [qw(ok cancel popup dr)];
}


sub actuate
{
    my ($self) = @_;

    $self->param('cancel') and return;

    my $backup =  new EBox::RemoteServices::Backup;
    my $name   = $self->param('name');
    my $dr = $self->param('dr');

    my $progress = $backup->prepareRestoreRemoteBackup($name, $dr);

    $self->showRestoreProgress($progress);
}

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Modalbox.hide(); window.location='/RemoteServices/Backup/Index'; return false",
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
    } elsif ($self->param('dr')) {
        push (@params, 'nextStepUrl' => '/SaveChanges?noPopup=1&save=1');
        push (@params, 'nextStepText' => __('Click here to save changes'));
        $endNote .= '<br/><br/>' . __('Please note that you may need to reload the page and accept the new certificate restored from the backup.');
    }

    push (@params, 'endNote' => $endNote);

    $self->showProgress(@params);
}

sub _print
{
    my ($self) = @_;
    if (not $self->param('popup')) {
        return $self->SUPER::_print();
    }

    $self->_printPopup();
}

1;
