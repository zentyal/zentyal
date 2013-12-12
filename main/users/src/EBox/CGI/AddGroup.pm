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

package EBox::CGI::UsersAndGroups::AddGroup;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::Group;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups', @_);
    bless($self, $class);
    $self->{errorchain} = 'UsersAndGroups/Groups';
    return $self;
}


sub _process($)
{
    my $self = shift;

    my @args = ();

    $self->_requireParam('groupname', __('group name'));

    my $groupname = $self->param('groupname');
    my $comment = $self->unsafeParam('comment');

    my $group = EBox::UsersAndGroups::Group->create($groupname, $comment);

    if ($self->param('addAndEdit')) {
        $self->{redirect} = 'UsersAndGroups/Group?group=' . $group->dn();
    } else {
        $self->{redirect} = "UsersAndGroups/Groups";
    }
}

1;
