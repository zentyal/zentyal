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

package EBox::CGI::IPSec::RSAView;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('RSA key'),
					'template' => 'ipsec/rsaview.mas');
	$self->{errorchain}  = 'IPSec/RSA';
	$self->{domain} = 'ebox-ipsec';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('RSA key');
	my $ipsec = EBox::Global->modInstance('ipsec');

	$self->_requireParam('id', __('RSA key ID'));
	my $key = $ipsec->getRSAPublicKey($self->param('id'));

	$self->{title} = __('RSA public key').": ". $self->param('id');

	my @array = ();
	push(@array, 'id' => $self->param('id'));
	push(@array, 'key' => $key);
	$self->{params} = \@array;
}

1;
