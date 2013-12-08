# Copyright (C) 2010-2011 Zentyal S.L.
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

package EBox::CGI::SysInfo::Hostname;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Validate;

use Sys::Hostname;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{errorchain} = "SysInfo/General";
    $self->{redirect} = "SysInfo/General";
    return $self;
}

sub _process
{
    my ($self) = @_;

    if (defined($self->param('sethostname'))) {
        my $hostname = $self->param('hostname');
        my $oldHostname = Sys::Hostname::hostname();
        if ($hostname ne $oldHostname) {
            EBox::Validate::checkHost($hostname, __('hostname'));
            my $global = EBox::Global->getInstance();
            my $apache = $global->modInstance('apache');
            $apache->set_string('hostname', $hostname);
            my $audit = EBox::Global->modInstance('audit');
            $audit->logAction('System', 'General', 'changeHostname', $hostname);
            $global->modChange('apache');
        }
    }
}

1;
