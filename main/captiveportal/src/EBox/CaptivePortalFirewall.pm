# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortalFirewall;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my %params = @_;
    my $self = $class->SUPER::new(@_);

    my $ro = $params{readOnly};
    my $global = EBox::Global->getInstance($ro);
    $self->{network} = $global->modInstance('network');
    $self->{captiveportal} = $global->modInstance('captiveportal');

    $self->{httpCapturePort} = undef;
    my  $squid = $global->modInstance('squid');
    if ($squid and $squid->transproxy()) {
        $self->{httpCapturePort} = $squid->port();
    }

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

    # Redirect HTTP and HTTPS traffic to redirecter
    my $port = $self->{captiveportal}->httpPort();
    my $captiveport = $self->{captiveportal}->httpsPort();
    my $ifaces = $self->{captiveportal}->ifaces();
    my @exRules =  @{$self->_exceptionsRules('captive')};

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        push(@rules, @{$self->_usersRules('captive')});
        push @rules, map {
            my $rule = $input . ' ' . $_->{rule};
            ($rule)
        } @exRules;

        my $r;
        $r = "$input -j captive";
        push(@rules, $r);

        $r = "$input -p tcp --dport 80 -j REDIRECT --to-ports $port";
        push(@rules, { 'rule' => $r, 'chain' => 'captive' });
        $r = "$input -p tcp --dport 443 -j REDIRECT --to-ports $captiveport";
        push(@rules, { 'rule' => $r, 'chain' => 'captive' });
    }
    return \@rules;
}

sub postrouting
{
    my ($self) = @_;
    my @rules = ();

    my $port = $self->{captiveportal}->httpPort();
    my $captiveport = $self->{captiveportal}->httpsPort();
    my $ifaces = $self->{captiveportal}->ifaces();
    my $net = $self->{network};

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        foreach my $add (@{$net->ifaceAddresses($ifc)}) {
            my $ip = $add->{'address'};
            my $r = "$input -p tcp --sport $port -j SNAT --to-source $ip:$port";
            push(@rules, $r);
            $r = "$input -p tcp --sport $captiveport -j SNAT --to-source $ip:$captiveport";
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

    push(@rules, @{$self->_exceptionsRules('icaptive')});

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);

        my $r;

        # Allow DNS and Captive portal access
        $r = "$input -p tcp --dport 53 -j iaccept";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p udp --dport 53 -j iaccept";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p tcp --dport $port -j iaccept";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p tcp --dport $captiveport -j iaccept";
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

    my $ifaces = $self->{captiveportal}->ifaces();
    my @exRules =  @{$self->_exceptionsRules('fcaptive')};

    foreach my $ifc (@{$ifaces}) {
        my $input = $self->_inputIface($ifc);
        my $r;

        push(@rules, @{$self->_usersRules('fcaptive')});
        push @rules, map {
            my $rule = $input . ' ' . $_->{rule};
            ($rule)
        } @exRules;
        # Allow DNS
        $r = "$input -p tcp --dport 53 -j faccept";
        push(@rules, { 'rule' => $r, priority => 5 });
        $r = "$input -p udp --dport 53 -j faccept";
        push(@rules, { 'rule' => $r, priority => 5 });

        $r = "$input -p tcp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });
        $r = "$input -p udp -j DROP";
        push(@rules, { 'rule' => $r, 'chain' => 'fcaptive' });

        $r = "$input -j fcaptive";
        push @rules, $r;
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

sub _exceptionsRules
{
    my ($self, $chain) = @_;

    my @rules = map {
        { 'rule' => $_, 'chain' => $chain }
    } @{  $self->{captiveportal}->exceptionsFirewallRules($chain) };

    return \@rules;
}

# we stop captiveportal to avoid race condition with not-yet added captive
# portal rules
sub beforeFwRestart
{
    my ($self) = @_;
    if ($self->{captiveportal}->needsSaveAfterConfig()) {
        # not really started and daemon file not configured, no need to stop
        return;
    }

    $self->{captiveportal}->stopService();
}

1;
