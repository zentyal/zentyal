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

package EBox::CGI::Firewall::Filter;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Firewall;
use EBox::Objects;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Packet filtering'),
				      'template' => '/firewall/filter.mas',
				      @_);
	$self->{domain} = 'ebox-firewall';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Packet filtering');
	my $firewall = EBox::Global->modInstance('firewall');
	my $objects = EBox::Global->modInstance('objects');

	my $objectlist = $objects->ObjectsArray();

	foreach (@{$objectlist}) {
		delete($_->{member});
	}

	my @array = ();

	push(@array, 'deny' => $firewall->denyAction);
	if ($objectlist && length(@{$objectlist}) > 0) {
		push(@array, 'objects' => $objectlist);
	}
	$self->{params} = \@array;
}

1;
