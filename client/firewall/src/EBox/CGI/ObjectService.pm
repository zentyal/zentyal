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

package EBox::CGI::Firewall::ObjectService;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = 'ebox-firewall';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $firewall = EBox::Global->modInstance('firewall');

	$self->{errorchain} = "Firewall/Filter";
	$self->_requireParam('object', __('Object'));
	$self->{redirect} = "Firewall/Object?object=". $self->param("object");


	if (defined($self->param('add')) || defined($self->param('change'))) {
		$self->_requireParam('service', __('service'));
		$self->_requireParam('policy', __('policy'));
		$firewall->setObjectService($self->param("object"),
					 $self->param("service"),
					 $self->param("policy"));
	} elsif (defined($self->param('delete'))) {
		$self->_requireParam('service', __('service'));
		$firewall->removeObjectService($self->param("object"),
					    $self->param("service"));
	}

}

1;
