# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::L2TP::LDAPUser;
use base qw(EBox::LdapUserBase);

use EBox::Gettext;
use EBox::Global;

sub _delGroup
{
    my ($self, $group) = @_;
    my $l2tp = EBox::Global->modInstance('l2tp');
    my $connections = $l2tp->model('Connections');
    $connections->delTunnelsForGroup($group->name());
}

sub _delGroupWarning
{
    my ($self, $group) = @_;
    my $l2tp = EBox::Global->modInstance('l2tp');
    my $connections = $l2tp->model('Connections');
    if ($connections->groupInUse($group->name())) {
        return (__('L2TP connections'));
    }
    return ();
}

1;
