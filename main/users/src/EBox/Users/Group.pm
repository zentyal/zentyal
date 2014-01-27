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

# Class: EBox::Users::Group
#
#   Zentyal group, stored in LDAP
#
package EBox::Users::Group;

use base 'EBox::Users::LdapObject';

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Users;
use EBox::Users::User;
use EBox::Validate;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;

use TryCatch::Lite;
use Perl6::Junction qw(any);
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use constant SYSMINGID      => 1900;
use constant MINGID         => 2000;
use constant MAXGROUPLENGTH => 128;
use constant CORE_ATTRS     => ('objectClass', 'mail', 'member', 'description');

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    if (defined $opts{gid}) {
        $self->{gid} = $opts{gid};
    } else {
        $self = $class->SUPER::new(@_);
    }

    bless ($self, $class);
    return $self;
}

# Method: mainObjectClass
#
#  Returns:
#     object class name which will be used to discriminate groups
sub mainObjectClass
{
    return 'zentyalDistributionGroup';
}

sub printableType
{
    return __('group');
}

# Class method: defaultContainer
#
#   Parameters:
#     ro - wether to use the read-only version of the users module
#
#   Return the default container that will hold Group objects.
#
sub defaultContainer
{
    my ($class, $ro) = @_;
    my $ldapMod = $class->_ldapMod();
    return $ldapMod->objectFromDN('ou=Groups,' . $class->_ldap->dn());
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the group
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        if (defined $self->{gid}) {
            my $result = undef;
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(cn=$self->{gid})",
                scope => 'sub',
            };
            $result = $self->_ldap->search($attrs);
            if ($result->count() > 1) {
                throw EBox::Exceptions::Internal(
                    __x('Found {count} results for, expected only one.',
                        count => $result->count()));
            }
            $self->{entry} = $result->entry(0);
        } else {
            $self->SUPER::_entry();
        }
    }
    return $self->{entry};
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
        if ($e->errorName ne 'LDAP_TYPE_OR_VALUE_EXISTS') {
            $e->throw();
        }
        EBox::debug("Tried to add already existent member " . $member->dn() . " from group " . $self->name());
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
    $self->deleteValues('member', [$member->dn()], $lazy);
}

# Method: members
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members
#
sub members
{
    my ($self) = @_;

    my $ldapMod = $self->_ldapMod();
    my @members = ();
    for my $memberDN ($self->get('member')) {
        my $member = $ldapMod->objectFromDN($memberDN);
        if ($member and $member->exists()) {
            push (@members, $member);
        }
    }

    @members = sort {
        my $aValue = $a->canonicalName();
        my $bValue = $b->canonicalName();
        (lc $aValue cmp lc $bValue) or ($aValue cmp $bValue)
    } @members;

    return \@members;
}


# Method: users
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members (EBox::Users::User)
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
#       array ref of EBox::Users::Group objects
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
#   arrary ref of contacts (EBox::Users::Contact)
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
        EBox::Users::Contact->new(entry => $_)
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
#       array ref of EBox::Users::Contact objects
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
        EBox::Users::Contact->new(entry => $_)
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
    $usersMod->notifyModsLdapUserBase('delGroup', $self, $self->{ignoreMods}, $self->{ignoreSlaves});

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
        $usersMod->notifyModsLdapUserBase('modifyGroup', [$self], $self->{ignoreMods}, $self->{ignoreSlaves});
    }
}

# GROUP CREATION METHODS

