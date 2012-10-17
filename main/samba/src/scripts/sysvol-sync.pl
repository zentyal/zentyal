#!/usr/bin/perl
#
# Copyright (C) 2012 eBox Technologies S.L.
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

use EBox::Global;
use Net::Ping;

EBox::init();
EBox::info("Samba sysvol synchronizer script started");

$ENV{KRB5CCNAME}="/tmp/sync.$$";

my $samba = EBox::Global->modInstance('samba');
my $sambaSettings = $samba->model('GeneralSettings');
my $sourceDC = $sambaSettings->dcfqdnValue();
my $mode = $sambaSettings->modeValue();
my $adc  = $sambaSettings->MODE_ADC();

my $pinger = Net::Ping->new('tcp', 2);
$pinger->port_number(445);

while (1) {
    # The script will be executed each 300 to 600 seconds
    my $randomSleep = 300 + int (rand (300));
    EBox::debug("Sleeping for $randomSleep seconds");
    sleep ($randomSleep);

    # Do nothing if server not provisioned and module enabled
    next unless ($samba->isEnabled() and $samba->isProvisioned());

    # Do nothing if server is not an additional DC
    next unless ($mode eq $adc);

    # Try to ping the DC
    EBox::debug("Trying to ping $sourceDC\n");
    unless ($pinger->ping($sourceDC)) {
        EBox::warn("$sourceDC is not reachable");
        next;
    }

    $samba->importSysvolFromDC($sourceDC);
    $samba->resetSysvolACL();
}

EBox::info("Samba sysvol synchronizer script stopped");
exit 0;
