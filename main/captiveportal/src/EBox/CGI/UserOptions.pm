# Copyright (C) 2011-2012 Zentyal S.L.
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

package EBox::CGI::CaptivePortal::UserOptions;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::CaptivePortal::LdapUser;
use EBox::UsersAndGroups::User;

## arguments:
##	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Captive Portal',
				      @_);

	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $cpldap = new EBox::CaptivePortal::LdapUser;

	$self->_requireParam('user', __('user'));
	my $user = $self->unsafeParam('user');
	$self->{redirect} = "UsersAndGroups/User?user=$user";

	$self->keepParam('user');

    my $user = new EBox::UsersAndGroups::User(dn => $user);

    my $overridden = not ($self->param('CaptiveUser_defaultQuota_selected') eq
                     'defaultQuota_default');

    my $quota = 0;
    if ($self->param('CaptiveUser_defaultQuota_selected') eq
        'defaultQuota_size') {
        $quota = $self->param('CaptiveUser_defaultQuota_size');
    }
    $cpldap->setQuota($user, $overridden, $quota);
}

1;