# Method: create
#
#   Adds a new group.
#
# Parameters:
#
#   args - Named parameters:
#       name            - Group name.
#       parent          - Parent container that will hold this new Group.
#       description     - Group's description.
#       mail            - Group's mail
#       isSecurityGroup - If true it creates a security group, otherwise creates a distribution group. By default true.
#       isSystemGroup   - If true it adds the group as system group, otherwise as normal group.
#       gidNumber       - The gid number to use for this group. If not defined it will auto assigned by the system.
#       ignoreMods      - Ldap modules to be ignored on addUser notify.
#       ignoreSlaves    - Slaves to be ignored on addUser notify.
#       isInternal      - Whether the group should be hidden or not.
#
# Exceptions:
#
#       TBD the remainder exceptions
#       <EBox::Exceptions::InvalidData> - thrown if the provided mail is incorrect
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('name') unless ($args{name});
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $name = $args{name};
    my $parent = $args{parent};
    my $isSecurityGroup = 1;
    if (defined $args{isSecurityGroup}) {
        $isSecurityGroup = $args{isSecurityGroup};
    }
    my $isSystemGroup = $args{isSystemGroup};
    if ((not $isSecurityGroup) and $isSystemGroup) {
        throw EBox::Exceptions::External(
            __x('While creating a new group \'{group}\': A group cannot be a distribution group and a system group at ' .
                'the same time.', group => $name));
    }
    my $isInternal = 0;
    if (defined $args{isInternal}) {
        $isInternal = $args{isInternal};
    }
    my $ignoreMods   = $args{ignoreMods};
    my $ignoreSlaves = $args{ignoreSlaves};

    if (length ($name) > MAXGROUPLENGTH) {
        throw EBox::Exceptions::External(
            __x("Groupname must not be longer than {maxGroupLength} characters", maxGroupLength => MAXGROUPLENGTH));
    }

    unless (_checkGroupName($name)) {
        my $advice = __('To avoid problems, the group name should consist ' .
                        'only of letters, digits, underscores, spaces, ' .
                        'periods, dashs and not start with a dash. They ' .
                        'could not contain only number, spaces and dots.');
        throw EBox::Exceptions::InvalidData(
            'data' => __('group name'),
            'value' => $name,
            'advice' => $advice
           );
    }
    my $usersMod = EBox::Global->modInstance('users');

    # Verify group exists
    my $groupExists = $usersMod->groupExists($name);
    if ($groupExists and ($groupExists == EBox::Users::OBJECT_EXISTS_AND_HIDDEN_SID())) {
        throw EBox::Exceptions::DataExists( text =>
                                                __x('The group {name} already exists as built-in Windows group',
                                                    name => $name));
    } elsif ($groupExists) {
        throw EBox::Exceptions::DataExists(
            'data' => __('group'),
            'value' => $name);
    }

    # Verify that a user with the same name does not exists
    my $userExists = $usersMod->userExists($name);
    if ($userExists and ($userExists == EBox::Users::OBJECT_EXISTS_AND_HIDDEN_SID())) {
        throw EBox::Exceptions::External(
            __x(q{A built-in Windows user with the name '{name}' already exists. Users and groups cannot share names},
               name => $name)
           );
    } elsif ($userExists) {
        throw EBox::Exceptions::External(
            __x(q{A user account with the name '{name}' already exists. Users and groups cannot share names},
               name => $name)
           );
    }

    $class->checkCN($parent, $name);

    my $dn = 'cn=' . $name . ',' . $parent->dn();

    my @attr = (
        'cn'          => $name,
        'objectclass' => ['zentyalDistributionGroup'],
    );

    if ($isSecurityGroup) {
        my $gid = defined $args{gidNumber} ? $args{gidNumber}: $class->_gidForNewGroup($isSystemGroup);
        $class->_checkGid($gid, $isSystemGroup);
        push (@attr, objectclass => 'posixGroup');
        push (@attr, gidNumber => $gid);
    }
    if ($isInternal) {
        push (@attr, internal => 1);
    }
    push (@attr, 'description' => $args{description}) if (defined $args{description} and $args{description});
    if (defined $args{mail} and $args{mail}) {
        EBox::Validate::checkEmailAddress($args{mail}, __('E-mail'));
        push (@attr, 'mail' => $args{mail});
    }

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attr);
        $usersMod->notifyModsPreLdapUserBase(
            'preAddGroup', [$entry, $parent], $ignoreMods, $ignoreSlaves);

        my $changetype =  $entry->changetype();
        my $changes = [$entry->changes()];
        my $result = $entry->update($class->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on group LDAP entry creation:'),
                    result => $result,
                    opArgs   => $class->entryOpChangesInUpdate($entry),
                   );
            }
        }

        $res = new EBox::Users::Group(dn => $dn);
        unless ($isSystemGroup) {
            $usersMod->reloadNSCD();

            # Call modules initialization
            $usersMod->notifyModsLdapUserBase('addGroup', $res, $ignoreMods, $ignoreSlaves);
        }
    } catch ($error) {
        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if ($res and $res->exists()) {
            $usersMod->notifyModsLdapUserBase('addGroupFailed', [ $res ], $ignoreMods, $ignoreSlaves);
            $res->SUPER::deleteObject(@_);
        } else {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddGroupFailed', [$entry, $parent], $ignoreMods, $ignoreSlaves);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    }

    return $res;
}

sub _checkGroupName
{
    my ($name)= @_;
    if (not EBox::Users::checkNameLimitations($name)) {
        return undef;
    }

    # windows group names could not be only numbers, spaces and dots
    if ($name =~ m/^[[:space:]0-9\.]+$/) {
        return undef;
    }

    return 1;
}

# Method: isSecurityGroup
#
#   Whether is a security group or just a distribution group.
#
sub isSecurityGroup
{
    my ($self) = @_;

    my $ldap = $self->_usersMod()->ldap();

    return ('posixGroup' eq any(@{$ldap->objectClasses($self->dn())}));
}

# Method: setSecurityGroup
#
#   Sets/unsets this group as a security group.
#
#
sub setSecurityGroup
{
    my ($self, $isSecurityGroup, $lazy) = @_;

    if (not ($isSecurityGroup xor $self->isSecurityGroup())) {
        # Do nothing if the new status matches current status.
        return;
    }

    if ($isSecurityGroup) {
        unless (defined $self->get('gidNumber')) {
            my $gid = $self->_gidForNewGroup();
            $self->_checkGid($gid);
            $self->set('gidNumber', $gid, $lazy);
        }
        $self->add('objectClass', 'posixGroup', $lazy);
    } else {
        $self->deleteValues('objectClass', ['posixGroup'], $lazy);
    }
}

# Method: isSystem
#
#   Whether the security group is a system group.
#
sub isSystem
{
    my ($self) = @_;

    if ($self->isSecurityGroup()) {
        return ($self->get('gidNumber') < MINGID);
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
    } else {
        $gid = $class->lastGid + 1;
    }

    return $gid;
}

# Method: lastGid
#
#       Returns the last gid used.
#
# Parameters:
#
#       system - boolan: if true, it returns the last gid for system groups,
#       otherwise the last gid for normal groups
#
# Returns:
#
#       string - last gid
#
sub lastGid
{
    my ($class, $system) = @_;

    my $lastGid = -1;
    my $usersMod = EBox::Global->modInstance('users');
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

    return $self->get('internal');
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
