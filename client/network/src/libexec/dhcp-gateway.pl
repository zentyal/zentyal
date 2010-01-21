#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Global;
use Error qw(:try);

EBox::init();

my $network = EBox::Global->modInstance('network');

my ($iface, $router) = @ARGV;

try {
    $network->setDHCPGateway($iface, $router);

    # Do not call regenGateways if we are restarting changes, they
    # are already going to be regenerated and also this way we
    # avoid nested lock problems
    unless (-f '/var/lib/ebox/tmp/ifup.lock') {
        $network->regenGateways();
    }
} finally {
    exit;
};
