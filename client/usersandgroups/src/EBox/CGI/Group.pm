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

package EBox::CGI::UsersAndGroups::Group;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;


sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Edit group'),
				      'template' => '/usersandgroups/group.mas',
				      @_);
	$self->{domain} = 'ebox-usersandgroups';
	bless($self, $class);
	return $self;
}


sub _process($) {
	my $self = shift;
	my $usersandgroups = EBox::Global->modInstance('users');

	my @args = ();

	$self->_requireParam('group', __('group'));
	
	my $group       = $self->param('group');
	my $groupinfo   = $usersandgroups->groupInfo($group);
	my $grpusers    = $usersandgroups->usersInGroup($group);
	my @remainusers = $usersandgroups->usersNotInGroup($group);
	my $components  = $usersandgroups->allGroupAddOns($group);

	push(@args, 'groupinfo' => $groupinfo);
	push(@args, 'groupusers' => $grpusers);
	push(@args, 'remainusers' => \@remainusers);
	push(@args, 'components' => $components);

	$self->{params} = \@args;
}


1;
