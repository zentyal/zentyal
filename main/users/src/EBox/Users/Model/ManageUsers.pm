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
        pageTitle => $self->parentModule()->printableName(),
        defaultActions => [ 'add', 'edit', 'delete' ],
        idParam => 'dn',
        help =>  __('Here you can manage Organizational Units, Users, Groups and Contacts. Also you can see the computers in the domain if using Samba. Please note that multiple OU support is partial, some modules may only work with users and groups in the default Users and Groups OUs.'),
    };
}

sub rootNodes
{
    my ($self) = @_;

    my $domain = EBox::Global->getInstance(1)->modInstance('sysinfo')->hostDomain();

    return [ { id => 'root', printableName => $domain, type => 'domain' } ];
}

sub childNodes
{
    my ($self, $parent) = @_;

    if ($parent eq 'root') {
        return $self->_ous();
    } elsif (($parent =~ /^ou=Computers,/) and EBox::Global->modExists('samba')) {
        return $self->_sambaComputers();
    } elsif ($parent =~ /^ou=/) {
        return $self->_ouObjects($parent);
    } else {
        return [];
    }
}

sub _ous
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

sub _sambaComputers
{
    my ($self) = @_;

    my $samba = EBox::Global->modInstance('samba');

    my @computers;

    foreach my $computer (@{$samba->computers()}) {
        my $id = $computer->dn();
        my $printableName = $computer->get('cn');
        push (@computers, { id => $id, printableName => $printableName, type => 'computer' });
    }

    return \@computers;
}

sub _ouObjects
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
    return [
        { name => 'domain', actions => { filter => 0, add => 1 } },
        { name => 'user', printableName => __('Users'), actions => { filter => 1, edit => 1, delete => 1 } },
        { name => 'group', printableName => __('Groups'), actions => { filter => 1, edit => 1, delete => 1 } },
        { name => 'computer', printableName => __('Computers'), actions => { filter => 1 } },
        { name => 'contact', printableName => __('Contacts'), actions => { filter => 1, edit => 1, delete => 1 } },
    ];
}

sub doubleClickHandlerJS
{
    my ($self, $type, $id) = @_;

    $self->actionHandlerJS('edit', $type, $id);
}

1;
