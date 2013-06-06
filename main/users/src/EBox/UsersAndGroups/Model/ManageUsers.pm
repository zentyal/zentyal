# Copyright (C) 2013 Zentyal S.L.
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

package EBox::UsersAndGroups::Model::ManageUsers;

use base 'EBox::Model::TreeView';

use EBox::Gettext;

sub _tree
{
    my ($self) = @_;

    return {
        treeName => 'ManageUsers',
        modelDomain => 'UsersAndGroups',
        pageTitle => __('Users and Groups'),
        help =>  __('FIXME'),
    };
}

sub rootNodes
{
    my ($self) = @_;

    return [
        { id => 'users', printableName => __('Users') },
        { id => 'groups', printableName => __('Groups') },
    ];
}

sub childNodes
{
    my ($self, $parent) = @_;

    if ($parent eq 'users') {
        return $self->_userNodes();
    } elsif ($parent eq 'groups') {
        return $self->_groupNodes();
    } else {
        return [];
    }
}

sub _userNodes
{
    my ($self) = @_;

    my @nodes;

    foreach my $user (@{$self->parentModule()->realUsers()}) {
        my $id = $user->dn();
        my $printableName = $user->fullname();

        push (@nodes, { id => $id, printableName => $printableName });
    }

    return \@nodes;
}

sub _groupNodes
{
    my ($self) = @_;

    my @nodes;

    foreach my $group (@{$self->parentModule()->groups()}) {
        my $id = $group->dn();
        my $printableName = $group->name();

        push (@nodes, { id => $id, printableName => $printableName });
    }

    return \@nodes;
}

1;
