#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Exceptions::Lock;
use Error qw(:try);

EBox::init();

my $timeout = 60;
my $global = EBox::Global->getInstance(1);
$global->modExists("firewall") or exit(0);
my $fw = $global->modInstance("firewall");


while ($timeout) {
	try {
		$fw->restartService();
		exit(0);
	} catch EBox::Exceptions::Lock with {
		sleep 5;
		$timeout -= 5;
	};
}

EBox::error("DHCP hook: Firewall module has been locked for 60 seconds, ".
		"I give up.");
