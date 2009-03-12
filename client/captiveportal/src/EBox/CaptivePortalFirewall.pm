# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::CaptivePortalFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;
use EBox::CaptivePortalHelper;

sub new
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        bless($self, $class);
        return $self;
}

sub chains
{
    return [ 'icaptive', 'fcaptive' ];
}

sub prerouting
{
	my ($self) = @_;
	my @rules = ();

	my $captiveportal = EBox::Global->modInstance('captiveportal');
    my $port = $captiveportal->port();
	my $ifaces = $captiveportal->ifaces();

    foreach my $ifc (@{$ifaces}) {
		my $r = "-i $ifc -p tcp --dport 80 -j REDIRECT --to-ports $port";
		push(@rules, $r);
    }
	return \@rules;
}

sub postrouting
{
	my ($self) = @_;
	my @rules = ();

	my $net = EBox::Global->modInstance('network');
	my $captiveportal = EBox::Global->modInstance('captiveportal');
    my $port = $captiveportal->port();
	my $ifaces = $captiveportal->ifaces();

    foreach my $ifc (@{$ifaces}) {
        foreach my $add (@{$net->ifaceAddresses($ifc)}) {
            my $ip = $add->{'address'};
            my $r = "-i $ifc -p tcp --sport $port -j SNAT --to-source $ip:$port";
            push(@rules, $r);
        }
    }

	return \@rules;
}

sub input
{
	my ($self) = @_;
	my @rules = ();

	my $captiveportal = EBox::Global->modInstance('captiveportal');
    my $port = $captiveportal->port();
	my $ifaces = $captiveportal->ifaces();

	my $usercorner = EBox::Global->modInstance('usercorner');
    my $ucport = $usercorner->port();

    foreach my $ifc (@{$ifaces}) {
		my $r;
        $r = "-i $ifc -j icaptive";
		push(@rules, { 'priority' => 5, 'rule' => $r });

        my $users = EBox::CaptivePortalHelper::currentUsers();
        for my $user (@{$users}) {
            my $ip = $user->{'ip'};
            $r = "-s $ip -j RETURN";
		    push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        }

        $r = "-i $ifc -p tcp --dport 53 -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "-i $ifc -p udp --dport 53 -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "-i $ifc -p tcp --dport $port -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "-i $ifc -p tcp --dport $ucport -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "-i $ifc -p tcp -j DROP";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "-i $ifc -p udp -j DROP";
		push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
    }
	return \@rules;
}

sub forward
{
	my ($self) = @_;
	my @rules = ();

	my $captiveportal = EBox::Global->modInstance('captiveportal');
    my $port = $captiveportal->port();
	my $ifaces = $captiveportal->ifaces();

    foreach my $ifc (@{$ifaces}) {
		my $r;
        $r = "-i $ifc -j fcaptive";
		push(@rules, { 'priority' => 5, 'rule' => $r });

        my $users = EBox::CaptivePortalHelper::currentUsers();
        for my $user (@{$users}) {
            my $ip = $user->{'ip'};
            $r = "-s $ip -j RETURN";
		    push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        }

        $r = "-i $ifc -p tcp --dport 53 -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        $r = "-i $ifc -p udp --dport 53 -j ACCEPT";
		push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        $r = "-i $ifc -p tcp -j DROP";
		push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        $r = "-i $ifc -p udp -j DROP";
		push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
    }
	return \@rules;
}

1;
