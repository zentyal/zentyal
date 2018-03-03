#!/usr/bin/perl

# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Exceptions::Lock;
use TryCatch;

EBox::init();

my $timeout = 60;
my $global = EBox::Global->getInstance(1);
$global->modExists("firewall") or exit(0);
my $fw = $global->modInstance("firewall");
exit (0) unless ($fw->isEnabled());


while ($timeout) {
	try {
		$fw->restartService();
		exit(0);
	} catch (EBox::Exceptions::Lock $e) {
		sleep 5;
		$timeout -= 5;
	}
}

EBox::error("DHCP hook: Firewall module has been locked for 60 seconds, ".
		"I give up.");
