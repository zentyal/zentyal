# Copyright (C) 2012-2014 Zentyal S.L.
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
);

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::DataExists;

use EBox::Samba::User;

use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Perl6::Junction qw(any);
use TryCatch;

use constant SYSMINGID      => 1900;
use constant MINGID         => 2000;
use constant MAXGROUPLENGTH => 128;
use constant CORE_ATTRS     => ('objectClass', 'mail', 'member', 'description');

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
#   EBox::Samba::Group::mainObjectClass
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
# Named parameters:
#
#       name            - Group name.
#       parent          - Parent container that will hold this new Group.
#       description     - Group's description.
#       mail            - Group's mail.
#       isSecurityGroup - If true it creates a security group, otherwise creates a distribution group. By default true.
#       isSystemGroup   - If true it adds the group as system group, otherwise as normal group.
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
    my $isSystemGroup = $args{isSystemGroup};
    if ((not $isSecurityGroup) and $isSystemGroup) {
        throw EBox::Exceptions::External(
            __x('While creating a new group \'{group}\': A group cannot be a distribution group and a system group at ' .
                'the same time.', group => $args{name}));
    }

    my $dn = 'CN=' . $args{name} . ',' . $args{parent}->dn();

    $class->_checkAccountName($args{name}, MAXGROUPLENGTH);
    $class->_checkAccountNotExists($args{name});

    # TODO: We may want to support more than global groups!
    my $groupType = GROUPTYPEGLOBAL;
    my $gidNumber = $args{gidNumber};
    my $attr = [];
    if ($isSecurityGroup) {
        unless (defined $gidNumber) {
            $gidNumber = $class->_gidForNewGroup($isSystemGroup);
        }
        push (@{$attr}, objectClass => ['top', 'group', 'posixAccount']);
        if ($gidNumber) {
            $class->_checkGid($gidNumber, $isSystemGroup);
            push (@{$attr}, gidNumber => $gidNumber);
        }
        $groupType |= GROUPTYPESECURITY;
    } else {
        push (@{$attr}, objectClass => ['top', 'group']);
    }
    push (@{$attr}, cn => $args{name});
    push (@{$attr}, sAMAccountName => $args{name});
    push (@{$attr}, description    => $args{description}) if ($args{description});
    push (@{$attr}, mail           => $args{mail}) if ($args{mail});

    $groupType = unpack('l', pack('l', $groupType)); # force 32bit integer
    push (@{$attr}, groupType => $groupType);

    # Add the entry
    my $result = $class->_ldap->add($dn, { attrs => $attr });
    my $createdGroup = new EBox::Samba::Group(dn => $dn);

    if ($isSecurityGroup) {
        my ($rid) = $createdGroup->sid() =~ m/-(\d+)$/;
        $gidNumber = $createdGroup->unixId($rid);
        $createdGroup->set('gidNumber', $gidNumber);
        $createdGroup->setupGidMapping($gidNumber);
    }

    # Call modules initialization
    my $usersMod = EBox::Global->modInstance('samba');
    $usersMod->notifyModsLdapUserBase('addGroup', $createdGroup, $createdGroup->{ignoreMods});

    return $createdGroup;
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
#
sub isSecurityGroup
{
    my ($self) = @_;
    if ($self->get('groupType') & GROUPTYPESECURITY) {
        return 1;
    } else {
        return 0;
    }
}

