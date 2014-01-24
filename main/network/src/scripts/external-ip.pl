#!/usr/bin/perl

# Copyright (C) 2011-2013 Zentyal S.L.
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

# Script: external-ip.pl
#
#    Get the external IP address using a fixed gateway
#

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Network;
use Pod::Usage;

# Constants
my $CHAIN = EBox::Network::CHECKIP_CHAIN();
my $DST_HOST = 'checkip.dyndns.org';

if (scalar(@ARGV) != 1 ) {
    pod2usage(-msg => 'Requires a gateway name', -exitval => 1);
}

EBox::init();

my $networkMod = EBox::Global->modInstance('network');

my $gwModel = $networkMod->model('GatewayTable');

my $gwId = $gwModel->findId(name => $ARGV[0]);
unless (defined($gwId)) {
    pod2usage(-msg => "$ARGV[0] is not a valid gateway name", -exitval => 2);
}

my $marks  = $networkMod->marksForRouters();
my $gwMark = $marks->{$gwId};

# Add the iptables marks
my @rules = ("/sbin/iptables -t mangle -F $CHAIN || true",
             "/sbin/iptables -t mangle -A $CHAIN -d $DST_HOST " .
             "-p tcp --dport 80 " .
             "-j MARK --set-mark $gwMark ");
EBox::Sudo::root(@rules);

# Perform the query as ebox
my $output = EBox::Sudo::command("/usr/bin/wget http://$DST_HOST -O - -q");
my ($ip) = $output->[0] =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;

# Flush the CHECKIP chain
EBox::Sudo::silentRoot("/sbin/iptables -t mangle -F $CHAIN");

print "$ip\n";

__END__

=head1 NAME

external-ip.pl - Get the external IP address using a fixed gateway

=head1 SYNOPSIS

external-ip.pl gateway-name

gateway-name : the gateway to use for the check

=cut
