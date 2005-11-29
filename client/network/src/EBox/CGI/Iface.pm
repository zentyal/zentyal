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

package EBox::CGI::Network::Iface;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = 'ebox-network';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $net = EBox::Global->modInstance('network');
	
	my $force = undef;

	$self->_requireParam("method", __("method"));
	$self->_requireParam("ifname", __("network interface"));

	$self->{errorchain} = "Network/Ifaces";

	my $iface = $self->param("ifname");
	my $alias = $self->param("ifalias");
	my $method = $self->param("method");
	my $address  = "";
	my $netmask  = "";
	my $external = undef;
	if (defined($self->param('external'))) {
		$external = 1;
	}

	$self->{redirect} = "Network/Ifaces?iface=$iface";

	if (defined($self->param("cancel"))) {
		return;
	} elsif (defined($self->param("force"))) {
		$force = 1;
	}

	$self->keepParam('iface');
	$self->cgi()->param(-name=>'iface', -value=>$iface);

	try {
		if (defined($alias)) {
			$net->setIfaceAlias($iface,$alias);
		}
		if ($method eq 'static') {
			$self->_requireParam("if_address", __("ip address"));
			$self->_requireParam("if_netmask", __("netmask"));
			$address = $self->param("if_address");
			$netmask = $self->param("if_netmask");
			$net->setIfaceStatic($iface, $address, $netmask, 
					$external, $force);
		} elsif ($method eq 'dhcp') {
			$net->setIfaceDHCP($iface, $external, $force);
		} elsif ($method eq 'trunk') {
			$net->setIfaceTrunk($iface, $force);
		} elsif ($method eq 'notset') {
			$net->unsetIface($iface, $force);
		}
	} catch EBox::Exceptions::DataInUse with {
		$self->{template} = 'network/confirm.mas';
		$self->{redirect} = undef;
		my @array = ();
		push(@array, 'iface' => $iface);
		push(@array, 'method' => $method);
		push(@array, 'address' => $address);
		push(@array, 'netmask' => $netmask);
		push(@array, 'external' => $external);
		$self->{params} = \@array;
	};
}

1;
