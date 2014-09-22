# Copyright (C) 2014 Zentyal S.L.
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

package EBox::RemoteServices::CGI::Community::UnRegister;

use base qw(EBox::CGI::ClientBase);

use EBox::Global;

sub requiredParameters
{
    return ['disassociate'];
}

sub actuate
{
    my ($self) = @_;

    my $remoteservices = EBox::Global->getInstance()->modInstance('remoteservices');
    $remoteservices->unregisterCommunityServer();
    # TODO: Set a message
    $self->{redirect} = '/RemoteServices/Backup/Index';
}

1;