# Method: setSecurityGroup
#
#   Sets/unsets this group as a security group.
#
#
sub setSecurityGroup
{
    my ($self, $isSecurityGroup, $lazy) = @_;
    $isSecurityGroup = $isSecurityGroup ? 1 : 0; # normalize for next
                                                 # comparation
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

sub printableType
{
    return __('group');
}

# Class method: defaultContainer
#
#   Parameters:
#     ro - whether to use the read-only version of the users module
#
#   Return the default container that will hold Group objects.
#
sub defaultContainer
{
    my ($class, $ro) = @_;
    my $ldapMod = $class->_ldapMod();
    return $ldapMod->objectFromDN('cn=Users,' . $class->_ldap->dn());
}

# Method: name
#
#   Return group name
#
sub name
{
    my ($self) = @_;
    return $self->get('cn');
}

sub description
{
    my ($self) = @_;
    return $self->get('description');
}

# Method: mail
#
#   Return group mail
#
sub mail
{
    my ($self) = @_;
    return $self->get('mail');
}

# Method: gidNumber
#
#   This method returns the group's gidNumber, ensuring it is properly set or
#   throwing an exception otherwise
#
sub gidNumber
{
    my ($self) = @_;

    my $gidNumber = $self->get('gidNumber');
    unless ($gidNumber =~ /^[0-9]+$/) {
        throw EBox::Exceptions::External(
            __x('The group {x} has not gidNumber set. Get method ' .
                "returned '{y}'.",
                x => $self->get('samAccountName'),
                y => defined ($gidNumber) ? $gidNumber : 'undef'));
    }

    return $gidNumber;
}

# Method: removeAllMembers
#
#   Remove all members in the group
#
sub removeAllMembers
{
    my ($self, $lazy) = @_;
    $self->delete('member', $lazy);
}

# Method: addMember
#
#   Adds the given person as a member
#
# Parameters:
#
#   member - member object (User, Contact, Group)
#
sub addMember
{
    my ($self, $member, $lazy) = @_;
    try {
        $self->add('member', $member->dn(), $lazy);
    } catch (EBox::Exceptions::LDAP $e) {
        if ($e->errorName() eq 'LDAP_TYPE_OR_VALUE_EXISTS' or
            $e->errorName() eq 'LDAP_ALREADY_EXISTS')
        {
            EBox::debug("Tried to add already existent member " .
                        $member->dn() . " from group " . $self->name());
        } else {
            $e->throw();
        }
    }
}

# Method: removeMember
#
#   Removes the given person as a member
#
# Parameters:
#
#   member - member object (User, Contact, Group)
#
sub removeMember
{
    my ($self, $member, $lazy) = @_;
    try {
        $self->deleteValues('member', [$member->dn()], $lazy);
    } catch (EBox::Exceptions::LDAP $e) {
        if ($e->errorName() eq 'LDAP_UNWILLING_TO_PERFORM') {
            # This happens when trying to remove a non-existant member
            throw EBox::Exceptions::External(
                __x('The server is unwilling to perform the requested ' .
                    'operation'));
        } else {
            $e->throw();
        }
    }
}

# Method: users
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members (EBox::Samba::User)
#
sub users
{
    my ($self, $system) = @_;

    $self->_users($system);
}

# Method: usersNotIn
#
#   Users that don't belong to this group
#
#   Returns:
#
#       array ref of EBox::Samba::Group objects
#
sub usersNotIn
{
    my ($self, $system) = @_;

    $self->_users($system, 1);
}

sub _users
{
    my ($self, $system, $invert) = @_;

    my $ldapMod = $self->_ldapMod();
    my $userClass = $ldapMod->userClass();

    my @users;

    if ($invert) {
        my %searchParams = (
                base => $self->_ldap->dn(),
                filter => "(&(objectclass=" . $userClass->mainObjectClass()  . ")(!(memberof=$self->{dn})))",
                scope => 'sub',
        );
        my $result = $self->_ldap->search(\%searchParams);

        @users = map { $userClass->new(entry => $_) } $result->entries();
    } else {
        my @members = $self->get('member');
        @users = map { $userClass->new(dn => $_) } @members;
    }

    my @filteredUsers;
    foreach my $user (@users) {
        next if ($user->isInternal());

        push (@filteredUsers, $user) if (not $user->isSystem());
    }

    # sort by uid
    @filteredUsers = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @filteredUsers;

    return \@filteredUsers;
}

# Method: contacts
#
#   Return the list of contacts for this group
#
# Returns:
#
#   arrary ref of contacts (EBox::Samba::Contact)
#
sub contacts
{
    my ($self) = @_;

    my %attrs = (
        base => $self->_ldap->dn(),
        filter => "(&(&(!(objectclass=posixAccount))(memberof=$self->{dn})(objectclass=inetorgPerson)))",
        scope => 'sub',
    );

    my $result = $self->_ldap->search(\%attrs);

    my @contacts = map {
        EBox::Samba::Contact->new(entry => $_)
    } $result->entries();

    # sort by fullname
    @contacts = sort {
            my $aValue = $a->fullname();
            my $bValue = $b->fullname();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @contacts;

    return \@contacts;
}

# Method: contactsNotIn
#
#   Contacts that don't belong to this group
#
#   Returns:
#
#       array ref of EBox::Samba::Contact objects
#
sub contactsNotIn
{
    my ($self) = @_;

    my %attrs = (
            base => $self->_ldap->dn(),
            filter => "(&(&(!(objectclass=posixAccount))(!(memberof=$self->{dn}))(objectclass=inetorgPerson)))",
            scope => 'sub',
            );

    my $result = $self->_ldap->search(\%attrs);

    my @contacts = map {
        EBox::Samba::Contact->new(entry => $_)
    } $result->entries();

    @contacts = sort {
            my $aValue = $a->fullname();
            my $bValue = $b->fullname();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @contacts;

    return \@contacts;
}

# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(CORE_ATTRS)) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::set(@_);
}

sub add
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(CORE_ATTRS)) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::add(@_);
}

