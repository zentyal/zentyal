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

package EBox::CGI::Firewall::Redirects;

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
	my $self = $class->SUPER::new('title' => __('Port redirections'),
				      'template' => '/firewall/redirects.mas',
				      @_);
	$self->{domain} = 'ebox-firewall';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Port redirections');
	my $firewall = EBox::Global->modInstance('firewall');
	my $net = EBox::Global->modInstance('network');

	my $redirections = $firewall->portRedirections;
	my $aux = $net->allIfaces;
	my @ifaces = ();
	foreach(@{$aux}) {
		push(@ifaces, {'name' => $_, 'alias' => $net->ifaceAlias($_)});			
	}

	my @array = ();

	if (defined($redirections)) {
		push(@array, 'redirections' => $redirections);
	}

	push(@array, 'ifaces' => \@ifaces);
	$self->{params} = \@array;
}

1;
