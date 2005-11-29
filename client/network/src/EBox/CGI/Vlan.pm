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

package EBox::CGI::Network::Vlan;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

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

	$self->_requireParam("ifname", __("network interface"));
	my $iface = $self->param("ifname");

	$self->{redirect} = "Network/Ifaces?iface=$iface";
	$self->{errorchain} = "Network/Ifaces";

	$self->keepParam('iface');
	$self->cgi()->param(-name=>'iface', -value=>$iface);
	
	if (defined($self->param('del'))) {
		$self->_requireParam("vlanid", __("VLAN Id"));
		$net->removeVlan($self->param('vlanid'));
	} elsif (defined($self->param('add'))) {
		$self->_requireParam("vlanid", __("VLAN Id"));
		$net->createVlan($self->param('vlanid'),
				 $self->param('vlandesc'),
				 $iface);
	} 
}

1;
