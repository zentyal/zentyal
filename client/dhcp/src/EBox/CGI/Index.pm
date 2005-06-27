# Copyright (C) 2005  Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::DHCP::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => 'DHCP',
				      'template' => 'dhcp/index.mas',
				      @_);
	$self->{domain} = 'ebox-dhcp';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $dhcp = EBox::Global->modInstance('dhcp');
	my $net = EBox::Global->modInstance('network');
	my @names = $self->cgi->param;

	my $ifaces = $net->allIfaces();
	my @iflist = ();

	foreach (@{$ifaces}) {
		if ($net->ifaceMethod($_) eq 'static') {
			push(@iflist, $_);
		}
	}

	my %iface;
	my $gateway = "";
	my $fixed = undef;
	my $ranges = undef;

	if(@iflist != 0) {
		$iface{name} = $self->param("iface");
		if(! defined($iface{name})) {
			#if not specified in URL take first static iface
			$iface{name} = $iflist[0];
		}
		foreach(@iflist){
			if($_ eq $iface{name}){
				$iface{address} = $net->ifaceAddress($_);
				$iface{netmask} = $net->ifaceNetmask($_);
				$iface{network} = $net->ifaceNetwork($_);
				$iface{init} = $dhcp->initRange($_);
				$iface{end} = $dhcp->endRange($_);
			}
		}
		$fixed = $dhcp->fixedAddresses($iface{name});
		$ranges = $dhcp->ranges($iface{name});
		$gateway = $dhcp->defaultGateway($iface{name});
	}

	my @array = ();
	push (@array, 'iface'    	=> \%iface);
	push (@array, 'ranges'    	=> $ranges);
	push (@array, 'ifaces'    	=> \@iflist);
	push (@array, 'fixed'    	=> $fixed);
	push (@array, 'gateway'		=> $gateway);
	push (@array, 'active'		=> $dhcp->service() ? 'yes' : 'no' );
	$self->{params} = \@array;
}

1;
