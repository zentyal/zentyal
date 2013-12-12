# Copyright (C) 2004-2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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


package EBox::CGI::UsersAndGroups::Users;
use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Users'),
            'template' => '/users/users.mas',
            @_);
    bless($self, $class);
    return $self;
}


sub _process($) {
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');

    my @args = ();

    if ($users->configured()) {
        push(@args, 'groups' => $users->groups());
        push(@args, 'users' => $users->users());

        if ($users->multipleOusEnabled) {
            push(@args, 'ous' => $users->ous());

            my $ou = $self->unsafeParam('filterOU');
            if ((defined $ou) and ($ou eq '_all')) {
                $ou = undef;
            }

            EBox::debug("setOUFilterAction: $ou");
            my $usersModel =  $users->model('Users');
            $usersModel->setFilterOU($ou);
            push @args, (usersModel => $usersModel);
        }
    } else {
        $self->setTemplate('/notConfigured.mas');
        push(@args, 'module' => __('Users'));
    }

    $self->{params} = \@args;
}

1;
