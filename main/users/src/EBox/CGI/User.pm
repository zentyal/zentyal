# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::CGI::UsersAndGroups::User;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;


sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/usersandgroups/user.mas',
                      @_);
    $self->{domain} = 'ebox-usersandgroups';
    bless($self, $class);
    return $self;
}


sub _process
{
    my ($self) = @_;
    my $usersandgroups = EBox::Global->modInstance('users');

    $self->{'title'} = __('Users');

    my @args = ();

    $self->_requireParam("username", __('username'));

    my $user = $self->param('username');
    my $userinfo = $usersandgroups->userInfo($user);
    my $components = $usersandgroups->allUserAddOns($user);
    my $usergroups = $usersandgroups->groupsOfUser($user);
    my $remaingroups = $usersandgroups->groupsNotOfUser($user);

    my $editable = $usersandgroups->editableMode();

    push(@args, 'user' => $userinfo);
    push(@args, 'usergroups' => $usergroups);
    push(@args, 'remaingroups' => $remaingroups);
    push(@args, 'components' => $components);
    push(@args, 'slave' => not $editable);

    if ($editable) {
        $self->{crumbs} = [
            {title => __('Users'),
                link => '/ebox/UsersAndGroups/Users'
            },
            {title => $user,
                link => undef,
            },
        ];
    }

    $self->{params} = \@args;
}

1;
