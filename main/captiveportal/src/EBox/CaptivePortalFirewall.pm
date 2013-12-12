# Copyright (C) 2011-2011 Zentyal S.L.
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

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{network} = EBox::Global->modInstance('network');
    $self->{captiveportal} = EBox::Global->modInstance('captiveportal');

    bless($self, $class);
    return $self;
}


sub chains
{
    return {
        'nat' => [ 'captive' ],
        'filter' => ['icaptive', 'fcaptive']
    };
}


sub prerouting
{
    my ($self) = @_;
    my @rules = ();

    # Redirect HTTP traffic to redirecter
    my $port = $self->{captiveportal}->httpPort();
    my $ifaces = $self->{captiveportal}->ifaces();

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        my $r;
        $r = "$input -j captive";
        push(@rules, { 'priority' => 5, 'rule' => $r });

        push(@rules, @{$self->_usersRules('captive')});

        $r = "$input -p tcp --dport 80 -j REDIRECT --to-ports $port";
        push(@rules, { 'rule' => $r, 'chain' => 'captive' });
    }
    return \@rules;
}


sub postrouting
{
    my ($self) = @_;
    my @rules = ();

    my $port = $self->{captiveportal}->httpPort();
    my $ifaces = $self->{captiveportal}->ifaces();
    my $net = EBox::Global->modInstance('network');

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        foreach my $add (@{$net->ifaceAddresses($ifc)}) {
            my $ip = $add->{'address'};
            my $r = "$input -p tcp --sport $port -j SNAT --to-source $ip:$port";
            push(@rules, $r);
        }
    }

    return \@rules;
}


sub input
{
    my ($self) = @_;
    my @rules = ();

    my $port = $self->{captiveportal}->httpPort();
    my $captiveport = $self->{captiveportal}->httpsPort();
    my $ifaces = $self->{captiveportal}->ifaces();

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        my $r;

        # Allow DNS and Captive portal access
        $r = "$input -p tcp --dport 53 -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p udp --dport 53 -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p tcp --dport $port -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p tcp --dport $captiveport -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });

        $r = "$input -j icaptive";
        push(@rules, { 'priority' => 6, 'rule' => $r });

        push(@rules, @{$self->_usersRules('icaptive')});

        $r = "$input -p tcp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
        $r = "$input -p udp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'icaptive' });
    }
    return \@rules;
}


sub forward
{
    my ($self) = @_;
    my @rules = ();

    my $port = $self->{captiveportal}->httpPort();
    my $captiveport = $self->{captiveportal}->httpPort();
    my $ifaces = $self->{captiveportal}->ifaces();

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);
        my $r;

        $r = "$input -j fcaptive";
        push(@rules, { 'priority' => 6, 'rule' => $r });

        push(@rules, @{$self->_usersRules('fcaptive')});

        # Allow DNS
        $r = "$input -p tcp --dport 53 -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p udp --dport 53 -j ACCEPT";
        push(@rules, { 'rule' => $r, priority => 5 });

        $r = "$input -p tcp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        $r = "$input -p udp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
    }
    return \@rules;
}


# create logged users rules on firewall restart
sub _usersRules
{
    my ($self, $chain) = @_;

    my @rules;
    my $users = $self->{captiveportal}->currentUsers();
    for my $user (@{$users}) {
        my $r = $self->{captiveportal}->userFirewallRule($user);
        push(@rules, { 'rule' => $r, 'chain' => $chain });
    }
    return \@rules;
}

1;
