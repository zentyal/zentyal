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

# Import DHCP Server configuration from a YAML file

use warnings;
use strict;

use EBox;
use EBox::Global;
use Error qw(:try);
use YAML::XS;

if (@ARGV ne 1) {
    print "Exported DHCP servers info expected. Usage:\n";
    print "$0 exported_file.txt\n";
    exit 1;
}

EBox::init();

if (not EBox::Global->modExists('dhcp')) {
    print "DHCP module is not installed. Aborting\n";
    exit 1;
}

# Import configuration file
my ($dhcp_servers) = YAML::XS::LoadFile($ARGV[0]);

my $network = EBox::Global->modInstance('network');
my $objects = EBox::Global->modInstance('objects');
my $dhcp = EBox::Global->modInstance('dhcp');
my $manager = EBox::Model::ModelManager->instance();

foreach my $server (@$dhcp_servers) {
    my $iface = read_iface($network, $server->{ip});
    $network->setIfaceStatic($iface, $server->{ip}, $server->{netmask}, 0, 1);

    # DHCP
    my $table = $manager->model("/dhcp/RangeTable/$iface");
    $table->removeAll();
    my $counter = 0;
    foreach my $range (@{$server->{ranges}}) {
        print "Adding range $range->{from}-$range->{to}...\n";
        $counter++;
        $table->add(
            name => "range$counter",
            from => $range->{from},
            to => $range->{to},
        );
    }

    my @fixed_addrs = @{$server->{fixed_addrs}};
    if (@fixed_addrs > 0) {
        print "Creating dhcp_$iface object for fixed addresses\n";

        my @members;
        foreach my $fixed (@fixed_addrs) {
            print "   Adding IP $fixed->{ip}...\n";
            push (@members, {
                'name'             => $fixed->{name},
                'address_selected' => 'ipaddr',
                'address'          => 'ipaddr',
                'ipaddr_ip'        => $fixed->{ip},
                'ipaddr_mask'      => 32,
                'macaddr'          => $fixed->{mac},
            });
        }

        $objects->addObject(
            id      => "dhcp_$iface",
            name    => "dhcp_$iface",
            members => \@members,
        );

        print "Adding object to the DHCP server\n";
        my $table = $manager->model("/dhcp/FixedAddressTable/$iface");
        $table->removeAll();
        $table->add(object => "dhcp_$iface");
    }
}

# Methods

# Ask the user for an interface to configure dhcp server on it
sub  read_iface
{
    my ($network, $ip) = @_;
    my $iface = '';
    while ($iface eq '') {
        print "Interface for $ip: ";
        $iface =  <STDIN>;
        chomp ($iface);
        if (not $network->ifaceExists($iface)) {
            print "$iface does not exists\n";
            $iface = '';
        }
    }

    return $iface;
}
