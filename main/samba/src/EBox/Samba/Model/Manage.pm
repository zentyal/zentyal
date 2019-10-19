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

package EBox::Samba::Model::Manage;

use base 'EBox::Model::TreeView';

use EBox::Gettext;
use EBox::Samba;
use EBox::Types::Action;
use Net::LDAP::Util qw( ldap_explode_dn );

use TryCatch;

sub _tree
{
    my ($self) = @_;

    return {
        treeName => 'Manage',
        modelDomain => 'Samba',
        pageTitle => __('Users and Computers'),
        defaultActions => [ 'add', 'delete' ],
        help =>  __('Here you can manage Organizational Units, Users, Groups and Contacts. Also you can see the computers in the domain if using Samba. Please note that multiple OU support is partial, some modules may only work with users and groups in the default Users and Groups OUs.'),
    };
}

sub rootNodes
{
    my ($self) = @_;

    my $usersMod = $self->parentModule();
    my $defaultNamingContext = $usersMod->defaultNamingContext();
    my $temp = [ { id => 'root', printableName => $defaultNamingContext->baseName(), type => 'domain', metadata => { dn => $defaultNamingContext->dn() } } ];
    return  $temp;
}

sub childNodes
{
    my ($self, $parentType, $parentMetadata) = @_;

    my $usersMod = $self->parentModule();

    my $parentObject = undef;
    if ($parentType eq 'domain') {
        $parentObject = $usersMod->defaultNamingContext();
    } elsif ($parentType eq 'computer') {
        # dont look for childs in computers
        return [];
    } elsif ($parentMetadata->{dn} =~ /^OU=Domain Controllers,/i) {
        return $self->_domainControllers();
    } elsif ($parentMetadata->{dn} =~ /^CN=Computers,/i) {
        # FIXME: Integrate this better with the rest of the logic.
        return $self->_computers();
    } else {
        $parentObject = $usersMod->objectFromDN($parentMetadata->{dn});
    }

    my $printableName = undef;
    my $type = undef;
    my @childNodes = ();
    foreach my $child (@{$parentObject->children()}) {
        next if ($child->isa('EBox::Samba::User'));
        my $dn = $child->dn();
        if ($child->isa('EBox::Samba::OU')) {
            $type = 'ou';
            $printableName = $child->name();
            next if ($self->_hiddenOU($child->dn()));
        } elsif ($child->isa('EBox::Samba::Container')) {
            $type = 'container';
            $printableName = $child->name();
            next if ($self->_hiddenContainer($child->dn()));
        } elsif ($child->isa('EBox::Samba::User')) {
            next if ($child->isInternal());

            if ($child->isDisabled()) {
                $type = 'duser';
            } else {
                $type = 'user';
            }
            $printableName = $child->name();

            # FIXME: temporary workaround until the regression is fixed properly
            use Sys::Hostname;
            my $hostname = Sys::Hostname::hostname();
            next if ($printableName =~ /^(\w+)-$hostname$/);

            my $displayname = $child->displayName();
            if ($displayname) {
                $printableName .= " ($displayname)";
            }
        } elsif ($child->isa('EBox::Samba::Contact')) {
            $type = 'contact';
            $printableName = $child->displayName();
            unless ($printableName) {
                $printableName = $child->fullname();
            }
        } elsif ($child->isa('EBox::Samba::Group')) {
            next if ($child->isInternal());

            $type = $child->isSecurityGroup() ? 'group' : 'dgroup';
            $printableName = $child->name();
        } else {
            EBox::warn("Unknown object type for DN: " . $child->dn());
            next;
        }
        push (@childNodes, { id => $dn, printableName => $printableName, type => $type, metadata => { dn => $dn } });
    }

    return \@childNodes;
}

sub _domainControllers
{
    my ($self) = @_;

    my @computers;
    foreach my $computer (@{$self->parentModule()->domainControllers()}) {
        my $dn = $computer->dn();
        my $printableName = $computer->name();
        push (@computers, { id => $dn, printableName => $printableName, type => 'computer', metadata => { dn => $dn } });
    }

    return \@computers;
}

sub _computers
{
    my ($self) = @_;

    my @computers;
    foreach my $computer (@{$self->parentModule()->computers()}) {
        my $dn = $computer->dn();
        my $printableName = $computer->name();
        push (@computers, { id => $dn, printableName => $printableName, type => 'computer', metadata => { dn => $dn } });
    }

    return \@computers;
}

sub nodeTypes
{
    my ($self) = @_;
    my $usersMod = $self->parentModule();
    my $rw = 1;

    return {
        domain => { actions => { filter => 0, add => $rw }, actionObjects => { add => 'OU' } },
        ou => { actions => { filter => 0, add => $rw, delete => $rw, edit => $rw}, actionObjects => { delete => 'OU', add => 'Object' }, defaultIcon => 1 },
        container => { actions => { filter => 0, edit => $rw, add => $rw, delete => $rw }, actionObjects => { delete => 'OU', add => 'Object' }, defaultIcon => 1 },
        user => { printableName => __('Users'), actions => { filter => 1, edit => 1, delete => $rw } },
        duser => { printableName => __('Disabled Users'), actions => { filter => 1, edit => 1, delete => $rw },
                                                          actionObjects => { edit => 'User', delete => 'User' } },
        group => { printableName => __('Security Groups'), actions => { filter => 1, edit => 1, delete => $rw } },
        dgroup => { printableName => __('Distribution Groups'), actions => { filter => 1, edit => 1, delete => $rw },
                                                                actionObjects => { edit => 'Group', delete => 'Group' } },
        computer => { printableName => __('Computers'), actions => { filter => 1 } },
        contact => { printableName => __('Contacts'), actions => { filter => 1, edit => 1, delete => $rw } },
    };
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

    my $samba = $self->parentModule();
    return ($samba->isProvisioned() and $samba->isEnabled());
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

    return __('You need to enable Domain Controller and File Sharing module in the module status section and save changes in order to use it.');
}

sub _hiddenOU
{
    my ($self, $dn) = @_;

    unless ($self->{ousToHide}) {
        $self->{ousToHide} = { map { $_ => 1 } @{$self->parentModule()->ousToHide()} };
    }

    # Only hide first level OUs and allow nested OUs matching hidden ones
    my $dnParts = ldap_explode_dn($dn, reverse => 1);
    my $e = shift @{$dnParts};
    while (@{$dnParts} and not defined $e->{OU}) {
        $e = shift @{$dnParts};
    };
    my $name = $e->{OU};

    return $self->{ousToHide}->{$name};
}

sub _hiddenContainer
{
    my ($self, $dn) = @_;

    unless ($self->{containersToHide}) {
        $self->{containersToHide} = { map { $_ => 1 } ('ForeignSecurityPrincipals', 'Program Data', 'System') };
    }

    # Only hide first level OUs and allow nested OUs matching hidden ones
    my $dnParts = ldap_explode_dn($dn, reverse => 1);
    my $e = shift @{$dnParts};
    while (@{$dnParts} and not defined $e->{CN}) {
        $e = shift @{$dnParts};
    };
    my $name = $e->{CN};

    return $self->{containersToHide}->{$name};
}

sub clickHandlerJS
{
    my ($self, $type) = @_;

    if ($type eq 'container'){
        $self->actionHandlerJS('list', $type);
    }elsif($type eq 'ou'){
        $self->actionHandlerJS('list', 'container');
    }elsif($type eq ''){}else{
        $self->actionHandlerJS('edit', $type);
    }
}

1;
