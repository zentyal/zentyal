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

package EBox::Users::Model::Manage;

use base 'EBox::Model::TreeView';

use EBox::Gettext;
use EBox::Types::Action;

sub _tree
{
    my ($self) = @_;

    return {
        treeName => 'Manage',
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

    my $usersMod = $self->parentModule();
    my $defaultNamingContext = $usersMod->defaultNamingContext();

    return [ { id => 'root', printableName => $defaultNamingContext->baseName(), type => 'domain' } ];
}

sub childNodes
{
    my ($self, $parent) = @_;

    my $usersMod = $self->parentModule();

    my $parentObject = undef;

    if ($parent eq 'root') {
        $parentObject = $usersMod->defaultNamingContext();
    } elsif (($parent =~ /^ou=Computers,/) and EBox::Global->modExists('samba')) {
        # FIXME: Integrate this better with the rest of the logic.
        return $self->_sambaComputers();
    } else {
        $parentObject = $usersMod->objectFromDN($parent);
    }

    my $id = undef;
    my $printableName = undef;
    my $type = undef;
    my @childNodes = ();
    foreach my $child (@{$parentObject->children()}) {
        $id = $child->dn();
        if ($child->isa('EBox::Users::OU')) {
            $type = 'ou';
            $printableName = $child->name();
            # Hide Kerberos OU as it's not useful for the user to keep the UI simple
            next if ($printableName eq 'Kerberos');
        } elsif ($child->isa('EBox::Users::User')) {
            $type = 'user';
            $printableName = $child->fullname();
            unless ($printableName) {
                $printableName => $child->name();
            }
        } elsif ($child->isa('EBox::Users::Contact')) {
            $type = 'contact';
            $printableName = $child->fullname();
        } elsif ($child->isa('EBox::Users::Group')) {
            $type = 'group';
            $printableName = $child->name();
        } else {
            EBox::warn("Unknown object type for DN: " . $child->dn());
            next;
        }
        push (@childNodes, { id => $id, printableName => $printableName, type => $type });
    }

    return \@childNodes;
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

sub nodeTypes
{
    return {
        domain => { actions => { filter => 0, add => 1 }, actionObjects => { add => 'OU' } },
        ou => { actions => { filter => 0, add => 1, delete => 1 }, actionObjects => { delete => 'OU', add => 'Object' }, defaultIcon => 1 },
        user => { printableName => __('Users'), actions => { filter => 1, edit => 1, delete => 1 } },
        group => { printableName => __('Groups'), actions => { filter => 1, edit => 1, delete => 1 } },
        computer => { printableName => __('Computers'), actions => { filter => 1 } },
        contact => { printableName => __('Contacts'), actions => { filter => 1, edit => 1, delete => 1 } },
    };
}

sub doubleClickHandlerJS
{
    my ($self, $type, $id) = @_;

    $self->actionHandlerJS('edit', $type, $id);
}

# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::Base::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->parentModule()->configured();
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::Model::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __('You must enable the module Users in the module status section in order to use it.');
}

1;
