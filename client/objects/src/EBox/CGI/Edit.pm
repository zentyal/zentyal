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

package EBox::CGI::Objects::Edit;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Edit Object'),
				  'template' => '/objects/edit.mas', @_);
	$self->{domain} = 'ebox-objects';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{title} = __('Edit Object');
	my $objects = EBox::Global->modInstance('objects');

	$self->_requireParam('objectname', __('Object name'));

	my $name = $self->param("objectname");
	my $members = $objects->ObjectMembers($name);
	my $description = $objects->ObjectDescription($name);
	my @array = ();

	push(@array, 'members' => $members);
	push(@array, 'name'=> $name);
	push(@array, 'description'=> $description);

	$self->{params} = \@array;
}

1;
