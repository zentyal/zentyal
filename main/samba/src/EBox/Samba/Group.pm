#!/usr/bin/perl

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

# Class: EBox::Samba::Group
#
#   Samba group, stored in samba LDAP
#

package EBox::Samba::Group;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;

use Perl6::Junction qw(any);
use Error qw(:try);

use constant MAXGROUPLENGTH => 128;

use base 'EBox::Samba::LdbObject';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}


# Method: removeAllMembers
#
#   Remove all members in the group
#
sub removeAllMembers
{
    my ($self, $lazy) = @_;

    $self->set('member', [], $lazy);
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

    my @members = $self->get('member');

    # return if user already in the group
    foreach my $dn (@members) {
        if (lc ($dn) eq lc ($user->dn())) {
            return;
        }
    }
    push (@members, $user->dn());

    $self->set('member', \@members, $lazy);
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
    foreach my $dn ($self->get('member')) {
        push (@members, $dn) if (lc ($dn) ne lc ($user->dn()));
    }

    $self->set('member', \@members, $lazy);
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
    my ($self) = @_;

    my @members = $self->get('member');
    @members = map { new EBox::Samba::User(dn => $_) } @members;

    return \@members;
}


# Method: usersNotIn
#
#   Users that don't belong to this group
#
#   Returns:
#
#       array ref of EBox::UsersAndGroups::Group objects
#
sub usersNotIn
{
    my ($self, $system) = @_;

    my $dn = $self->dn();
    my %attrs = (
            base => $self->_ldap->dn(),
            filter => "(&(objectclass=posixAccount)(!(memberof=$dn)))",
            scope => 'sub',
            );

    my $result = $self->_ldap->search(\%attrs);

    my @users;
    if ($result->count > 0) {
        foreach my $entry ($result->sorted('uid')) {
            push (@users, new EBox::Samba::User(entry => $entry));
        }
    }
    return \@users;
}

sub setupGidMapping
{
    my ($self, $gidNumber) = @_;

    # NOTE Samba4 beta2 support rfc2307, reading uidNumber from ldap instead idmap.ldb, but
    # it is not working when the user init session as DOMAIN/user but user@domain.com
    # FIXME Remove this when fixed
    my $type = $self->_ldap->idmap->TYPE_GID();
    $self->_ldap->idmap->setupNameMapping($self->sid(), $type, $gidNumber);
}


# Method: create
#
#   Adds a new group
#
# Parameters:
#
#   group - group name
#   comment - comment's group
#   system - boolan: if true it adds the group as system group,
#   otherwise as normal group
#   ignoreMods - ldap modules to be ignored on addUser notify
#   ignoreSlaves - slaves to be ignored on addUser notify
#
sub create
{
    my ($self, $samAccountName, $params) = @_;

    # TODO Is the group added to the default OU?
    my $baseDn = $self->_ldap->dn();
    my $dn = "CN=$samAccountName,CN=Users,$baseDn";

    $self->_checkAccountName($samAccountName, MAXGROUPLENGTH);
    $self->_checkAccountNotExists($samAccountName);

    my $usersModule = EBox::Global->modInstance('users');
    my $realm = $usersModule->kerberosRealm();
    my $attr = [];
    push ($attr, objectClass    => ['top', 'group', 'posixGroup']);
    push ($attr, sAMAccountName    => "$samAccountName");
    push ($attr, gidNumber         => $params->{gidNumber}) if defined $params->{gidNumber};
    push ($attr, description       => $params->{description}) if defined $params->{description};

    # Add the entry
    my $result = $self->_ldap->add($dn, { attr => $attr });
    my $createdGroup = new EBox::Samba::Group(dn => $dn);

    # Setup the gid mapping
    $createdGroup->setupGidMapping($params->{gidNumber}) if defined $params->{gidNumber};

    return $createdGroup;
}

sub addToZentyal
{
    my ($self) = @_;

    my $gid       = $self->get('samAccountName');
    my $comment   = $self->get('description');

    my %optParams;
    $optParams{ignoreMods} = ['samba'];
    EBox::info("Adding samba group '$gid' to Zentyal");
    my $zentyalGroup = undef;
    try {
        $zentyalGroup = EBox::UsersAndGroups::Group->create($gid, $comment, 0, %optParams);
    } otherwise {};
    return unless defined $zentyalGroup;

    try {
        $self->_membersToZentyal($zentyalGroup);
    } otherwise {
        my $error = shift;
        EBox::error("Error adding members: $error");
    };
}

sub updateZentyal
{
    my ($self) = @_;

    my $gid = $self->get('samAccountName');
    EBox::info("Updating zentyal group '$gid'");

    my $zentyalGroup = undef;
    try {
        my $desc = $self->get('description');

        $zentyalGroup = new EBox::UsersAndGroups::Group(gid => $gid);
        $zentyalGroup->setIgnoredModules(['samba']);
        return unless $zentyalGroup->exists();

        $zentyalGroup->set('description', $desc, 1);
        $zentyalGroup->save();
    } otherwise {};
    return unless defined $zentyalGroup;

    try {
        $self->_membersToZentyal($zentyalGroup);
    } otherwise {
        my $error = shift;
        EBox::error("Error: $error");
    };
}

sub _membersToZentyal
{
    my ($self, $zentyalGroup) = @_;

    return unless (defined $zentyalGroup and $zentyalGroup->exists());

    my $gid = $self->get('samAccountName');
    my $sambaMembersList = $self->users();
    my $zentyalMembersList = $zentyalGroup->users();

    my %sambaMembers = map { $_->get('samAccountName') => $_ } @{$sambaMembersList};
    my %zentyalMembers = map { $_->get('uid') => $_ } @{$zentyalMembersList};

    foreach my $memberName (keys %zentyalMembers) {
        unless (exists $sambaMembers{$memberName}) {
            EBox::info("Removing member '$memberName' from Zentyal group '$gid'");
            $zentyalGroup->removeMember($zentyalMembers{$memberName}, 1);
        }
    }

    foreach my $memberName (keys %sambaMembers) {
        unless (exists $zentyalMembers{$memberName}) {
            EBox::info("Adding member '$memberName' to Zentyal group '$gid'");
            my $zentyalUser = new EBox::UsersAndGroups::User(uid => $memberName);
            next unless $zentyalUser->exists();
            $zentyalGroup->addMember($zentyalUser, 1);
        }
    }
    $zentyalGroup->setIgnoredModules(['samba']);
    $zentyalGroup->save();
}

1;
