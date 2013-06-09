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

package EBox::Users::Model::ManageUsers;

use base 'EBox::Model::TreeView';

use EBox::Gettext;
use EBox::Types::Action;

sub _tree
{
    my ($self) = @_;

    return {
        treeName => 'ManageUsers',
        modelDomain => 'Users',
        pageTitle => __('Users and Groups'),
        defaultActions => [ 'add', 'edit', 'delete' ],
        help =>  __('FIXME'),
    };
}

sub rootNodes
{
    my ($self) = @_;

    my @nodes;

    foreach my $ou (@{$self->parentModule()->ous()}) {
        my $dn = $ou->dn();
        my ($name) = $dn =~ /^ou=([^,]+),/;
        push (@nodes, { id => $dn, printableName => $name });
    }

    return \@nodes;
}

sub childNodes
{
    my ($self, $parent) = @_;

    my @nodes;

    foreach my $object (@{$self->parentModule()->ouObjects($parent)}) {
        my $id = $object->dn();
        my $printableName;
        my $type;

        if ($object->isa('EBox::Users::User')) {
            $type = 'user';
            $printableName = $object->fullname();
        } elsif ($object->isa('EBox::Users::Group')) {
            $type = 'group';
            $printableName = $object->name();
        } else {
            next;
        }

        push (@nodes, { id => $id, printableName => $printableName, type => $type });
    }

    return \@nodes;
}

sub nodeTypes
{
    return [ 'user', 'group' ];
}

1;
