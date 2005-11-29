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

package EBox::CGI::IPSec::RoadWarriorEdit;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Road Warrior tunnel'),
				'template' => 'ipsec/roadwarrior-edit.mas');
	$self->{domain} = 'ebox-ipsec';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Road Warrior tunnel');
	my $ipsec = EBox::Global->modInstance('ipsec');
	my $network = EBox::Global->modInstance('network');

	$self->_requireParam('id', __('connection id'));
	my $id = $self->param('id');

	my $connection = $ipsec->getWarriorConn($id);
	unless (defined($connection)) {
		$self->{error} = __('The requested tunnel does not exist.');
		$self->{chain} = "IPSec/RoadWarrior";
		$self->{errorchain} = "IPSec/RoadWarrior";
		return;
	}

	my @array = ();

	my $rsakeys = $ipsec->listRSAKeys();
	push(@array, 'rsakeys' => $rsakeys);
	
	my $aux = $network->allIfaces();
	my @ifaces = ();
	foreach (@{$aux}) {
		push(@ifaces, {'name' => $_});
	}
	push(@array, 'ifaces' => \@ifaces);

	push(@array, 'connection' => $connection);
	push(@array, 'id' => $id);

	$self->{params} = \@array;

	if (defined($self->param('change'))) {
		my $enabled = undef;
		 if (defined($self->param('enabled')) and
		 	$self->param('enabled') eq 'yes') {
			$enabled = 1;
		}
		$self->_requireParam('name', __('connection name'));
		$self->_requireParam('iface', __('network interface'));
		$self->_requireParam('lnet', __('local network'));
		$self->_requireParam('lmask', __('local network mask'));
		$self->_requireParam('rnet', __('remote network'));
		$self->_requireParam('rmask', __('remote network mask'));
		$self->_requireParam('lid', __('RSA key'));
		$self->_requireParam('rid', __('remote id'));
		$self->_requireParam('rrsa', __('remote RSA key'));
		$ipsec->changeWarriorConn($id,
					$self->param('name'),
					$self->param('iface'),
					$self->param('lnet'),
					$self->param('lmask'),
					$self->param('rnet'),
					$self->param('rmask'),
					$self->param('lid'),
					$self->param('rid'),
					$self->param('rrsa'),
					$enabled);
	} elsif (defined($self->param('cancel'))) {
		$self->{redirect} = "IPSec/RoadWarrior";
		return;
	}

	@array = ();
	push(@array, 'rsakeys' => $rsakeys);
	push(@array, 'ifaces' => \@ifaces);
	push(@array, 'connection' => $ipsec->getWarriorConn($id));
	push(@array, 'id' => $id);
	$self->{params} = \@array;
}

1;
