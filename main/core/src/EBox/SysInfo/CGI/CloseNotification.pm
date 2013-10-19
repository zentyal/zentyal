# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::SysInfo::CGI::CloseNotification;

use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use TryCatch;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('message');
    my $name = $self->param('message');

    my $global = EBox::Global->getInstance();
    my $sysinfo = $global->modInstance('sysinfo');

    my $state = $sysinfo->get_state();
    $state->{closedMessages}->{$name} = 1;
    $state->{lastMessageTime} = time();
    $sysinfo->set_state($state);
}

1;
