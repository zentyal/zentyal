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

package EBox::CGI::Samba::SambaConf;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Samba',
				      @_);
	$self->{redirect} = "Samba/Index";	
	$self->{domain} = "ebox-samba";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $samba = EBox::Global->modInstance('samba');

	$self->_requireParam('netbios', __('netbios'));
	$self->_requireParam('workgroup', __('working group'));
	$self->_requireParam('description', __('description'));
	$self->_requireParam('userquota', __('user quota'));

	$samba->setWorkgroup($self->param('workgroup'));
	$samba->setNetbios($self->param('netbios'));
	$samba->setDefaultUserQuota($self->param('userquota'));
	$samba->setDescription($self->param('description'));

}

1;
