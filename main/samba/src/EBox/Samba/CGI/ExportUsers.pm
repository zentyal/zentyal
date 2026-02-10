# Copyright (C) 2011-2013 Zentyal S.L.
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

# Class: EBox::Samba::CGI::ExportUsers
#
#   CGI handler for exporting domain users to CSV.
#   Uses ProgressClient to show a native Zentyal progress bar during export.
#   Also handles the download of the generated CSV file.
#
use strict;
use warnings;

package EBox::Samba::CGI::ExportUsers;
use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::WebAdmin;
use EBox::Exceptions::Internal;
use EBox::ProgressIndicator;

use Plack::Util;
use Cwd qw(realpath);
use File::Basename;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
        title => __('Export Users'),
        @_
    );
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    my $action = $self->param('action');

    if ($action eq 'download') {
        EBox::info('Downloading users CSV');
        $self->_downloadUsersCSV();
    } elsif ($action eq 'run') {
        EBox::info('Running users exporter with progress');
        $self->_runExport();
    } else {
        # Default: show form/redirect back
        $self->{redirect} = '/Samba/Composite/ImportExport';
    }
}

sub _runExport
{
    my ($self) = @_;

    my $csvPath = EBox::Config::tmp() . 'users-export.csv';
    unlink $csvPath if (-f $csvPath);
    my $script = '/usr/share/zentyal-samba/users-export.pl';
    my $executable = "$script $csvPath";

    # Count users for totalTicks estimate
    my $totalTicks = 10; # default estimate
    eval {
        my $usersMod = EBox::Global->modInstance('samba');
        if ($usersMod and $usersMod->isEnabled()) {
            my @users = @{$usersMod->ldb()->users()};
            $totalTicks = scalar(@users);
            $totalTicks = 1 if ($totalTicks < 1);
        }
    };

    my $progressIndicator = EBox::ProgressIndicator->create(
        executable => $executable,
        totalTicks => $totalTicks,
    );
    $progressIndicator->runExecutable();

    $self->showProgress(
        progressIndicator  => $progressIndicator,
        title              => __('Exporting Users'),
        currentItemCaption => __('Current operation'),
        itemsLeftMessage   => __('users exported'),
        endNote            => __('Export finished successfully.') . ' <a href="/Samba/Composite/ImportExport">' . __('Go back') . '</a>',
        errorNote          => __('Some errors occurred during export.') . ' <a href="/Samba/Composite/ImportExport">' . __('Go back') . '</a>',
        reloadInterval     => 2,
        nextStepUrl        => '/Samba/ExportUsers?action=download',
        nextStepText       => __('Download CSV'),
    );
}

sub _downloadUsersCSV
{
    my ($self) = @_;
    my $path = EBox::Config::tmp() . 'users-export.csv';

    if (-f $path) {
        $self->{downfile} = $path;
        $self->{downfilename} = fileparse($path);
    } else {
        throw EBox::Exceptions::Internal(
            __('No exported CSV file found. Please run the export first.')
        );
    }
}

sub _print
{
    my ($self) = @_;

    if ($self->{error} or not defined($self->{downfile})) {
        $self->SUPER::_print;
        return;
    }

    open (my $fh, "<:raw", $self->{downfile}) or
        throw EBox::Exceptions::Internal('Could NOT open the csv file.');
    Plack::Util::set_io_path($fh, Cwd::realpath($self->{downfile}));

    my $response = $self->response();
    $response->status(200);
    $response->content_type('application/octet-stream');
    $response->header('Content-Disposition' => 'attachment; filename="' . $self->{downfilename} . '"');
    $response->body($fh);
}

1;