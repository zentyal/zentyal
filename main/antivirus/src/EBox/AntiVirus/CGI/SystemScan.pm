# Copyright (C) 2018 Zentyal S.L.
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

package EBox::AntiVirus::CGI::SystemScan;
use base qw(EBox::CGI::ClientBase);

use EBox::Global;
use EBox::Config;
use EBox::WebAdmin;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Scan', @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $action = $self->param('action');

    if ($action eq 'scan') {
        $SIG{CHLD} = 'IGNORE';
        if (fork() == 0) {
            my $paths = EBox::Config::configkey('os_scan_paths');
            EBox::WebAdmin::cleanupForExec();
            exec ("/usr/share/zentyal-antivirus/clamscan-system $paths");
        }
        $self->{redirect} = 'Antivirus/Composite/General';
    } elsif ($action eq 'status') {
        my $finished = not (-f '/var/lib/zentyal/tmp/.clamscan-running');
        $self->{json} = { finished => $finished };
    }
}

1;
