# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Network::CGI::Wizard::Network;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use TryCatch;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'network/wizard/network.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _masonParameters
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');

    my @exifaces = ();
    my @inifaces = ();
    foreach my $iface ( @{$net->ifaces} ) {
        if ( $net->ifaceIsExternal($iface) ) {
            push (@exifaces, $iface);
        } else {
            push (@inifaces, $iface);
        }
    }

    my @params = ();
    push (@params, 'extifaces' => \@exifaces);
    push (@params, 'intifaces' => \@inifaces);
    return \@params;
}

sub _processWizard
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $gwModel = $net->model('GatewayTable');

    # Remove possible gateways introduced by network-import script
    $gwModel->removeAll();

    my $interfaces = $net->get_hash('interfaces');

    foreach my $iface (@{$net->ifaces}) {
        my $method = $self->param($iface . '_method');

        if ($method eq 'dhcp') {
            my $ext =  $net->ifaceIsExternal($iface);
            $net->setIfaceDHCP($iface, $ext, 1);

            # As after the installation the method is already set
            # to DHCP, we need to force the change in order to
            # execute ifup during the first save changes
            $interfaces->{$iface}->{changed} = 1;
        } elsif ($method eq 'static') {
            my $ext =  $net->ifaceIsExternal($iface);
            my $addr = $self->param($iface . '_address');
            my $nmask = $self->param($iface . '_netmask');
            my $gw  = $self->param($iface . '_gateway');
            my $dns1 = $self->param($iface . '_dns1');
            my $dns2 = $self->param($iface . '_dns2');

            EBox::info("Configuring $iface as $addr/$nmask");
            $net->setIfaceStatic($iface, $addr, $nmask, $ext, 1);

            if ($gw) {
                EBox::info("Adding gateway $gw for iface $iface");
                try {
                    my $name      = "gw-$iface";
                    my $defaultGw = $gwModel->size() == 0;
                    $gwModel->add(name      => $name,
                                  ip        => $gw,
                                  default   => $defaultGw);
                } catch ($e) {
                    EBox::warn("Could not add gateway $gw: $e");
                }
            }

            my $dnsModel = $net->model('DNSResolver');
            if ($dns1) {
                unless ($dnsModel->find('nameserver' => $dns1)) {
                    EBox::info("Adding nameserver $dns1");
                    $dnsModel->add(nameserver => $dns1);
                }
            }
            if ($dns2) {
                unless ($dnsModel->find('nameserver' => $dns2)) {
                    EBox::info("Adding nameserver $dns2");
                    $dnsModel->add(nameserver => $dns2);
                }
            }
        }
    }

    $net->set('interfaces', $interfaces);
}

1;
