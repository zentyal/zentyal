# Copyright (C) 2005-2007 Warp Networks S.L
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

package EBox::CGI::UsersAndGroups::Group;

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
    my $self = $class->SUPER::new('title' => __('Edit group'),
                      'template' => '/users/group.mas',
                      @_);
    bless($self, $class);
    return $self;
}


sub _process
{
    my ($self) = @_;
    my $usersandgroups = EBox::Global->modInstance('users');

    my @args = ();

    $self->_requireParam('group', __('group'));

    my $group       = $self->unsafeParam('group');
    $group          = new EBox::UsersAndGroups::Group(dn => $group);
    my $grpusers    = $group->users();
    my $remainusers = $group->usersNotIn();
    my $components  = $usersandgroups->allGroupAddOns($group);

    my $editable = $usersandgroups->editableMode();

    push(@args, 'group' => $group);
    push(@args, 'groupusers' => $grpusers);
    push(@args, 'remainusers' => $remainusers);
    push(@args, 'components' => $components);
    push(@args, 'slave' => not $editable);

    if ($editable) {
        $self->{crumbs} = [
            {
                title => __('Groups'),
                link => '/UsersAndGroups/Groups'
            },
            {
                title => $group->name(),
                link => undef,
            },
        ];
    }

    $self->{params} = \@args;
}

1;
