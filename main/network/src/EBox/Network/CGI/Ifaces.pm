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

package EBox::Network::CGI::Ifaces;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Network Interfaces'),
            'template' => '/network/ifaces.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    $self->{params} = $self->masonParameters();
}

sub masonParameters
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifname = $self->param('iface');
    ($ifname) or $ifname = '';

    my $tmpifaces = $net->ifaces();
    my $iface = {};
    if ($ifname eq '') {
        $ifname = @{$tmpifaces}[0];
    }

    my @params = ();
    my @bridges = ();
    my @bonds = ();
    my @ifaces = ();
    my $vlans = [];

    foreach (@{$tmpifaces}) {
        my $ifinfo = {};
        $ifinfo->{'name'} = $_;
        $ifinfo->{'alias'} = $net->ifaceAlias($_);
        push(@ifaces,$ifinfo);
        ($_ eq $ifname) or next;
        $iface->{'name'} = $_;
        $iface->{'alias'} = $net->ifaceAlias($_);
        $iface->{'method'} = $net->ifaceMethod($_);
        if ($net->ifaceIsExternal($_)) {
            $iface->{'external'} = "yes";
        } else {
            $iface->{'external'} = "no";
        }
        if ($net->ifaceMethod($_) eq 'static') {
            $iface->{'address'} = $net->ifaceAddress($_);
            $iface->{'netmask'} = $net->ifaceNetmask($_);
            $iface->{'virtual'} = $net->vifacesConf($_);
        } elsif ($net->ifaceMethod($_) eq 'trunk') {
            $vlans = $net->ifaceVlans($_);
        } elsif ($net->ifaceMethod($_) eq 'bridged') {
            $iface->{'bridge'} = $net->ifaceBridge($_);
        } elsif ($net->ifaceMethod($_) eq 'bundled') {
            $iface->{'bond'} = $net->ifaceBond($_);
        } elsif ($net->ifaceMethod($_) eq 'ppp') {
            $iface->{'ppp_user'} = $net->ifacePPPUser($_);
            $iface->{'ppp_pass'} = $net->ifacePPPPass($_);
        }
        if ($net->ifaceIsBond($_)) {
            $iface->{'bond_mode'} = $net->bondMode($_);
        }
    }

    my $externalWarning = 0;
    if ($net->ifaceIsExternal($ifname)) {
        $externalWarning = $net->externalConnectionWarning($ifname, $self->request());
    }

    foreach my $bridge (@{$net->bridges()}) {
        my $brinfo = {};
        $brinfo->{'id'} = $bridge;
        $brinfo->{'name'} = "br$bridge";
        $brinfo->{'alias'} = $net->ifaceAlias("br$bridge");
        push (@bridges, $brinfo);
    }

    foreach my $bond (@{$net->bonds()}) {
        my $bondinfo = {};
        $bondinfo->{'id'} = $bond;
        $bondinfo->{'name'} = "bond$bond";
        $bondinfo->{'alias'} = $net->ifaceAlias("bond$bond");
        push (@bonds, $bondinfo);
    }

    @params = (
        'network'         => $net,
        'externalWarning' => $externalWarning,
        'iface'           => $iface,
        'ifaces'          => \@ifaces,
        'bridges'         => \@bridges,
        'bonds'           => \@bonds,
        'vlans'           => $vlans
    );

    return \@params;
}

1;
