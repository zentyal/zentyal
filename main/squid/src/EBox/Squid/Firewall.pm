# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Squid::Firewall;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;

use Socket;

# Method: prerouting
#
#   To set transparent HTTP proxy if it is enabled
#
# Overrides:
#
#   <EBox::FirewallHelper::prerouting>
#
sub prerouting
{
    my ($self) = @_;

    my $sq = $self->_global()->modInstance('squid');
    if ((not $sq->temporaryStopped()) and $sq->transproxy()) {
        return $self->_trans_prerouting();
    }

    return [];
}

# Method: restartOnTemporaryStop
#
# Overrides:
#
#   <EBox::FirewallHelper::restartOnTemporaryStop>
#
sub restartOnTemporaryStop
{
    return 1;
}

sub _trans_prerouting
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq      = $global->modInstance('squid');
    my $net     = $global->modInstance('network');

    my $sqport = $sq->port();
    my @rules = ();

    my $exceptions = $sq->model('TransparentExceptions');
    foreach my $id (@{$exceptions->enabledRows()}) {
        my $row = $exceptions->row($id);
        my $addr = $row->valueByName('domain');
        my ($h, undef, undef, undef, @addrs) = gethostbyname($addr);
        if ($h) {
            foreach my $packedIPAddr (@addrs) {
                my $ipAddr = inet_ntoa($packedIPAddr);
                push (@rules, "-p tcp -d $ipAddr --dport 80 -j ACCEPT");
            }
        }
    }

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addrs = $net->ifaceAddresses($ifc);
        my $input = $self->_inputIface($ifc);

        foreach my $addr (map { $_->{address} } @{$addrs}) {
            (defined($addr) && $addr ne "") or next;
            my $rHttp = "$input ! -d $addr -p tcp --dport 80 -j REDIRECT --to-ports $sqport";
            push (@rules, $rHttp);
            # https does not work in transparent mode with squid, so no https
            # redirect there
        }
    }

    if ($global->modExists('openvpn')) {
        # add openvpn interfaces
        my $openvpn = $global->modInstance('openvpn');
        $openvpn->initializeInterfaces();
        my @servers = grep {
            my $server = $_;

        } $openvpn->servers();

        foreach my $server (@servers) {
            if ((not $server->isEnabled()) or ( $server->pullRoutes()) or ($server->internal())) {
                next;
            }

            my $iface    = $server->iface();
            my $addr     = $server->ifaceAddress();
            if (not $addr) {
                next;
            }
            my $rHttp = "-i $iface ! -d $addr -p tcp --dport 80 -j REDIRECT --to-ports $sqport";
            push (@rules, $rHttp);
        }
    }

    return \@rules;
}

sub input
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');

    my $port = $sq->port();
    my $proxyPort = $sq->PROXYPORT_FILTER();
    my @rules = ();

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $input = $self->_inputIface($ifc);
        my $r = "-m state --state NEW $input -p tcp --dport $port -j iaccept";
        push (@rules, $r);
    }
    push (@rules, "-m state --state NEW -p tcp --dport $proxyPort -j DROP");
    return \@rules;
}

sub output
{
    my ($self) = @_;

    my @rules;
    push (@rules, "-m state --state NEW -p tcp --dport 80 -j oaccept");
    push (@rules, "-m state --state NEW -p tcp --dport 443 -j oaccept");
    return \@rules;
}

sub preForward
{
    my ($self) = @_;

    my $global = $self->_global();

    return [] if $global->communityEdition();

    my $sq = $global->modInstance('squid');
    my $profilesModel = $sq->model('FilterProfiles');
    my @rules;
    my %domainsById;

    my (undef, $min, $hour, undef, undef, undef, $day) = localtime();
    foreach my $profile (@{$sq->model('AccessRules')->filterProfiles()}) {
        next unless ($profile->{usesHTTPS} and not $profile->{group});

        if ($profile->{timePeriod}) {
            next unless ($profile->{days}->{$day});
            if ($profile->{begin}) {
                my ($beginHour, $beginMin) = split (':', $profile->{begin});
                next if ($hour < $beginHour);
                next if (($hour == $beginHour) and ($min < $beginMin));
            }
            if ($profile->{end}) {
                my ($endHour, $endMin) = split (':', $profile->{end});
                next if ($hour > $endHour);
                next if (($hour == $endHour) and ($min >= $endMin));
            }
        }
        my $id = $profile->{id};
        unless (exists $domainsById{$id}) {
            $domainsById{$id} = $profilesModel->row($id)->subModel('filterPolicy')->deniedDomains();
        }
        foreach my $domain (@{$domainsById{$id}}) {
            my $addr = $profile->{address};
            my $src;
            if (index ($addr, '-') == -1) {
                $src = "-s $addr";
            } else {
                $addr =~ s:/255.255.255.255::;
                $src = "-m iprange --src-range $addr";
            }
            push (@rules, "-p tcp --dport 443 $src -m string --string '$domain' --algo bm --to 65535 -j REJECT");
        }
    }

    return \@rules;
}

sub _global
{
    my ($self) = @_;
    my $ro = $self->{ro};
    return EBox::Global->getInstance($ro);
}

1;
