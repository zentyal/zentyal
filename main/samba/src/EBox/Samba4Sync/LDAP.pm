#!/usr/bin/perl

use strict;
use warnings;

package Samba4Sync::LDAP;

use MIME::Base64;
use Encode;
use Perl6::Junction qw(any);
use Error qw (:try);

use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;
use EBox::LDB;
use EBox::Samba;

my $cachedLdb = undef;

# Method: getUser
#
#   Searchs a user in the Zentyal LDAP and returns a user instance if
#   the user is found
#
# Parameters:
#
#   dn - The user DN forwarded by the LDB module. This DN is samba formatted
#        so it has to be converted to Zentyal format
#
#   uid - uid to check the cached user
#
# Returns:
#
#   A user instance on success, undef on error
#
sub getUser
{
    my ($dn, $uid) = @_;

    # Translate the samba DN to the zentyal DN
    my @dn = split (',', $dn);
    shift @dn;
    $dn = join (',', @dn);
    $dn =~ s/CN=/OU=/g;
    my $zentyalDn = "uid=$uid,$dn";
    my $user = new EBox::UsersAndGroups::User(dn => $zentyalDn);
    unless ($user->exists()) {
        return undef;
    }
    return $user;
}

# Method: getGroup
#
#   Searchs a group in the Zentyal LDAP and returns a group instance if
#   the group is found
#
# Parameters:
#
#   dn - The group DN forwarded by the LDB module. This DN is samba formatted
#        so it has to be converted to Zentyal format
#
#   gid - gid to check the cached group
#
# Returns:
#
#   A group instance on success, undef on error
#
sub getGroup
{
    my ($dn, $gid) = @_;

    # Translate the samba DN to the zentyal DN
    my @dn = split (',', $dn);
    shift @dn;
    $dn = join (',', @dn);
    $dn =~ s/CN=Users/OU=Groups/g;
    $dn =~ s/CN=/OU=/g;
    my $zentyalDn = "cn=$gid,$dn";
    my $group = new EBox::UsersAndGroups::Group(dn => $zentyalDn);
    unless ($group->exists()) {
        return undef;
    }
    return $group;
}

sub add
{
    my ($dn, $attrs) = @_;

    my $ret = 0;
    if (not defined $attrs->{isCriticalSystemObject}) {
        my %objectClass = map { decode_base64($_) => 1 } @{$attrs->{objectClass}->{values}};
        if (exists $objectClass{computer}) {
            # Computers also has the 'user' object class so this must be the
            # first case to ignore them
        } elsif (exists $objectClass{user}) {
            $ret = addUser($dn, $attrs);
        } elsif (exists $objectClass{group}) {
            $ret = addGroup($dn, $attrs);
        }
    }

    return $ret;
}

sub modify
{
    my ($dn, $attrs, $object) = @_;

    my $ret = 0;
    if (not defined $object->{isCriticalSystemObject}) {
        my %objectClass = map { decode_base64($_) => 1 } @{$object->{objectClass}->{values}};
        if (exists $objectClass{computer}) {
            # Computers also has the 'user' object class so this must be the
            # first case to ignore them
        } elsif (exists $objectClass{user}) {
            $ret = modifyUser($dn, $attrs, $object);
        } elsif (exists $objectClass{group}) {
            $ret = modifyGroup($dn, $attrs, $object);
        }
    }

    return $ret;
}

sub del
{
    my ($dn, $object) = @_;

    my $ret = 0;
    if (not defined $object->{isCriticalSystemObject}) {
        my %objectClass = map {decode_base64($_) => 1} @{$object->{objectClass}->{values}};
        if (exists $objectClass{computer}) {
            # Computers also has the 'user' object class so this must be the
            # first case to ignore them
        } elsif (exists $objectClass{user}) {
            $ret = deleteUser($dn, $object);
        } elsif (exists $objectClass{group}) {
            $ret = deleteGroup($dn, $object);
        }
    }

    return $ret;
}

