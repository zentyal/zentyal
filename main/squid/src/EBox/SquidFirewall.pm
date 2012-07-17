# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::SquidFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;

sub prerouting
{
    my ($self) = @_;

    my $sq = $self->_global()->modInstance('squid');
    if ($sq->transproxy()) {
        return $self->_trans_prerouting();
    } else {
        return $self->_normal_prerouting();
    }
}

sub _normal_prerouting
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    return [] unless ($sq->filterNeeded());

    my $net = $global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->DGPORT();
    my @rules = ();

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addrs = $net->ifaceAddresses($ifc);
        my $input = $self->_inputIface($ifc);

        foreach my $addr (map { $_->{address} } @{$addrs}) {
            (defined($addr) && $addr ne "") or next;

            my $r = "$input -d $addr -p tcp --dport $sqport -j REDIRECT --to-ports $dgport";
            push (@rules, $r);
        }
    }

    return \@rules;
}

sub _trans_prerouting
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');

    my $sqport = $sq->port();
    my $dgport = $sq->DGPORT();
    my @rules = ();

    my $exceptions = $sq->model('TransparentExceptions');
    foreach my $id (@{$exceptions->enabledRows()}) {
        my $row = $exceptions->row($id);
        my $addr = $row->valueByName('domain');
        push (@rules, "-p tcp -d $addr --dport 80 -j ACCEPT");
        if ($sq->https()) {
            push (@rules, "-p tcp -d $addr --dport 443 -j ACCEPT");
        }
    }

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addrs = $net->ifaceAddresses($ifc);
        my $input = $self->_inputIface($ifc);

        foreach my $addr (map { $_->{address} } @{$addrs}) {
            (defined($addr) && $addr ne "") or next;

            my $port = $sq->filterNeeded() ? $dgport : $sqport;
            my $r = "$input ! -d $addr -p tcp --dport 80 -j REDIRECT --to-ports $port";
            push (@rules, $r);
            # TODO: https? will it work with dansguardian?
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

    my $sqport = $sq->port();
    my $dgport = $sq->DGPORT();
    my @rules = ();

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $input = $self->_inputIface($ifc);

        my $port = $sq->filterNeeded() ? $dgport : $sqport;
        my $r = "-m state --state NEW $input -p tcp --dport $port -j ACCEPT";
        push(@rules, $r);
    }
    push(@rules, "-m state --state NEW -p tcp --dport $sqport -j DROP");
    return \@rules;
}

sub output
{
    my ($self) = @_;

    my @rules = ();
    push(@rules, "-m state --state NEW -p tcp --dport 80 -j ACCEPT");
    push(@rules, "-m state --state NEW -p tcp --dport 443 -j ACCEPT");
    return \@rules;
}

sub _global
{
    my ($self) = @_;
    my $ro = $self->{ro};
    return EBox::Global->getInstance($ro);
}

1;