sub delete
{
    my ($self, $attr, $lazy) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(CORE_ATTRS)) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::delete(@_);
}

sub deleteValues
{
    my ($self, $attr, $values, $lazy) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any(CORE_ATTRS)) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::deleteValues(@_);
}

# Method: deleteObject
#
#   Delete the group
#
sub deleteObject
{
    my ($self) = @_;

    # Notify group deletion to modules
    my $usersMod = $self->_usersMod();
    $usersMod->notifyModsLdapUserBase('delGroup', $self, $self->{ignoreMods});

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

sub save
{
    my ($self) = @_;

    shift @_;
    $self->SUPER::save(@_);

    if ($self->{core_changed}) {
        delete $self->{core_changed};

        my $usersMod = $self->_usersMod();
        $usersMod->notifyModsLdapUserBase('modifyGroup', [$self], $self->{ignoreMods});
    }
}

sub _checkGroupName
{
    my ($name)= @_;
    if (not EBox::Samba::checkNameLimitations($name)) {
        return undef;
    }

    # windows group names could not be only numbers, spaces and dots
    if ($name =~ m/^[[:space:]0-9\.]+$/) {
        return undef;
    }

    return 1;
}

# Method: isSystem
#
#   Whether the security group is a system group.
#
sub isSystem
{
    my ($self) = @_;

    if ($self->isSecurityGroup()) {
        my $gidNumber = $self->get('gidNumber');
        if (defined $gidNumber) {
            return ($gidNumber < MINGID);
        }
        return 1;
    } else {
        # System groups are only valid with security groups.
        return undef;
    }
}

sub _gidForNewGroup
{
    my ($class, $system) = @_;

    my $gid;
    if ($system) {
        $gid = $class->lastGid(1) + 1;
        if ($gid == MINGID) {
            throw EBox::Exceptions::Internal(
                __('Maximum number of groups reached'));
        }
    } # else it is undef until objectSID is generated

    return $gid;
}

# Method: lastGid
#
#       Returns the last gid used.
#
# Parameters:
#
#       system - boolean: if true, it returns the last gid for system groups,
#       otherwise the last gid for normal groups
#
# Returns:
#
#       string - last GID
#
sub lastGid
{
    my ($class, $system) = @_;

    my $lastGid = -1;
    my $usersMod = EBox::Global->modInstance('samba');
    foreach my $group (@{$usersMod->securityGroups($system)}) {
        my $gid = $group->get('gidNumber');
        if ($system) {
            last if ($gid >= MINGID);
        } else {
            next if ($gid < MINGID);
        }
        if ($gid > $lastGid) {
            $lastGid = $gid;
        }
    }
    if ($system) {
        return ($lastGid < SYSMINGID ? SYSMINGID : $lastGid);
    } else {
        return ($lastGid < MINGID ? MINGID : $lastGid);
    }
}

sub isInternal
{
    my ($self) = @_;

    # FIXME: whitelist Domain Admins and Schema Admins, do this better removing
    #        isCriticalSystemObject check
    my $sid = $self->sid();
    if ($sid =~ /^S-1-5-21-\d+-\d+-\d+-512$/) { # Domain Admins
        return 0;
    } elsif ($sid =~ /^S-1-5-21-\d+-\d+-\d+-518$/) { # Schema Admins
        return 0;
    }

    return ($self->isInAdvancedViewOnly() or $self->get('isCriticalSystemObject'));
}

sub setInternal
{
    my ($self, $internal, $lazy) = @_;

    $self->setInAdvancedViewOnly($internal, $lazy);
}

sub _checkGid
{
    my ($self, $gid, $system) = @_;

    if ($gid < MINGID) {
        if (not $system) {
            throw EBox::Exceptions::External(
                __x('Incorrect GID {gid} for a group . GID must be equal or greater than {min}',
                    gid => $gid,
                    min => MINGID,
                )
            );
        }
    } elsif ($system) {
        throw EBox::Exceptions::External(
            __x('Incorrect GID {gid} for a system group . GID must be lesser than {max}',
                gid => $gid,
                max => MINGID,
            )
        );
    }
}

1;
