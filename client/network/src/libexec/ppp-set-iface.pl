#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Global;
use Error qw(:try);

EBox::init();

my $network = EBox::Global->modInstance('network');

my ($iface, $ppp_iface, $ppp_addr) = @ARGV;

try {
    $network->setRealPPPIface($iface, $ppp_iface, $ppp_addr);
    $network->regenGateways();
} finally {
    exit;
};
