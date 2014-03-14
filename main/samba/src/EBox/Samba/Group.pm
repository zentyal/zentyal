# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::Samba::Group
#
#   Samba group, stored in samba LDB
#
package EBox::Samba::Group;

use base qw(
    EBox::Samba::SecurityPrincipal
    EBox::Users::Group
);

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

use EBox::Users::User;
use EBox::Users::Group;

use EBox::Samba::Contact;

use Perl6::Junction qw(any);
use TryCatch::Lite;

use constant MAXGROUPLENGTH     => 128;
use constant GROUPTYPESYSTEM    => 0x00000001;
use constant GROUPTYPEGLOBAL    => 0x00000002;
use constant GROUPTYPELOCAL     => 0x00000004;
use constant GROUPTYPEUNIVERSAL => 0x00000008;
use constant GROUPTYPEAPPBASIC  => 0x00000010;
use constant GROUPTYPEAPPQUERY  => 0x00000020;
use constant GROUPTYPESECURITY  => 0x80000000;

sub new
{
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);
    bless ($self, $class);
    return $self;
}

# Method: mainObjectClass
#
# Override:
#   EBox::Users::Group::mainObjectClass
#
sub mainObjectClass
{
    return 'group';
}

sub setupGidMapping
{
    my ($self, $gidNumber) = @_;

    my $type = $self->_ldap->idmap->TYPE_GID();
    $self->_ldap->idmap->setupNameMapping($self->sid(), $type, $gidNumber);
}

# Method: create
#
#   Adds a new Samba group.
#
# Parameters:
#
#   args - Named parameters:
#       name            - Group name.
#       parent          - Parent container that will hold this new Group.
#       description     - Group's description.
#       mail            - Group's mail.
#       isSecurityGroup - If true it creates a security group, otherwise creates a distribution group. By default true.
#       gidNumber       - The gid number to use for this group. If not defined it will auto assigned by the system.
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('name') unless ($args{name});
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $isSecurityGroup = 1;
    if (defined $args{isSecurityGroup}) {
        $isSecurityGroup = $args{isSecurityGroup};
    }

    my $dn = 'CN=' . $args{name} . ',' . $args{parent}->dn();

    $class->_checkAccountName($args{name}, MAXGROUPLENGTH);
    $class->_checkAccountNotExists($args{name});

    # TODO: We may want to support more than global groups!
    my $groupType = GROUPTYPEGLOBAL;
    my $attr = [];
    push ($attr, cn => $args{name});
    push ($attr, objectClass    => ['top', 'group']);
    push ($attr, sAMAccountName => $args{name});
    push ($attr, description    => $args{description}) if ($args{description});
    push ($attr, mail           => $args{mail}) if ($args{mail});
    if ($isSecurityGroup) {
        $groupType |= GROUPTYPESECURITY;
    }

    $groupType = unpack('l', pack('l', $groupType)); # force 32bit integer
    push ($attr, groupType => $groupType);

    # Add the entry
    my $result = $class->_ldap->add($dn, { attrs => $attr });
    my $createdGroup = new EBox::Samba::Group(dn => $dn);

    if (defined $args{gidNumber}) {
        $createdGroup->setupGidMapping($args{gidNumber});
    }

    return $createdGroup;
}

