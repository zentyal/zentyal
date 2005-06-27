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

package EBox::CGI::Squid::General;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'squid',
				      @_);
	$self->{redirect} = "Squid/Index";
	$self->{domain} = "ebox-squid";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $squid = EBox::Global->modInstance('squid');

	$self->_requireParam('threshold', __('content filter threshold'));
	$squid->setBanThreshold($self->param("threshold"));

	$self->_requireParam('transparent', __('transparent proxy'));
	$squid->setTransproxy($self->param("transparent") eq 'yes');

	$self->_requireParam('port', __('listening port'));
	$squid->setPort($self->param("port"));

	$self->_requireParam('policy', __('global policy'));
	$squid->setGlobalPolicy($self->param("policy"));

}

1;
