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

package EBox::CGI::Objects::AddTo;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	$self->{domain} = 'ebox-objects';
	$self->{redirect} = "/Objects/Index";
	return $self;
}

sub _process
{
	my $self = shift;
	my $objects = EBox::Global->modInstance('objects');

	$self->_requireParam('objectname', __('Object name'));
	$self->keepParam('objectname');
	$self->{redirect} = "/Objects/Edit?objectname=" . $self->param("objectname");

	$self->_requireParam('ip_addr', __('IP address'));
	$self->_requireParam('ip_mask', __('Netmask'));
	$self->_requireParam('ip_name', __('Name'));
	
	$objects->addToObject($self->param("objectname"),
	$self->param("ip_addr"),
	$self->param("ip_mask"),
	$self->param("mac"),
	$self->param("ip_name"));
}

1;
