# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::SysInfo::CGI::Backup;
use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Config;
use EBox::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use Cwd qw(realpath);
use HTTP::Date;
use Plack::Util;
use Sys::Hostname;
use TryCatch;


sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Configuration Backup'),
                      'template' => '/backupTabs.mas',
                      @_);
    $self->{errorchain} = "SysInfo/Backup";

    $self->{audit} = EBox::Global->modInstance('audit');

    bless($self, $class);
    return $self;
}

sub _print
{
    my ($self) = @_;

    if (defined($self->{downfile}) and (not defined $self->{error})) {
        # file download

        open (my $fh, "<:raw", $self->{downfile}) or
            throw EBox::Exceptions::Internal('Could not open backup file.');
        Plack::Util::set_io_path($fh, Cwd::realpath($self->{downfile}));

        my $response = $self->response();
        $response->status(200);
        $response->content_type('application/octet-stream');
        my @stat = stat $self->{downfile};
        $response->content_length($stat[7]);
        $response->header('Last-Modified' => HTTP::Date::time2str($stat[9]));
        $response->header('Content-Disposition' => 'attachment; filename="' . $self->{downfilename} . '"');
        $response->body($fh);
    } elsif (not $self->{popup}) {
        $self->SUPER::_print();
    } else {
        $self->{template} = '/ajax/simpleModalDialog.mas';
        $self->_printPopup();
    }
}

sub requiredParameters
{
    my ($self) = @_;

    if ($self->param('backup')) {
        return [qw(backup description)];
    } elsif ($self->param('bugreport')) {
        return [qw(bugreport)];
    } elsif ($self->param('restoreFromFile')) {
        return [qw(restoreFromFile backupfile)];
    } elsif ($self->param('restoreFromId')) {
        return [qw(restoreFromId id)];
    } elsif ($self->param('download')) {
        return [qw(id download)];
    } elsif ($self->param('delete')) {
        return [qw(delete id)];
    } elsif ($self->param('bugReport')) {
        return [qw(bugReport)];
    } else {
        return [];
    }
}

sub optionalParameters
{
    my ($self) = @_;

    if ($self->param('cancel')) {
        return ['.*'];
    }

    return ['selected', 'download', 'popup'];
}

sub actuate
{
    my ($self) = @_;
    $self->{popup} = $self->param('popup');

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

    my $subscribed = 0;
    push @params, (subscribed => $subscribed);

    return \@params;
}

sub _backupAction
{
    my ($self) = @_;

    my $description = $self->param('description');
    my $progressIndicator;
    try {
        my $backup = EBox::Backup->new();
        $progressIndicator= $backup->prepareMakeBackup(description => $description);
    } catch ($e) {
        $self->setErrorFromException($e);
    }

    if ($progressIndicator) {
        $self->_showBackupProgress($progressIndicator);
        $self->{audit}->logAction('System', 'Backup', 'exportConfiguration', $description);
    }
}

sub _restoreFromFileAction
{
    my ($self) = @_;

    my $filename = $self->unsafeParam('backupfile');
    # poor man decode html entity for '/'
    $filename =~ s{%2F}{/}g;
    $self->_restore($filename);

    $self->{audit}->logAction('System', 'Backup', 'importConfiguration', $filename);
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

    $self->{audit}->logAction('System', 'Backup', 'importConfiguration', $id);
}

sub _restore
{
    my ($self, $filename) = @_;

    my $backup = new EBox::Backup;

    my $progressIndicator;
    try {
        $progressIndicator = $backup->prepareRestoreBackup($filename);
    } catch ($e) {
        $self->setErrorFromException($e);
    }

    if ($progressIndicator) {
        $self->_showRestoreProgress($progressIndicator);
    }
}

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Zentyal.Dialog.close(); window.location='/SysInfo/Backup?selected=local'; return false",
);

sub _showBackupProgress
{
    my ($self, $progressIndicator) = @_;
    my @params = (
            progressIndicator => $progressIndicator,

            title    => __('Backing up'),
            text               =>  __('Backing up modules'),
            currentItemCaption =>  __('Operation') ,
            itemsLeftMessage   =>  __('operations left to finish backup'),
            endNote            =>  __('Backup successful'),
            reloadInterval     =>  2,
            );
    if ($self->param('popup')) {
        push @params, @popupProgressParams;
    }

    $self->showProgress(@params);
}

sub _showRestoreProgress
{
    my ($self, $progressIndicator) = @_;

    my @params = (
            progressIndicator  => $progressIndicator,

            title              => __('Restoring backup'),
            text               =>   __('Restoring modules'),
            currentItemCaption =>   __('Module') ,
            itemsLeftMessage   =>   __('modules restored'),
            endNote            =>   __('Restore successful'),
            reloadInterval     =>   4,
            );
    if ($self->param('popup')) {
        push @params, @popupProgressParams;
    }

    $self->showProgress(@params);
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
    $self->{downfilename} = hostname() . "_$id.tar";

    $self->{audit}->logAction('System', 'Backup', 'downloadConfigurationBackup', $id);
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

    $self->{audit}->logAction('System', 'Backup', 'deleteConfigurationBackup', $id);
}

sub  _bugreportAction
{
    my ($self) = @_;

    my $backup = EBox::Backup->new();
    $self->{errorchain} = 'SysInfo/Bug';
    $self->{downfile} = $backup->makeBugReport();
    $self->{downfilename} = 'zentyal-configuration-report.tar';

    $self->{audit}->logAction('System', 'Backup', 'downloadConfigurationReport');
}

1;