sub addUser
{
    my ($dn, $attrs) = @_;

    my $ret = -1;

    my $userName    = $attrs->{sAMAccountName}->{values}[0];
    my $givenName   = $attrs->{givenName}->{values}[0];
    my $surName     = $attrs->{sn}->{values}[0];
    my $commonName  = $attrs->{name}->{values}[0];
    my $description = $attrs->{description}->{values}[0];

    # Windows uses different attribute name
    unless (defined $userName) {
        $userName = $attrs->{samAccountName}->{values}[0];
    }

    if (defined $userName) {
        $userName = decode_base64($userName);
    }
    if (defined $givenName) {
        $givenName = decode_base64($givenName);
    }
    if (defined $surName) {
        $surName = decode_base64($surName);
    }
    if (defined $commonName) {
        $commonName = decode_base64($commonName);
    }
    if (defined $description) {
        $description = decode_base64($description);
    }

    my $user = getUser($dn, $userName);
    if (defined $user) {
        throw EBox::Exceptions::Internal("User '$userName' already exists");
    }
    my $userParams;
    $userParams->{'user'} = $userName;
    $userParams->{'givenname'} = defined ($givenName) ? $givenName : $userName;
    $userParams->{'surname'} = defined ($surName) ? $surName : $userName;
    $userParams->{'cn'} = defined ($commonName) ? $commonName : $userName;
    $userParams->{'comment'} = $description;

    _info("Adding user '$userName'");
    my %params;
    $params{ignoreMods} = ['samba'];
    EBox::UsersAndGroups::User->create($userParams, 0, %params);
    $ret = 0;

    return $ret;
}

sub addGroup
{
    my ($dn, $attrs) = @_;

    my $ret = -1;

    my $groupName = $attrs->{sAMAccountName}->{values}[0];
    my $description = $attrs->{description}->{values}[0];

    # Windows uses different attribute name
    unless (defined $groupName) {
        $groupName = $attrs->{samAccountName}->{values}[0];
    }

    if (defined $groupName) {
        $groupName = decode_base64($groupName);
    }
    if (defined $description) {
        $description = decode_base64($description);
    }

    my $group = getGroup($dn, $groupName);
    if (defined $group) {
        throw EBox::Exceptions::Internal("Group '$groupName' already exists");
    }

    _info("Adding group '$groupName'");
    my %params;
    $params{ignoreMods} = ['samba'];
    EBox::UsersAndGroups::Group->create($groupName, $description, 0, %params);
    $ret = 0;

    return $ret;
}

sub modifyUser
{
    my ($dn, $attrs, $object) = @_;

    my $userName = $object->{sAMAccountName}->{values}[0];

    # Windows uses different attribute name
    unless (defined $userName) {
        $userName = $object->{samAccountName}->{values}[0];
    }

    if (defined $userName) {
        $userName = decode_base64($userName);
    }

    my $user = getUser($dn, $userName);

    if (defined $user) {
        if (defined $attrs->{unicodePwd}) {
            my $pwd = delete $attrs->{unicodePwd};
            $pwd = decode_base64($pwd->{values}[0]);
            $pwd = decode('UTF16-LE', $pwd);
            $pwd =~ s/(^"|"$)//g;
            $user->setIgnoredModules(['samba']);
            _info("Updating '$userName' password");
            $user->changePassword($pwd, 1);
        }

        if (defined $attrs->{clearTextPassword}) {
            my $pwd = delete $attrs->{clearTextPassword};
            $pwd = decode_base64($pwd->{values}[0]);
            $user->setIgnoredModules(['samba']);
            _info("Updating '$userName' password");
            $user->changePassword($pwd, 1);
        }

        foreach my $attr (keys $attrs) {
            if ($attr eq any $user->CORE_ATTRS) {
                my $value = decode_base64($attrs->{$attr}->{values}[0]);
                $user->set($attr, $value, 1);
                _info("Modify user '$userName'");
            }
        }

        if (defined $user->{core_changed} or
            defined $user->{core_changed_password}) {
            $user->setIgnoredModules(['samba']);
            $user->save();
        }
    }

    return 0;
}

