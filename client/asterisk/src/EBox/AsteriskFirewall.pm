# Copyright (C) 2009 Warp Networks S.L.
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

package EBox::AsteriskFirewall;

use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Gettext;

use constant SIPUDPPORT => '5060';
use constant H323TCPPORT => '1720'; 
use constant H323UDPPORTRANGE => '5000:5014'; 
use constant IAXTCPPORT => '4569';
use constant RTPUDPPORTRANGE => '10000:20000';

sub new 
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        bless($self, $class);
        return $self;
}

sub output
{
	my $self = shift;
	my @rules = ();
	
	my $net = EBox::Global->modInstance('network');
	my @ifaces = @{$net->InternalIfaces()};

	my @AsteriskPorts = ();
	push(@AsteriskPorts, SIPUDPPORT);
	push(@AsteriskPorts, H323UDPPORTRANGE);
	push(@AsteriskPorts, RTPUDPPORTRANGE);

	foreach my $port (@AsteriskPorts){
	    foreach my $ifc (@ifaces) {
		my $r = "-m state --state NEW -o $ifc  ".
			"-p udp --sport $port -j ACCEPT";
		push(@rules, $r);
	    }
	}
	
	@AsteriskPorts = ();
	push(@AsteriskPorts, H323TCPPORT);

	foreach my $port (@AsteriskPorts){
	    foreach my $ifc (@ifaces) {
		my $r = "-m state --state NEW -o $ifc  ".
			"-p tcp --sport $port -j ACCEPT";
		push(@rules, $r);
	    }
	}
	
	return \@rules;
}

1;
