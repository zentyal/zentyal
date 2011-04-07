#!/usr/bin/perl

# Copyright (C) 2011 eBox Technologies S.L.
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

#
# This will add local address and local port to VPN internal clients

#

package EBox::Migration;

use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::RemoteServices::Auth;

sub runGConf
{
    my ($self) = @_;

    my $remoteservices = $self->{gconfmodule};
    my $openvpn = EBox::Global->modInstance('openvpn');
    defined $openvpn or
        return;

    my $clientModel = $openvpn->model('Clients');
    foreach my $id (@{  $clientModel->ids() }) {
        my $clientRow = $clientModel->row($id);
        if (not $clientRow->valueByName('internal')) {
            # no internal, skipping
            next;
        }

        my $clientSettings = $clientRow->elementByName('configuration')->foreignModelInstance();
        my $settingsRow = $clientSettings->row();

        my $alreadyHasLocal = $settingsRow->valueByName('localAddr') and
                              $settingsRow->valueByName('lport');
        if ($alreadyHasLocal) {
            next;
        }

        my $vpnServer = $settingsRow->valueByName('server');
        my $protocol  = $settingsRow->elementByName('serverPortAndProtocol')->protocol();
        my $localAddr = EBox::RemoteServices::Auth->_vpnClientLocalAddress($vpnServer);
        my $localPort = EBox::NetWrappers::getFreePort($protocol, $localAddr);

        # set values and store
        $settingsRow->elementByName('localAddr')->setValue($localAddr);
        $settingsRow->elementByName('lport')->setValue($localPort);
        $settingsRow->store();

        if (not $clientRow->valueByName('service')) {
            # client not enabled, we will not restart it
            next;
        }

        # write conf & restart changed client
        my $client = $openvpn->client($clientRow->valueByName('name'));
        my $confDir = $openvpn->confDir();
        $client->writeConfFile($confDir);

        if ($client->isRunning()) {
            $client->stop();
        }

        $client->start();
    }
}

EBox::init();

my $mod = EBox::Global->modInstance('remoteservices');
my $migration = __PACKAGE__->new(gconfmodule => $mod,
                                 version     => 3);

$migration->execute();
