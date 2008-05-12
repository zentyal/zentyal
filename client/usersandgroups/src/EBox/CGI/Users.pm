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

package EBox::CGI::UsersAndGroups::Users;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;



sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Users'),
            'template' => '/usersandgroups/users.mas',
            @_);
    $self->{domain} = 'ebox-usersandgroups';
    bless($self, $class);
    return $self;
}


sub _process($) {
    my ($self) = @_;
    my $usersandgroups = EBox::Global->modInstance('users');

    my @args = ();

    if ($usersandgroups->configured()) {

        my @groups = $usersandgroups->groups();
        my @users = $usersandgroups->users();

        push(@args, 'groups' => \@groups);
        push(@args, 'users' => \@users);

    } else {
        $self->setTemplate('/notConfigured.mas'); 
        push(@args, 'module' => __('Users'));
    }

    $self->{params} = \@args;   
}

1;
