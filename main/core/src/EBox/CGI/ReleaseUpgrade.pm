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

package EBox::CGI::ReleaseUpgrade;
use base qw(EBox::CGI::ClientPopupBase);

use EBox::Global;
use EBox::Gettext;
use EBox::WebAdmin;
use EBox::GlobalImpl;

my $LOGFILE = '/var/log/zentyal/upgrade.log';

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Upgrade Zentyal'),
                                  'template' => '/upgrade.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $action = $self->param('action');

    if ($action eq 'upgrade') {
        if (fork() == 0) {
            EBox::WebAdmin::cleanupForExec();
            exec ('/usr/share/zentyal/upgrade-wrapper');
        }
    } elsif ($action eq 'output') {
        my $output = `tail -10 $LOGFILE`;
        utf8::decode($output);
        my $finished = (-f '/var/lib/zentyal/.upgrade-finished');
        $self->{json} = { output => $output, finished => $finished };
#    } else {
#        my @removedModules;
#        foreach my $module (qw(ips nut ebackup monitor radius webserver webmail ipsec)) {
#            if (EBox::GlobalImpl::_packageInstalled("zentyal-$module")) {
#                push (@removedModules, $module);
#            }
#        }
#        $self->{params} = [ removedModules => \@removedModules ];
    }
}

1;
