# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::IPSec::Static;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Static tunnels'),
					'template' => 'ipsec/static.mas');
	$self->{domain} = 'ebox-ipsec';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Static tunnels');
	my $ipsec = EBox::Global->modInstance('ipsec');
	my $net = EBox::Global->modInstance('network');

	my @array = ();

	my $rsakeys = $ipsec->listRSAKeys();
	push(@array, 'rsakeys' => $rsakeys);

	my $aux = $net->allIfaces();
	my @ifaces = ();
	foreach (@{$aux}) {
		push(@ifaces, {'name' => $_, 'alias' => $net->ifaceAlias($_)});
	}
	push(@array, 'ifaces' => \@ifaces);

	push(@array, 'connections' => $ipsec->staticConnsArray());
	$self->{params} = \@array;

	if (defined($self->param('add'))) {
		my $remoteid = "";
		my $remotersa = "";
		$self->_requireParam('name', __('connection name'));
		$self->_requireParam('iface', __('network interface'));
		$self->_requireParam('rIP', __('remote IP address'));
		$self->_requireParam('lnet', __('local network'));
		$self->_requireParam('lmask', __('local network mask'));
		$self->_requireParam('rnet', __('remote network'));
		$self->_requireParam('rmask', __('remote network mask'));
		$self->_requireParam('authmethod', __('authentication method'));
		my $authparam = 'sharedsecret';
		if ($self->param('authmethod') eq 'sharedsecret') {
			$self->_requireParam('sharedsecret',
				__('shared secret'));
		} else {
			$self->_requireParam('rsakey', __('RSA key'));
			$self->_requireParam('remoteid', __('remote id'));
			$self->_requireParam('remotersa', __('remote RSA key'));
			$authparam = 'rsakey';
			$remoteid = $self->param('remoteid');
			$remotersa = $self->param('remotersa');
		}
		$ipsec->addStaticConn($self->param('name'),
					$self->param('iface'),
					$self->param('lnet'),
					$self->param('lmask'),
					$self->param('rIP'),
					$self->param('rnet'),
					$self->param('rmask'),
					$self->param('authmethod'),
					$self->param($authparam),
					$remoteid,
					$remotersa);
	} elsif (defined($self->param('delete'))) {
		$self->_requireParam('id', __('connection id'));
		$ipsec->removeStaticConn($self->param('id'));
	}

	@array = ();

	push(@array, 'rsakeys' => $rsakeys);
	push(@array, 'ifaces' => \@ifaces);
	push(@array, 'connections' => $ipsec->staticConnsArray());

	$self->{params} = \@array;
}

1;
