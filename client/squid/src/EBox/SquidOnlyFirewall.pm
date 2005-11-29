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

package EBox::SquidOnlyFirewall;
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

sub _trans_prerouting
{
	my $self = shift;
	my $sq = EBox::Global->modInstance('squid');
	my $net = EBox::Global->modInstance('network');
	my $sqport = $sq->port();
	my @rules = ();

	my @ifaces = @{$net->InternalIfaces()};
	my $pol = $sq->globalPolicy();
	foreach my $ifc (@ifaces) {
		my $addr = $net->ifaceAddress($ifc);
		(defined($addr) && $addr ne "") or next;

		my $r = "-i $ifc -d ! $addr -p tcp " . 
			"--dport 80 -j REDIRECT --to-ports $sqport";
		push(@rules, $r);
	}
	return \@rules;
}

sub prerouting
{
	my $self = shift;
	my $sq = EBox::Global->modInstance('squid');
	if ($sq->transproxy()) {
		return $self->_trans_prerouting();
	}
}

sub input
{
	my $self = shift;
	my $sq = EBox::Global->modInstance('squid');
	my $net = EBox::Global->modInstance('network');
	my $sqport = $sq->port();
	my @rules = ();

	my @ifaces = @{$net->InternalIfaces()};
	my $pol = $sq->globalPolicy();
	foreach my $ifc (@ifaces) {
		my $r = "-m state --state NEW -i $ifc -p tcp --dport $sqport ".
			"-j ACCEPT";
		push(@rules, $r);
	}
	return \@rules;
}

sub output
{
	my $self = shift;
	my $sq = EBox::Global->modInstance('squid');
	my @rules = ();
	push(@rules, "-m state --state NEW -p tcp --dport 80 -j ACCEPT");
	push(@rules, "-m state --state NEW -p tcp --dport 443 -j ACCEPT");
	return \@rules;
}

1;
