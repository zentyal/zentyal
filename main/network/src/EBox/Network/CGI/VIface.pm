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

package EBox::Network::CGI::VIface;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::DataInUse;
use TryCatch;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    my $net = EBox::Global->modInstance('network');

    $self->{errorchain} = "Network/Ifaces";
    $self->_requireParam("ifname", __("network interface"));
    $self->_requireParam("ifaction", __("virtual interface action"));

    my $iface = $self->param("ifname");
    my $ifaction = $self->param("ifaction");

    my $force = undef;

    $self->{redirect} = "Network/Ifaces?iface=$iface";

    if (defined($self->param("cancel"))) {
        return;
    } elsif (defined($self->param("force"))) {
        $force = 1;
    }

    my $audit = EBox::Global->modInstance('audit');

    my $request = $self->request();
    my $parameters = $request->parameters();
    $self->keepParam('iface');
    $parameters->set('iface', $iface);
    if ($ifaction eq 'add'){
        $self->_requireParam("vif_address", __("IP address"));
        $self->_requireParam("vif_netmask", __("netmask"));
        $self->_requireParam("vif_name", __("virtual interface name"));
        my $name = $self->param("vif_name");
        my $address = $self->param("vif_address");
        my $netmask = $self->param("vif_netmask");
        $net->setViface($iface, $name, $address, $netmask);

        $audit->logAction('network', 'Interfaces', 'setViface', "$iface:$name, $address/$netmask", 1);
    } elsif ($ifaction eq 'delete')  {
        $self->_requireParam("vif_name", __("virtual interface name"));
        my $viface = $self->param("vif_name");
        try {
            $net->removeViface($iface, $viface, $force);

            $audit->logAction('network', 'Interfaces', 'removeViface', "$iface:$viface", 1);
        } catch (EBox::Exceptions::DataInUse $e) {
            $self->{template} = 'network/confirmremove.mas';
            $self->{redirect} = undef;
            my @array = ();
            push(@array, 'iface' => $iface);
            push(@array, 'viface' => $viface);
            $self->{params} = \@array;
        }
    }
}

1;
