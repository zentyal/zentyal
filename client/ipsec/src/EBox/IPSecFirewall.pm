# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::IPSecFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;

sub new 
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        bless($self, $class);
        return $self;
}

sub input
{
	my $self = shift;
	my $net = EBox::Global->modInstance('network');
	my $ipsec = EBox::Global->modInstance('ipsec');
	my @static = @{$ipsec->staticActiveConnsArray()};
	my @rules = ();

	foreach my $conn (@static) {
		my $r = "-m state --state NEW -p 50 -s " . $conn->{rIP} .
			" -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p 51 -s " . $conn->{rIP} .
			" -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p udp --dport 500  -s " . 
			$conn->{rIP} .  " -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p udp --dport 4500  -s " . 
			$conn->{rIP} .  " -j ACCEPT";
		push(@rules, $r);
	}

	return \@rules;
}

sub output
{
	my $self = shift;
	my $net = EBox::Global->modInstance('network');
	my $ipsec = EBox::Global->modInstance('ipsec');
	my @static = @{$ipsec->staticActiveConnsArray()};
	my @rules = ();

	foreach my $conn (@static) {
		my $r = "-m state --state NEW -p 50 -d " . $conn->{rIP} .
			" -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p 51 -d " . $conn->{rIP} .
			" -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p udp --dport 500 -d " . 
			$conn->{rIP} .  " -j ACCEPT";
		push(@rules, $r);
		$r = "-m state --state NEW -p udp --dport 4500 -d " . 
			$conn->{rIP} .  " -j ACCEPT";
		push(@rules, $r);
	}

	return \@rules;
}

1;
