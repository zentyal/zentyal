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

package EBox::Network::CGI::Iface;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use TryCatch::Lite;

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

    $self->{errorchain} = 'Network/Ifaces';

    $self->_requireParam('ifname', __('network interface'));
    my $iface = $self->param('ifname');
    $self->{redirect} = "Network/Ifaces?iface=$iface";

    $self->setIface();
}

sub setIface
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');

    my $force = undef;

    $self->_requireParam('method', __('method'));
    $self->_requireParam('ifname', __('network interface'));

    my $iface = $self->param('ifname');
    my $alias = $self->param('ifalias');
    my $method = $self->param('method');
    my $address  = '';
    my $netmask  = '';
    my $external = undef;
    if (defined($self->param('external'))) {
        $external = 1;
    }
    my $extStr = $external ? 'external' : 'internal'; # string for audit log

    if (defined($self->param('cancel'))) {
        return;
    } elsif (defined($self->param('force'))) {
        $force = 1;
    }

    my $request = $self->request();
    my $parameters = $request->parameters();
    $self->keepParam('iface');
    $parameters->set('iface', $iface);

    my $audit = EBox::Global->modInstance('audit');

    try {
        if (defined($alias)) {
            $net->setIfaceAlias($iface,$alias);

            $audit->logAction('network', 'Interfaces', 'setIfaceAlias', "$iface, $alias", 1) if ($iface ne $alias);
        }
        if ($method eq 'static') {
            $self->_requireParam('if_address', __('ip address'));
            $self->_requireParam('if_netmask', __('netmask'));
            $address = $self->param('if_address');
            $netmask = $self->param('if_netmask');
            $net->setIfaceStatic($iface, $address, $netmask,
                    $external, $force);

            $audit->logAction('network', 'Interfaces', 'setIfaceStatic', "$iface, $address, $netmask, $extStr", 1);
        } elsif ($method eq 'dhcp') {
            $net->setIfaceDHCP($iface, $external, $force);

            $audit->logAction('network', 'Interfaces', 'setIfaceDHCP', "$iface, $extStr", 1);
        } elsif ($method eq 'trunk') {
            $net->setIfaceTrunk($iface, $force);

            $audit->logAction('network', 'Interfaces', 'setIfaceTrunk', $iface, 1);
        } elsif ($method eq 'notset') {
            $net->unsetIface($iface, $force);

            $audit->logAction('network', 'Interfaces', 'unsetIface', $iface, 1);
        }
    } catch (EBox::Exceptions::DataInUse $e) {
        $self->{template} = 'network/confirm.mas';
        $self->{redirect} = undef;
        my @array = ();
        push(@array, 'iface' => $iface);
        push(@array, 'method' => $method);
        push(@array, 'address' => $address);
        push(@array, 'netmask' => $netmask);
        push(@array, 'external' => $external);
        $self->{params} = \@array;
    }
}

1;
