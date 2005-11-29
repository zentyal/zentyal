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

package EBox::CGI::Network::Diag;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Network diagnosis'),
				      'template' => '/network/diag.mas',
				      @_);
	$self->{domain} = 'ebox-network';

	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Network diagnosis');

	my $net = EBox::Global->modInstance('network');

	my @array = ();

	my $action = $self->param("action");

	if(defined($action)){
		if($action eq "ping"){
			$self->_requireParam("ip", __("Host"));
			my $ip = $self->param("ip");
			my $output = $net->ping($ip);
			push(@array, 'action' => 'ping');
			push(@array, 'target' => $ip);
			push(@array, 'output' => $output);
		}elsif($action eq "dns"){
			$self->_requireParam("host", __("host name"));
			my $host = $self->param("host");
			my $output = $net->resolv($host);
			push(@array, 'action' => 'dns');
			push(@array, 'target' => $host);
			push(@array, 'output' => $output);
		}
	}
	$self->{params} = \@array;
}

1;
