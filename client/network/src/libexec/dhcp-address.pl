#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Global;
use Error qw(:try);

EBox::init();

my $global = EBox::Global->getInstance(1);
my $network = $global->modInstance("network");

my $iface = shift;
my $address = shift;
my $mask = shift;

$iface or exit;
$address or exit;
$mask or exit;

try {
	$network->setDHCPAddress($iface, $address, $mask);
} finally {
	exit;
};
