# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::CGI::UsersAndGroups::DelGroupFromUser;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;


sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups',
                      @_);
    $self->{domain} = 'ebox-usersandgroups';
    bless($self, $class);
    return $self;
}


sub _process
{
    my ($self) = @_;

    my $usersandgroups = EBox::Global->modInstance('users');

    $self->_requireParam('user' , __('user'));
    my $user = $self->param('user');
    $self->{errorchain} = "UsersAndGroups/User";
    $self->keepParam('user');

    $self->_requireParam('delgroup', __('group'));

    my @groups = $self->param('delgroup');

    foreach my $group (@groups){
        $usersandgroups->delUserFromGroup($user, $group);
    }

    # FIXME Is there a better way to pass parameters to redirect/chain
    # cgi's
    $self->{redirect} = "UsersAndGroups/User?username=$user";
}


1;
