# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::WebServer::Maintenance
#
#      This package is intended to manage the installation and removal
#      process
#

package EBox::WebServer::Maintenance;

use strict;
use warnings;

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;

# Method: onInstall
#
# 	Execute the first time the web module is installed.
#
#       *(Static method)*
#
sub onInstall
{
    # Become an eBox user
    EBox::init();

    # Get service module
    my $gl = EBox::Global->getInstance();
    my $serviceMod = $gl->modInstance('services');
    my $firewallMod = $gl->modInstance('firewall');
    my $port = 80; # Default port = 80

    # Add http service
    unless ( $serviceMod->serviceExists('name' => 'http')) {
        # Check port availability
        my $available = 0;
        do {
            $available = $firewallMod->availablePort('tcp', $port);
            unless ( $available ) {
                if ( $port == 80 ) {
                    $port = 8080;
                } else {
                    $port++;
                }
            }
        } until ( $available );
        $serviceMod->addService(
                                'name'            => 'http',
                                'description'     => __('HyperText Transport Protocol'),
                                'protocol'        => 'tcp',
                                'sourcePort'      => 'any',
                                'destinationPort' => $port,
                                'internal'        => 1,
                                'readOnly'        => 1,
                               );
        $firewallMod->setInternalService(
                                        'http',
                                        'accept',
                                       );
        # Save the changes
        $serviceMod->save();
        $firewallMod->save();
    } else {
        EBox::info('The http service is already exists, not adding');
        my $servId = $serviceMod->serviceId('http');
        $port = $serviceMod->serviceConfiguration($servId)->[0]->{destination};
    }
    # Save settings on the model
    my $webMod = $gl->modInstance('webserver');
    my $settingsModel = $webMod->model('GeneralSettings');
    $settingsModel->set(port => $port);
    $webMod->save();

}

# Method: onRemove
#
# 	Method to execute before the web eBox module is uninstalled
#
#       *(Static method)*
#
sub onRemove
{
    # Become an eBox user
    EBox::init();

    my $serviceMod = EBox::Global->modInstance('services');

    if ($serviceMod->serviceExists('name' => 'http')) {
        $serviceMod->removeService('name' => 'http');
    } else {
        EBox::info("Not removing http service as it already exists");
    }

    $serviceMod->save();
}


1;