sub addToZentyal
{
    my ($self) = @_;

    my $sambaMod = EBox::Global->modInstance('samba');

    my $parent = undef;
    my $domainSID = $sambaMod->ldb()->domainSID();
    my $domainUsersSID = "$domainSID-513";
    my $domainAdminsSID = "$domainSID-512";
    if ($domainAdminsSID eq $self->sid()) {
        # TODO: We must stop moving this Samba group from the Users container to the legacy's Group OU in Zentyal.
        $parent = EBox::Users::Group->defaultContainer();
    } else {
        $parent = $sambaMod->ldapObjectFromLDBObject($self->parent);
    }

    if (not $parent) {
        my $dn = $self->dn();
        throw EBox::Exceptions::External("Unable to to find the container for '$dn' in OpenLDAP");
    }
    my $parentDN = $parent->dn();

    my $name = $self->get('samAccountName');

    my $zentyalGroup = undef;

    if ($domainUsersSID eq $self->sid()) {
        my $usersMod = EBox::Global->modInstance('users');
        my $usersName = $usersMod->DEFAULTGROUP();

        $zentyalGroup = new EBox::Users::Group(gid => $usersName);
        if ($zentyalGroup->exists()) {
            # Link both objects.
            $self->_linkWithUsersObject($zentyalGroup);
            # Update its fields.
            $self->updateZentyal();
            return;
        } else {
            # There is no __USERS__ group in Zentyal, this should not happen, but just in case is just a matter of
            # create this group with the __USERS__ name.
            $zentyalGroup = undef;
            $name = $usersName;
        }
    }

    EBox::info("Adding samba group '$name' to Zentyal");
    try {
        my @params = (
            name => scalar($name),
            parent => $parent,
            isSecurityGroup => $self->isSecurityGroup(),
            ignoreMods  => ['samba'],
        );

        my $description = $self->description();
        push (@params, description =>  $description) if ($description);
        my $mail = $self->mail();
        push (@params, mail =>  $mail) if ($mail);

        if ($self->isSecurityGroup()) {
            my $gidNumber = $self->xidNumber();
            unless (defined $gidNumber) {
                throw EBox::Exceptions::Internal("Could not get gidNumber for group $name");
            }
            push (@params, gidNumber => $gidNumber);
            push (@params, isSystemGroup => ($gidNumber < EBox::Users::Group->MINGID()));
            EBox::debug("Replicating a security group into OpenLDAP with gidNumber = $gidNumber");
        }

        if ($self->isInAdvancedViewOnly() or $sambaMod->hiddenSid($self)) {
            push (@params, isInternal => 1);
        }

        $zentyalGroup = EBox::Users::Group->create(@params);
        $self->_linkWithUsersObject($zentyalGroup);
    } catch (EBox::Exceptions::DataExists $e) {
        EBox::debug("Group $name already in Zentyal database");
        $zentyalGroup = $sambaMod->ldapObjectFromLDBObject($self);
        unless ($zentyalGroup) {
            EBox::error("The group $name exists in Zentyal but is not linked with Samba!");
        }
    } catch ($error) {
        EBox::error("Error loading group '$name': $error");
    }

    if ($zentyalGroup and $zentyalGroup->exists()) {
        $self->_membersToZentyal($zentyalGroup);
    }
}

sub updateZentyal
{
    my ($self) = @_;

    my $sambaMod = EBox::Global->modInstance('samba');
    my $zentyalGroup = $sambaMod->ldapObjectFromLDBObject($self);
    my $gid = $self->get('samAccountName');
    EBox::info("Updating zentyal group '$gid'");

    $zentyalGroup->setIgnoredModules(['samba']);
    if ($self->isSecurityGroup()) {
        unless ($zentyalGroup->isSecurityGroup()) {
            $zentyalGroup->setSecurityGroup(1, 1);
            my $gidNumber = $self->xidNumber();
            unless (defined $gidNumber) {
                throw EBox::Exceptions::Internal("Could not get gidNumber for group " . $zentyalGroup->name());
            }
            $zentyalGroup->set('gidNumber', $gidNumber, 1);
        }
    } elsif ($zentyalGroup->isSecurityGroup()) {
        $zentyalGroup->setSecurityGroup(0, 1);
    }
    my $description = $self->get('description');
    if ($description) {
        $zentyalGroup->set('description', $description, 1);
    } else {
        $zentyalGroup->delete('description', 1);
    }
    my $mail = $self->get('mail');
    if ($mail) {
        $zentyalGroup->set('mail', $mail, 1);
    } else {
        $zentyalGroup->delete('mail', 1);
    }
    $zentyalGroup->save();

    $self->_membersToZentyal($zentyalGroup);
}

