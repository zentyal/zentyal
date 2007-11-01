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

package EBox::CGI::UsersAndGroups::DelUserFromGroup;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;


sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Users and Groups',
				      @_);
#        $self->{redirect} = "UsersAndGroups/Group";
	$self->{domain} = 'ebox-usersandgroups';
	bless($self, $class);
	return $self;
}


sub _process($) {
	my $self = shift;
	my $usersandgroups = EBox::Global->modInstance('usersandgroups');

	my @args = ();
	
	$self->_requireParam('group' , __('group'));
	my $group = $self->param('group');
	$self->{errorchain} = "UsersAndGroups/Group";
	$self->keepParam('group');
	
	$self->_requireParam('deluser', __('user'));
	
	my @users = $self->param('deluser');
	
	foreach my $us (@users){
		$usersandgroups->delUserFromGroup($us, $group);
	}

	# FIXME Is there a better way to pass parameters to redirect/chain
        # cgi's
        $self->{redirect} = "UsersAndGroups/Group?group=$group";

}


1;
