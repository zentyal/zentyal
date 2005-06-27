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

package EBox::CGI::Samba::ActivePrinting;

use strict;
use warnings;

use base 'EBox::CGI::Base';

use EBox::Global;
use EBox::SambaLdapUser;
use EBox::UsersAndGroups;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new {
        my $class = shift;
        my $self = $class->SUPER::new( @_);
	$self->{domain} = "ebox-samba";	

        bless($self, $class);
        return $self;
}

sub _process($) {
        my $self = shift;

	my ($user, $group);
 	if ($self->param('user')) {
		$self->_requireParam('user', __('user name'));
         	$user = $self->param('user');

        } else {
		$self->_requireParam('group', __('group name'));
         	$group = $self->param('group');
        }

        	
	my $samba = EBox::Global->modInstance('samba');
	my @newconf;
	for my $printer (@{$samba->printers()}) {
		push (@newconf,	 { 
				'name' => $printer, 
				'allowed' => $self->param($printer) ? 1 : undef 
				 });
	}

	if ($user) {
		$samba->setPrintersForUser($user, \@newconf);
        	$self->{redirect} = "UsersAndGroups/User?username=$user";
	} else {
		$samba->setPrintersForGroup($group, \@newconf);
        	$self->{redirect} = "UsersAndGroups/Group?group=$group";
	}
		
}

1;
