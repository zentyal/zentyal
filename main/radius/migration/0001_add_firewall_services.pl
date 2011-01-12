#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
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
# This is a migration script to add a service and firewall rules
# for the Zentyal RADIUS system
#

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    my $service = EBox::Global->getInstance()->modInstance('services');
    my $firewall = EBox::Global->getInstance()->modInstance('firewall');

    my $serviceName = 'RADIUS';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('Zentyal RADIUS system'),
                'translationDomain' => 'ebox-radius',
                'internal' => 1,
                'services' => [
                                { # radius
                                    'protocol' => 'udp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '1812',
                                },
                              ]);
   }

   $firewall->setExternalService($serviceName, 'deny');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive();
}

EBox::init();

my $mod = EBox::Global->modInstance('radius');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mod,
        'version' => 1
        );
$migration->execute();
