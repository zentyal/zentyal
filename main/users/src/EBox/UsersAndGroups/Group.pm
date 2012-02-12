#!/usr/bin/perl -w

# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Group
#
#   Zentyal group, stored in LDAP
#

package EBox::UsersAndGroups::Group;

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use constant SYSMINUID      => 1900;
use constant SYSMINGID      => 1900;
use constant MINUID         => 2000;
use constant MINGID         => 2000;
use constant MAXGROUPLENGTH => 128;

use base 'EBox::UsersAndGroups::LdapObject';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}


# Method: name
#
#   Return group name
#
sub name
{
    my ($self) = @_;
    return $self->_entry->get('cn');
}


# Method: addMember
#
#   Adds the given user as a member
#
# Parameters:
#
#   user - User object
#
sub addMember
{
    my ($self, $user, $lazy) = @_;

    my @members = $self->_entry->get('member');
    push (@members, $user->dn());

    $self->set('member', \@members);

    $self->save() unless ($lazy);
}


# Method: removeMember
#
#   Removes the given user as a member
#
# Parameters:
#
#   user - User object
#
sub removeMember
{
    my ($self, $user, $lazy) = @_;

    my @members;
    foreach my $dn ($self->_entry->get('member')) {
        push (@members, $dn) if ($dn ne $user->dn());
    }

    $self->set('member', \@members);

    $self->save() unless ($lazy);
}


# Method: members
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members (EBox::UsersAndGroups::User)
#
sub members
{
    my ($self) = @_;

    my @members = map { new EBox::UsersAndGroups::User(dn => $_) }
                  @{$self->_entry->get('member')};

    return \@members;
}


# GROUP CREATION METHODS


# Method: create
#
#       Adds a new group
#
# Parameters:
#
#       group - group name
#       comment - comment's group
#       system - boolan: if true it adds the group as system group,
#       otherwise as normal group
#
sub create
{
    my ($self, $group, $comment, $system, %params) = @_;

    if (length($group) > MAXGROUPLENGTH) {
        throw EBox::Exceptions::External(
            __x("Groupname must not be longer than {maxGroupLength} characters",
                maxGroupLength => MAXGROUPLENGTH));
    }

    unless (_checkName($group)) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('group name'),
            'value' => $group);
    }

    # Verify group exists TODO
#    if ($self->groupExists($group)) {
#        throw EBox::Exceptions::DataExists('data' => __('group name'),
#                                           'value' => $group);
#    }

    my $gid = exists $params{gidNumber} ?
                     $params{gidNumber} :
                     $self->_gidForNewGroup($system);

    $self->_checkGid($gid, $system);

    my %args = (
        attr => [
                 'cn'        => $group,
                 'gidNumber'   => $gid,
                 'objectclass' => ['posixGroup', 'zentyalGroup'],
            ]
        );

    my $dn = "cn=" . $group ."," . $self->groupsDn;
    my $r = $self->ldap->add($dn, \%args);

    $self->_changeAttribute($dn, 'description', $comment);

    unless ($system) {
        # Tell modules depending on users and groups
        # a new group is created
        my @mods = @{$self->_modsLdapUserBase()};

        foreach my $mod (@mods){
            $mod->_addGroup($group);
        }
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
#       system - boolan: if true, it returns the last gid for system users,
#       otherwise the last gid for normal users
#
# Returns:
#
#       string - last gid
#
sub lastGid # (gid)
{
    my ($self, $system) = @_;

    my %args = (
        base => $self->_ldap->dn(),
        filter => '(objectclass=posixGroup)',
        scope => 'one',
        attrs => ['gidNumber']
    );

    my $result = $self->ldap->search(\%args);
    my @users = $result->sorted('gidNumber');

    my $gid = -1;
    foreach my $user (@users) {
        my $currgid = $user->get_value('gidNumber');
        if ($system) {
            last if ($currgid > MINGID);
        } else {
            next if ($currgid < MINGID);
        }

        if ( $currgid > $gid){
            $gid = $currgid;
        }
    }

    if ($system) {
        return ($gid < SYSMINUID ?  SYSMINUID : $gid);
    } else {
        return ($gid < MINGID ?  MINGID : $gid);
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
