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

package EBox::RemoteServices::CGI::Backup::Confirm;

use base qw(EBox::CGI::ClientBase);

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Util::FileSize;

my @extraParameters = qw(cn user password description newName);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_,
                                   template => 'remoteservices/Backup/confirm.mas',
                                   title => __('Configuration backup'),
                                 );

    bless($self, $class);

    if ($self->param('popup')) {
        $self->_setErrorChain();
    }

    return $self;
}

sub _setErrorChain
{
    my ($self) = @_;

    my $errorchain = "RemoteServices/Backup/Index";
    $self->{errorchain} = $errorchain;
}

sub requiredParameters
{
    return ['action'];
}

sub optionalParameters
{
    my @optional = @extraParameters;
    push @optional, 'backup';  # needed for backup overwritten confirmation
    push @optional, 'popup';
    push @optional, 'uuid';
    push @optional, 'label';

    return \@optional;
}

my %cgiByAction = (
           delete    => 'DeleteRemoteBackup',
           restore   => 'RestoreRemoteBackup',
           overwrite => 'OverwriteRemoteBackup',
);

sub actuate
{
    my ($self) = @_;

}

sub restoreText
{
    my ($self) = @_;
    return __('Please confirm that you want to restore the configuration using the following remote backup:')
}

sub restoreOkText
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

sub overwriteText
{
    my ($self) = @_;
    return __('Please confirm that you want to overwrite the following remote backup with a new one')
}

sub overwriteOkText
{
    my ($self) = @_;
    return __('Overwrite');
}

sub _backup
{
    my ($self, $action) = @_;

    my $uuid = $self->param('uuid');

    my $backupService =  new EBox::RemoteServices::Backup();
    return $backupService->remoteBackupInfo($uuid);
}

sub masonParameters
{
    my ($self) = @_;

    my $uuid   = $self->param('uuid');
    my $label  = $self->param('label') ;
    my $action = $self->param('action');
    exists $cgiByAction{$action} or
        throw EBox::Exceptions::External(
                __x('Inexistent action: {a}', a => $action)
                );

    my $actionCGI = $cgiByAction{$action};

    my $backup = $self->_backup($action);
    $backup->{size} = EBox::Util::FileSize::printableSize($backup->{size});

    my @parameters =(
            uuid      => $uuid,
            label     => $label,
            backup    => $backup,
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
        # need to use unsafeParam because of password parameter
        my $value = $self->unsafeParam($p);
        if ($value) {
            push @extraActionParams, ($p => $value);
        }
    }

    push @parameters, (extraActionParams => \@extraActionParams);

    if ($self->param('popup')) {
        push @parameters, (popup => 1);
    }

    return \@parameters;
}

# to avoid the <div id=content>
sub _print
{
    my ($self) = @_;
    if (not $self->param('popup')) {
        $self->SUPER::_print();
    } else {
        $self->_printPopup();
    }
}

1;
