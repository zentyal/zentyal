# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::NetworkUtil;

use strict;
use warnings;

use EBox::Network;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS  = (all => [qw{ gwReachable } ]);
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}


sub gwReachable # (network, address, exception?)
{
	my ($network, $gw, $exception) = @_;

	my $cidr_gw = "$gw/32";
	foreach (@{$network->allIfaces()}) {
		my $host = $network->ifaceAddress($_);
		my $mask = $network->ifaceNetmask($_);
		my $meth = $network->ifaceMethod($_);
		checkIPNetmask($gw, $mask) or next;
		($meth eq 'static') or next;
		(defined($host) and defined($mask)) or next;
		if (isIPInNetwork($host,$mask,$cidr_gw)) {
			return 1;
		}
	}

	if ($exception) {
		   throw EBox::Exceptions::External(
			   __x("Gateway {gw} not reachable", gw => $gw));
        } else {
		return undef;
	}
}

1;
