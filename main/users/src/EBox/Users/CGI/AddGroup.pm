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

package EBox::Users::CGI::AddGroup;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Users;
use EBox::Users::Group;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups', @_);
    bless($self, $class);
    $self->{errorchain} = 'Users/Groups';
    return $self;
}

sub _process($)
{
    my $self = shift;

    my @args = ();

    $self->_requireParam('groupname', __('group name'));

    my $groupname = $self->param('groupname');
    my $comment = $self->unsafeParam('comment');

    my $group = EBox::Users::Group->create($groupname, $comment);

    if ($self->param('addAndEdit')) {
        $self->{redirect} = 'Users/Group?group=' . $group->dn();
    } else {
        $self->{redirect} = "Users/Groups";
    }
}

1;
