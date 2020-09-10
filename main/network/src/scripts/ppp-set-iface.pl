#!/usr/bin/perl

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

my $network = EBox::Global->modInstance('network');

my ($iface, $ppp_iface, $ppp_addr) = @ARGV;

EBox::debug('Called ppp-set-iface.pl with the following values:');
EBox::debug("iface: $iface") if $iface;
EBox::debug("ppp_iface: $ppp_iface") if $ppp_iface;
EBox::debug("ppp_addr: $ppp_addr") if $ppp_addr;

for my $tries (1 .. 10) {
    try {
        $network->setRealPPPIface($iface, $ppp_iface, $ppp_addr);
        # Do not call regenGateways if we are restarting changes,
        my $ifupLock = EBox::Util::Lock::_lockFile('ifup');
        unless (-f $ifupLock) {
            $network->regenGateways();
        }
        exit 0;
    } catch (EBox::Exceptions::Lock $e) {
        sleep 5;
    } catch {
        EBox::error("Call to setRealPPPIface for $iface failed");
        exit 1;
    }
}

exit 0;
