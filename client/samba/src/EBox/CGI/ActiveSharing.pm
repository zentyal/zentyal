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

package EBox::CGI::Samba::ActiveSharing;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::SambaLdapUser;
use EBox::UsersAndGroups;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new {
        my $class = shift;
        my $self = $class->SUPER::new('title' => 'Users and Groups',
                                      @_);
	$self->{domain} = "ebox-samba";	

        bless($self, $class);
        return $self;
}

sub _group {
	my $self = shift;
	
	my $samba = new EBox::SambaLdapUser;
	
	$self->_requireParam('group', __('group name'));
	$self->keepParam('group');	
	$self->{errorchain} =  "UsersAndGroups/Group";
	$self->_requireParamAllowEmpty('sharename', __('sharing name'));
	my $name =  $self->param('sharename');
	my $group = $self->param('group');
	if ($self->param('namechange') or $self->param('add')) {
		$samba->setSharingName($group, $name);
	} elsif ($self->param('remove')) {
		$samba->removeSharingName($group);
	}

	$self->{redirect} = "UsersAndGroups/Group?group=$group";
}

sub _user {
	my $self = shift;
	
	my $smbldap = new EBox::SambaLdapUser;
	my $smb = EBox::Global->modInstance('samba');
	

	$self->_requireParam('user', __('user name'));
	$self->keepParam('user');
	$self->{errorchain} =  "UsersAndGroups/User";
	$self->_requireParam('active', __('active'));
	my $user = $self->param('user');
	my $active = $self->param('active');
	
	$self->{redirect} = "UsersAndGroups/User?username=$user";

	$smbldap->setUserSharing($user, $active);
	$smb->setAdminUser($user, $self->param('is_admin'));
}

sub _process($) {
        my $self = shift;

	if ($self->param('user')) {	
		$self->_user;
	} else {
		$self->_group;	
	}
}

1;