sub modifyGroup
{
    my ($dn, $attrs, $object) = @_;

    my $groupName = $object->{sAMAccountName}->{values}[0];
    my $description = $object->{description}->{values}[0];
    unless (defined $groupName) {
        $groupName = $object->{samAccountName}->{values}[0];
    }

    if (defined $groupName) {
        $groupName = decode_base64($groupName);
    }

    my $group = getGroup($dn, $groupName);
    if (defined $group) {
        my $member = delete $attrs->{member};
        if (defined $member) {
            if ($member->{flags} eq '1') {
                # Flag '1' means add members
                addGroupMembers($group, $member->{values});
            } elsif ($member->{flags} eq '3') {
                # Flag '3' means del members
                delGroupMembers($group, $member->{values});
            }
        }

        foreach my $attr (keys $attrs) {
            if ($attr eq any $group->CORE_ATTRS) {
                my $value = decode_base64($attrs->{$attr}->{values}[0]);
                _info("Modify group '$groupName'");
                $group->set($attr, $value, 1);
            }
        }

        if (defined $group->{core_changed}) {
            $group->setIgnoredModules(['samba']);
            $group->save();
        }
    }

    return 0;
}

sub deleteUser
{
    my ($dn, $object) = @_;

    my $userName = $object->{sAMAccountName}->{values}[0];
    # Windows uses different attribute name
    unless (defined $userName) {
        $userName = $object->{samAccountName}->{values}[0];
    }

    if (defined $userName) {
        $userName = decode_base64($userName);
    }
    my $user = getUser($dn, $userName);
    if (defined $user) {
        $user->setIgnoredModules(['samba']);
        _info("Deleting user '$userName'");
        $user->deleteObject();
    }

    return 0;
}

sub deleteGroup
{
    my ($dn, $object) = @_;

    my $groupName = $object->{sAMAccountName}->{values}[0];
    # Windows uses different attribute name
    unless (defined $groupName) {
        $groupName = $object->{samAccountName}->{values}[0];
    }
    if (defined $groupName) {
        $groupName = decode_base64($groupName);
    }

    my $group = getGroup($dn, $groupName);
    if (defined $group) {
        $group->setIgnoredModules(['samba']);
        _info("Deleting group '$groupName'");
        $group->deleteObject();
    }

    return 0;
}

sub addGroupMembers
{
    my ($group, $members) = @_;

    my $ldb = getLdb();

    my $gid = $group->get('cn');
    foreach my $memberDN (@{$members}) {
        try {
            $memberDN = decode_base64($memberDN);
            my $userName = $ldb->getIdByDN($memberDN);
            my $user = getUser($memberDN, $userName);
            _info("Adding user '$userName' to group '$gid'");
            $group->addMember($user, 1);
        } otherwise {
            my $error = shift;
            _error($error);
        };
    }
}

sub delGroupMembers
{
    my ($group, $members) = @_;

    my $ldb = getLdb();

    my $gid = $group->get('cn');
    foreach my $memberDN (@{$members}) {
        try {
            $memberDN = decode_base64($memberDN);
            my $userName = $ldb->getIdByDN($memberDN);
            my $user = getUser($memberDN, $userName);
            _info("Removing user '$userName' from group '$gid'");
            $group->removeMember($user, 1);
        } otherwise {
            my $error = shift;
            _error($error);
        };
    }
}

sub getLdb
{
    unless (defined $cachedLdb) {
        my $samba = EBox::Global->modInstance('samba');
        $cachedLdb = $samba->ldb();
    }
    return $cachedLdb;
}

sub _error
{
    my ($msg) = @_;

    EBox::error($msg);
    print "ERROR: $msg\n";
}

sub _warning
{
    my ($msg) = @_;

    EBox::warn($msg);
    print "WARNING: $msg\n";
}

sub _info
{
    my ($msg) = @_;

    EBox::info($msg);
    print "INFO: $msg\n";
}

sub _debug
{
    my ($msg) = @_;

    EBox::debug($msg);
    print "DEBUG: $msg\n";
}

1;
