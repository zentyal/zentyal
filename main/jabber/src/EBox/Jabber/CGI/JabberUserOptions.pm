# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Jabber::CGI::JabberUserOptions;
use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Gettext;
use EBox::JabberLdapUser;


sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Jabber',
                                  @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;
    my $jabberldap = new EBox::JabberLdapUser;

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    my $user = new EBox::Samba::User(dn => $userDN);

    if ($self->param('active') eq 'yes'){
        $jabberldap->setHasAccount($user, 1);
        $self->{json}->{enabled} = 1;
        if ($self->param('is_admin')) {
            $jabberldap->setIsAdmin($user, 1);
            $self->{json}->{admin} = 1;
            $self->{json}->{msg} = __('Jabber account enabled with administration rights');
        } else {
            $jabberldap->setIsAdmin($user, 0);
            $self->{json}->{msg} = __('Jabber account enabled');
        }
    } else {
        if ($jabberldap->hasAccount($user)){
            $jabberldap->setHasAccount($user, 0);
        }
        $self->{json}->{enabled} = 0;
        $self->{json}->{msg} = __('Jabber account disabled');
    }

    $self->{json}->{success} = 1;
}

1;
