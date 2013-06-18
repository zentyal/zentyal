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

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;

use Error qw(:try);
use Perl6::Junction qw(any);
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use List::MoreUtils 'any';

use constant SYSMINGID      => 1900;
use constant MINGID         => 2000;
use constant MAXGROUPLENGTH => 128;
use constant CORE_ATTRS     => ('member', 'description');

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
#   person - inetOrgPerson object
#
sub addMember
{
    my ($self, $person, $lazy) = @_;
    try {
        $self->add('member', $person->dn(), $lazy);
    } catch EBox::Exceptions::LDAP with {
        my $ex = shift;
        if ($ex->errorName ne 'LDAP_TYPE_OR_VALUE_EXISTS') {
            $ex->throw();
        }
        EBox::debug("Tried to add already existent member $person to group " . $self->name());
    };
}

# Method: removeMember
#
#   Removes the given person as a member
#
# Parameters:
#
#   person - inetOrgPerson object
#
sub removeMember
{
    my ($self, $person, $lazy) = @_;
    try {
        $self->deleteValues('member', [$person->dn()], $lazy);
    } catch EBox::Exceptions::LDAP with {
        my $ex = shift;
        if ($ex->errorName ne 'LDAP_TYPE_OR_VALUE_EXISTS') {
            $ex->throw();
        }
        EBox::debug("Tried to remove inexistent member $person to group " . $self->name());
    };
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

    my @members = $self->get('member');
    @members = map { new EBox::Users::User(dn => $_) } @members;

    unless ($system) {
        @members = grep { not $_->isSystemGroup() } @members;
    }
    # sort by uid
    @members = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @members;

    return \@members;
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

    my %attrs = (
            base => $self->_ldap->dn(),
            filter => "(&(objectclass=posixAccount)(!(memberof=$self->{dn})))",
            scope => 'sub',
            );

    my $result = $self->_ldap->search(\%attrs);

    my @users = map {
            EBox::Users::User->new(entry => $_)
        } $result->entries();

    unless ($system) {
        @users = grep { not $_->isSystemGroup() } @users;
    }

    @users = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @users;

    return \@users;
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
        filter => "(&(!(objectclass=posixAccount))(memberof=$self->{dn}))",
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

# Method: members
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members (EBox::Users::InetOrgPerson)
#
sub members
{
    my ($self) = @_;

    my %attrs = (
        base => $self->_ldap->dn(),
        filter => "(memberof=$self->{dn})",
        scope => 'sub',
    );

    my $result = $self->_ldap->search(\%attrs);

    my @members = map {
        EBox::Users::InetOrgPerson->new(entry => $_)
    } $result->entries();

    # sort by fullname
    @members = sort {
            my $aValue = $a->fullname();
            my $bValue = $b->fullname();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @members;

    return \@members;
}

# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::set(@_);
}

sub add
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::add(@_);
}

sub delete
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::delete(@_);
}

sub deleteValues
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
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
    my $users = EBox::Global->modInstance('users');
    $users->notifyModsLdapUserBase('delGroup', $self, $self->{ignoreMods}, $self->{ignoreSlaves});

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

sub save
{
    my ($self, $ignore_mods) = @_;

    shift @_;
    $self->SUPER::save(@_);

    if ($self->{core_changed}) {
        delete $self->{core_changed};

        my $users = EBox::Global->modInstance('users');
        $users->notifyModsLdapUserBase('modifyGroup', [$self], $self->{ignoreMods}, $self->{ignoreSlaves});
    }
}

# Method: setIgnoredModules
#
#   Set the modules that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining module names
#
sub setIgnoredModules
{
    my ($self, $mods) = @_;

    if (defined $mods) {
        $self->{ignoreMods} = $mods;
    }
}

# Method: setIgnoredSlaves
#
#   Set the slaves that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining slave names
#
sub setIgnoredSlaves
{
    my ($self, $slaves) = @_;
    $self->{ignoreSlaves} = $slaves;
}

# GROUP CREATION METHODS

