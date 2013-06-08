# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Users::CGI::AddGroupToUser;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Users;
use EBox::Users::User;
use EBox::Users::Group;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups',
                      @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('user' , __('user'));
    my $user = $self->unsafeParam('user');
    $user = new EBox::Users::User(dn => $user);

    $self->{errorchain} = "Users/User";
    $self->keepParam('user');

    $self->_requireParam('addgroup', __('group'));
    my @groups = $self->unsafeParam('addgroup');

    foreach my $dn (@groups){
        my $group = new EBox::Users::Group(dn => $dn);
        $user->addGroup($group);
    }

    $self->{redirect} = 'Users/User?user=' . $user->dn();
}

1;
