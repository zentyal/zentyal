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

package EBox::CGI::Jabber::JabberUserOptions;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::JabberLdapUser;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Jabber',
				      @_);
	$self->{domain} = "ebox-jabber";

	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $jabber = EBox::Global->modInstance('jabber');
	my $jabberldap = new EBox::JabberLdapUser;

	$self->_requireParam('username', __('username'));
	my $username = $self->param('username');
	$self->{redirect} = "UsersAndGroups/User?username=$username";	

	$self->keepParam('username');
	
	if ($self->param('active') eq 'yes'){
	    $jabberldap->setHasAccount($username, 1);
	    if (defined($self->param('is_admin')))
	    {
		$jabberldap->setIsAdmin($username,1);
	    } else {
		$jabberldap->setIsAdmin($username,0);
	    }
	} else {
	    if ($jabberldap->hasAccount($username)){
		$jabberldap->setHasAccount($username, 0);
	    }
	}
}

1;