# Method: create
#
#       Adds a new group
#
# Parameters:
#
#   group - group name
#   comment - comment's group
#   system - boolan: if true it adds the group as system group,
#   otherwise as normal group
#   security - boolean: if true it creates a security group, otherwise creates a distribution group. Default is true.
#   ignoreMods - ldap modules to be ignored on addUser notify
#   ignoreSlaves - slaves to be ignored on addUser notify
#
sub create
{
    my ($self, $group, $comment, $system, %params) = @_;

    if (!$params{security} && $system) {
        throw EBox::Exceptions::External(
            __('A group cannot be a distribution group and a system group at the same time.'));
    }

    my $users = EBox::Global->modInstance('users');
    my $dn = $users->groupDn($group);

    if (length ($group) > MAXGROUPLENGTH) {
        throw EBox::Exceptions::External(
            __x("Groupname must not be longer than {maxGroupLength} characters",
                maxGroupLength => MAXGROUPLENGTH));
    }

    unless (_checkGroupName($group)) {
        my $advice = __('To avoid problems, the group name should consist ' .
                        'only of letters, digits, underscores, spaces, ' .
                        'periods, dashs and not start with a dash. They ' .
                        'could not contain only number, spaces and dots.');
        throw EBox::Exceptions::InvalidData(
            'data' => __('group name'),
            'value' => $group,
            'advice' => $advice
           );
    }

    # Verify group exists
    if (new EBox::Users::Group(dn => $dn)->exists()) {
        throw EBox::Exceptions::DataExists(
            'data' => __('group'),
            'value' => $group);
    }
    # Verify that a user with the same name does not exists
    if ($users->userExists($group)) {
        throw EBox::Exceptions::External(
            __x(q{A user account with the name '{name}' already exists. Users and groups cannot share names},
               name => $group)
           );
    }

    my @attr = (
        'cn'          => $group,
        'objectclass' => ['zentyalDistributionGroup'],
    );

    if ($params{security}) {
        my $gid = exists $params{gidNumber} ? $params{gidNumber}: $self->_gidForNewGroup($system);
        $self->_checkGid($gid, $system);
        push ($attr{objectclass}, 'posixGroup');
        push (@attr, gidNumber => $gid);
   }
    push (@attr, 'description' => $comment) if ($comment);

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attr);
        $users->notifyModsPreLdapUserBase('preAddGroup', $entry,
            $params{ignoreMods}, $params{ignoreSlaves});

                my $changetype =  $entry->changetype();
                my $changes = [$entry->changes()];
        my $result = $entry->update($self->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on group LDAP entry creation:'),
                    result => $result,
                    opArgs   => $self->entryOpChangesInUpdate($entry),
                   );
            }
        }

        $res = new EBox::Users::Group(dn => $dn);
        unless ($system) {
            $users->reloadNSCD();

            # Call modules initialization
            $users->notifyModsLdapUserBase('addGroup', $res, $params{ignoreMods}, $params{ignoreSlaves});
        }
    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if ($res and $res->exists()) {
            $users->notifyModsLdapUserBase('addGroupFailed', [ $res ], $params{ignoreMods}, $params{ignoreSlaves});
            $res->SUPER::deleteObject(@_);
        } else {
            $users->notifyModsPreLdapUserBase('preAddGroupFailed', [ $entry ], $params{ignoreMods}, $params{ignoreSlaves});
        }
        $res = undef;
        $entry = undef;
        throw $error;
    };

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

    my $ldap = EBox::Global->modInstance('users')->ldap();

    return any { /posixGroup/ } $ldap->objectClasses($self->dn());
}

# Method: isSystemGroup
#
#   Whether the security group is a system group.
#
sub isSystemGroup
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
    my ($self, $system) = @_;

    my $gid;
    if ($system) {
        $gid = $self->lastGid(1) + 1;
        if ($gid == MINGID) {
            throw EBox::Exceptions::Internal(
                __('Maximum number of groups reached'));
        }
    } else {
        $gid = $self->lastGid + 1;
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
    my ($self, $system) = @_;

    my $lastGid = -1;
    my $users = EBox::Global->modInstance('users');
    foreach my $group (@{$users->securityGroups($system)}) {
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
    }
    else {
        if ($system) {
            throw EBox::Exceptions::External(
               __x('Incorrect GID {gid} for a system group . GID must be lesser than {max}',
                    gid => $gid,
                    max => MINGID,
                   )
               );
        }
    }
}

1;
