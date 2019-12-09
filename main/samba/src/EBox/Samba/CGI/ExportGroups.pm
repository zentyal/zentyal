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

# Class: EBox::Samba::CGI::ExportGroups;
#
use strict;
use warnings;

package EBox::Samba::CGI::ExportGroups;
use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Config;
use EBox::WebAdmin;
use EBox::Exceptions::Internal;

use Plack::Util;
use Cwd qw(realpath);
use HTTP::Date;
use File::Basename;

# Method: new
#
#       Constructor for group exporter CGI
#
# Returns:
#
#       <EBox::Samba::CGI::ExportGroups> - The object recently created
sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

# Group: Protected methods

# Method: _process
#
#      Gets the appropriate GET param to call the right subroutine
#
# Overrides:
#
#      <EBox::CGI::Base::_process>
#
sub _process
{
    my $self = shift;
    my $action = $self->param('action');
    if ( $action eq 'download') {
        EBox::info('Downloading groups CSV');
        $self->_downloadGroupsCSV();
    } else {
        EBox::info("Running groups exporter");
        $self->_generateGroupsCSV($action);
    }
}

# Method: _generateSystemStatusReport
#
sub _generateGroupsCSV
{
    my ($self, $action) = @_;
    if ($action eq 'run') {
        $SIG{CHLD} = 'IGNORE';
        if (fork() == 0) {
            EBox::WebAdmin::cleanupForExec();
            EBox::Sudo::root('/usr/share/zentyal-samba/groups-export.pl /tmp/groups-export.csv');
        }
        $self->{redirect} = '/Samba/Composite/ImportExport';
    } elsif ($action eq 'status') {
        my $finished = not (-f '/var/lib/zentyal/tmp/.groups_exporter-running');
        $self->{json} = { finished => $finished };
    }
}

# Method: _downloadSystemStatusReport
#
sub _downloadGroupsCSV
{
    my ($self) = @_;
    my $path = '/tmp/groups-export.csv';
    my $temp = '/var/lib/zentyal/tmp/.groups_exporter-running';

    unless (-e $temp) {
        if (-f $path) {
            # Setting the file
            $self->{downfile} = $path;
            # Setting the file name
            $self->{downfilename} = fileparse($path);
        }
    }
}

# Method: _print
#
# Overrides:
#
#   <EBox::CGI::Base::_print>
#
# Overwrite the _print method to send the file
#
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