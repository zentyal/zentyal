# Copyright (C) 2013-2014 Zentyal S.L.
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

package EBox::SysInfo::CGI::CrashReport;

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;
use EBox::Validate;
use EBox::Util::BugReport;

use constant OC_CRASH_UPLOAD => '/usr/share/openchange/upload-crash-report.py';
my $CRASH_DIR = '/var/crash';
my $CRASHREPORT_SERVER_URL = 'http://crashreport.zentyal.org/report/';

sub _process
{
    my ($self) = @_;

    my $action = $self->param('action');
    my $email = $self->param('email');

    if ($email) {
        $email = "-n $email";
    } else {
        $email = ""
    }

    # FIXME: unhardcode samba if more daemon crashes are watched

    if ($action eq 'report') {
        my @files = @{EBox::Sudo::root("ls $CRASH_DIR | grep ^_usr_sbin_samba")};
        if (EBox::Sudo::fileTest('-x', OC_CRASH_UPLOAD)) {
            foreach my $file (@files) {
                chomp($file);
                EBox::info("Sending crash report: $file");
                EBox::Sudo::root('python3 ' . OC_CRASH_UPLOAD . " $email $CRASH_DIR/$file $CRASHREPORT_SERVER_URL");
            }
            EBox::Sudo::root('rm -f /var/crash/_usr_sbin_samba*');
        } else {
            EBox::error('Cannot send crash report as ' . OC_CRASH_UPLOAD . ' is not available');
        }
    } elsif ($action eq 'discard') {
        EBox::Sudo::root('rm -f /var/crash/_usr_sbin_samba*');
    }
}

sub requiredParameters
{
    my ($self) = @_;

    return [ 'action' ];
}

1;
