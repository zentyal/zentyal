# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenVPN::Migration;

sub addClientsAdvertisedNetworks
{
    my ($openvpn) = @_;
    my $changedConf;

    my $clientsModel = $openvpn->model('Clients');
    foreach my $id (@{ $clientsModel->ids() }) {
        my $row = $clientsModel->row($id);
        # populate the advertised networks with all internal interfaces so the
        # behaviour does not change
        my $advertise = $row->subModel('advertisedNetworks');
        if ($advertise->size() > 0) {
            # already has routes, ignoring
            next;
        }
        $advertise->populateWithInternalNetworks(1);
    }

    if ($changedConf) {
        $openvpn->saveConfig();
    }
}

1;
