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

# Class: EBox::SysInfo::CGI::SmartAdminReport;
#
use strict;
use warnings;

package EBox::SysInfo::CGI::SmartAdminReport;
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
#       Constructor for SmartAdminReport CGI
#
# Returns:
#
#       <EBox::SysInfo::CGI::SmartAdminReport> - The object recently created
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
        $self->_downloadSystemStatusReport();
    } else {
        $self->_generateSystemStatusReport($action);
    }
}

# Method: _runSystemStatusReportScript
#
sub _runSystemStatusReportScript
{
    my $cmd = EBox::Config::scripts() . "smart-admin-report";
    EBox::info("Running report generation from Smart Admin component");
    EBox::WebAdmin::cleanupForExec();
    EBox::Sudo::root($cmd . ' > /usr/share/zentyal/www/smart-admin.report');
}

# Method: _generateSystemStatusReport
#
sub _generateSystemStatusReport
{
    my ($self, $action) = @_;
    if ($action eq 'run') {
        $SIG{CHLD} = 'IGNORE';
        if (fork() == 0) {
            $self->_runSystemStatusReportScript();
        }
        $self->{redirect} = '/SysInfo/Composite/SmartAdmin';
    } elsif ($action eq 'status') {
        my $finished = not (-f '/var/lib/zentyal/tmp/.smart-admin-running');
        $self->{json} = { finished => $finished };
    }
}

# Method: _downloadSystemStatusReport
#
sub _downloadSystemStatusReport
{
    my ($self) = @_;
    my $path = '/usr/share/zentyal/www/smart-admin.report';
    my $temp = '/var/lib/zentyal/tmp/.smart-admin-running';

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
        throw EBox::Exceptions::Internal('Could NOT open the report file.');
    Plack::Util::set_io_path($fh, Cwd::realpath($self->{downfile}));

    my $response = $self->response();
    $response->status(200);
    $response->content_type('application/octet-stream');
    $response->header('Content-Disposition' => 'attachment; filename="' . $self->{downfilename} . '"');
    $response->body($fh);
}

1;