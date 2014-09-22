#!/usr/bin/perl

# Copyright (C) 2011-2014 Zentyal S.L.
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
use LWP::UserAgent;
use Pod::Usage;

# Constants
use constant REQUEST_TIMEOUT => 10;
my $CHAIN = EBox::Network::CHECKIP_CHAIN();
my @DST_HOSTS = ('icanhazip.com', 'myexternalip.com/raw', 'checkip.dyndns.org', 'ipecho.net/plain');

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
my @rules = ("/sbin/iptables -t mangle -F $CHAIN || true");
foreach my $dstHost (@DST_HOSTS) {
    my $host = $dstHost;
    $host =~ s/\/.*$//g;
    push(@rules, "/sbin/iptables -t mangle -A $CHAIN -d $host " .
                 "-p tcp --dport 80 -j MARK --set-mark $gwMark ");
}
EBox::Sudo::root(@rules);

my $ua = new LWP::UserAgent(timeout => REQUEST_TIMEOUT,
                            env_proxy => 1);

# Perform the query as ebox
my $ip;
foreach my $dstHost (@DST_HOSTS) {
    my $res = $ua->get("http://$dstHost");
    if ($res->is_success()) {
        ($ip) = $res->decoded_content() =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/x;
        last if ($ip);
    }
}

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