sub _membersToZentyal
{
    my ($self, $zentyalGroup) = @_;

    return unless ($zentyalGroup and $zentyalGroup->exists());

    my $sambaMod = $self->_sambaMod();
    my $domainSID = $sambaMod->ldb()->domainSID();
    my $domainUsersSID = "$domainSID-513";

    if ($domainUsersSID eq $self->sid()) {
        # Domain Users group is handled automatically by Samba, no need to sync the members
        EBox::debug("Ignored the syncronization between 'Domain Users' and '__USERS__'");
        return;
    }

    my $gid = $self->get('samAccountName');
    my $sambaMembersList = $self->members();
    my $zentyalMembersList = $zentyalGroup->members();

    my %zentyalMembers = map { $_->get('msdsObjectGUID') => $_ } @{$zentyalMembersList};
    my %sambaMembers;
    foreach my $sambaMember (@{$sambaMembersList}) {
        if ($sambaMember->isa('EBox::Samba::User') or
            $sambaMember->isa('EBox::Samba::Contact') or
            $sambaMember->isa('EBox::Samba::Group')) {
            my $uniqueID = $sambaMember->objectGUID();
            $sambaMembers{$uniqueID} = $sambaMember;
            next;
        }
        my $dn = $sambaMember->dn();
        EBox::error("Unexpected member type ($dn)");
    }

    foreach my $memberUniqueID (keys %zentyalMembers) {
        my $canonicalName = $zentyalMembers{$memberUniqueID}->canonicalName(1);
        unless (exists $sambaMembers{$memberUniqueID}) {
            EBox::info("Removing member '$canonicalName' from Zentyal group '$gid'");
            try {
                $zentyalGroup->removeMember($zentyalMembers{$memberUniqueID}, 1);
            } catch ($error) {
                EBox::error("Error removing member '$canonicalName' from Zentyal group '$gid': $error");
            }
         }
    }

    foreach my $memberUniqueID (keys %sambaMembers) {
        my $canonicalName = $sambaMembers{$memberUniqueID}->canonicalName(1);
        unless (exists $zentyalMembers{$memberUniqueID}) {
            EBox::info("Adding member '$canonicalName' to Zentyal group '$gid'");
            my $zentyalMember = $sambaMod->ldapObjectFromLDBObject($sambaMembers{$memberUniqueID});
            unless ($zentyalMember and $zentyalMember->exists()) {
                if ($sambaMembers{$memberUniqueID}->isa('EBox::Samba::Group')) {
                    # The group is not yet syncronized, we force its sync now to retry...
                    $sambaMembers{$memberUniqueID}->addToZentyal();
                    $zentyalMember = $sambaMod->ldapObjectFromLDBObject($sambaMembers{$memberUniqueID});
                    unless ($zentyalMember and $zentyalMember->exists()) {
                        EBox::error("Cannot add member '$canonicalName' to group '$gid' because the member does not exist");
                        next;
                    }
                } elsif ($sambaMembers{$memberUniqueID}->isa('EBox::Samba::User') or
                         $sambaMembers{$memberUniqueID}->isa('EBox::Samba::Contact')) {
                    EBox::warn("Cannot add member '$canonicalName' to Zentyal group '$gid' because the member does not exist");
                    next;
                } else {
                    EBox::error("Cannot add member '$canonicalName' to Zentyal group '$gid' because it's not a known object.");
                    next;
                }
            }
            try {
                $zentyalGroup->addMember($zentyalMember, 1);
            } catch ($error) {
                EBox::error("Error adding member '$canonicalName' to Zentyal group '$gid': $error");
            }
        }
    }

    $zentyalGroup->setIgnoredModules(['samba']);
    $zentyalGroup->save();
}

sub _checkAccountName
{
    my ($self, $name, $maxLength) = @_;
    $self->SUPER::_checkAccountName($name, $maxLength);
    if ($name =~ m/^[[:space:]0-9\.]+$/) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('account name'),
                'value' => $name,
                'advice' =>  __('Windows group names cannot be only spaces, numbers and dots'),
           );
    }
}

# Method: isSecurityGroup
#
#   Whether is a security group or just a distribution group.
#
# Override:
#   EBox::Users::Group::isSecurityGroup
#
sub isSecurityGroup
{
    my ($self) = @_;

    return 1 if ($self->get('groupType') & GROUPTYPESECURITY);
}

# Method: setSecurityGroup
#
#   Sets/unsets this group as a security group.
#
# Override:
#   EBox::Users::Group::setSecurityGroup
#
sub setSecurityGroup
{
    my ($self, $isSecurityGroup, $lazy) = @_;

    return if ($self->isSecurityGroup() == $isSecurityGroup);

    # We do this so we are able to use the groupType value as a 32bit number.
    my $groupType = ($self->get('groupType') & 0xFFFFFFFF);

    if ($isSecurityGroup) {
        $groupType |= GROUPTYPESECURITY;
    } else {
        $groupType &= ~GROUPTYPESECURITY;
    }

    $self->set('groupType', $groupType, $lazy);
}

1;
