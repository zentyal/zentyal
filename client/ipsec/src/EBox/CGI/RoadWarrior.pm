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

package EBox::CGI::IPSec::RoadWarrior;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Road Warrior tunnels'),
					'template' => 'ipsec/roadwarrior.mas');
	$self->{domain} = 'ebox-ipsec';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Road Warrior tunnels');
	my $ipsec = EBox::Global->modInstance('ipsec');
	my $network = EBox::Global->modInstance('network');

	my @array = ();

	my $rsakeys = $ipsec->listRSAKeys();
	push(@array, 'rsakeys' => $rsakeys);

	my $aux = $network->allIfaces();
	my @ifaces = ();
	foreach (@{$aux}) {
		push(@ifaces, {'name' => $_});
	}
	push(@array, 'ifaces' => \@ifaces);

	push(@array, 'connections' => $ipsec->warriorConnsArray());

	$self->{params} = \@array;
	

	if (defined($self->param('add'))) {
		$self->_requireParam('name', __('connection name'));
		$self->_requireParam('iface', __('network interface'));
		$self->_requireParam('lnet', __('local network'));
		$self->_requireParam('lmask', __('local network mask'));
		$self->_requireParam('rnet', __('remote network'));
		$self->_requireParam('rmask', __('remote network mask'));
		$self->_requireParam('lid', __('RSA key'));
		$self->_requireParam('rid', __('remote id'));
		$self->_requireParam('rrsa', __('remote RSA key'));
		$ipsec->addWarriorConn($self->param('name'),
					$self->param('iface'),
					$self->param('lnet'),
					$self->param('lmask'),
					$self->param('rnet'),
					$self->param('rmask'),
					$self->param('lid'),
					$self->param('rid'),
					$self->param('rrsa'));
	} elsif (defined($self->param('delete'))) {
		$self->_requireParam('id', __('connection id'));
		$ipsec->removeWarriorConn($self->param('id'));
	}

	@array = ();
	push(@array, 'ifaces' => \@ifaces);
	push(@array, 'rsakeys' => $rsakeys);
	push(@array, 'connections' => $ipsec->warriorConnsArray());

	$self->{params} = \@array;
}

1;
