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

package EBox::SambaLdapUser;

use strict;
use warnings;

use EBox::Sudo;
use EBox::Samba;

use EBox::Gettext;
use Error qw(:try);

# Home path for users and groups
use constant BASEPATH           => '/home/ebox/samba';
use constant USERSPATH          => '/home';
use constant GROUPSPATH         => BASEPATH . '/groups';
use constant PROFILESPATH       => BASEPATH . '/profiles';

use base qw(EBox::LdapUserBase);

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{samba} = EBox::Global->modInstance('samba');
    $self->{ldb} = $self->{samba}->ldb();
    bless($self, $class);
    return $self;
}

# Method: _addUSer
#
#   This method adds the user to LDB
#
sub _addUser
{
    my ($self, $user, $password) = @_;

    return unless ($self->{samba}->configured());

    my $userId = $user->name();
    my $userUid = $user->get('uidNumber');
    my $userGid = $user->get('gidNumber');
    my $userGivenname = $user->firstname();
    my $userSurname = $user->surname();
    my $userComment = $user->comment();
    my $homeDirectory = $user->get('homeDirectory');
    #my $homeDrive = $self->{samba}->drive();
    my $profilePath = PROFILESPATH . "/$userId";
    #my $netbios = $self->{samba}->netbiosName();
    #$homeDirectory =~ s/\//\\/g;

    EBox::debug("Creating roaming profile directory for samba user '$userId'");
    $self->_createDir($profilePath, $userUid, $userGid, '0700');

    #$profilePath = "\\\\$netbios\\profiles\\$userId";
    my $result = $self->{ldb}->search({
            filter => "(sAMAccountName=$userId)",
            attrs => ['distinguishedName']});
    if (scalar (@{$result}) == 0) {
        # User creation
        my $cmd = $self->{samba}->SAMBATOOL() . " user create $userId $password" .
            " --enable-reversible-encryption" .
            " --surname='$userSurname'" .
            " --given-name='$userGivenname'";
            #" --profile-path='$profilePath'" .
            #" --home-drive='$homeDrive'" .
            #" --home-directory='$homeDirectory'";
        if (length ($userComment) > 0) {
            $cmd .= " --description='$userComment'";
        }
        EBox::debug("Adding user '$userId' to LDB");
        EBox::Sudo::root($cmd);
        # Map unix uid
        $self->{ldb}->xidMapping($userId, $userUid);
    }
}

sub _modifyUser
{
    my ($self, $user, $password) = @_;

    return unless ($self->{samba}->configured());
    my $userId = $user->name();
    my $userUid = $user->get('uidNumber');
    my $userGid = $user->get('gidNumber');
    my $userGivenname = $user->firstname();
    my $userSurname = $user->surname();
    my $userComment = $user->comment();
    #my $homeDirectory = $user->get('homeDirectory');
    #my $homeDrive = $self->{samba}->drive();
    #my $profilePath = PROFILESPATH . "/$userId";
    #my $netbios = $self->{samba}->netbiosName();
    #$profilePath = "\\\\$netbios\\profiles";
    #$homeDirectory =~ s/\//\\/g;

    # Get the user DN
    my $result = $self->{ldb}->search({
        filter => "(sAMAccountName=$userId)",
        attrs => ['distinguishedName', 'description']});
    if (scalar (@{$result}) == 1 ) {
        my $entry = pop @{$result};
        my $dn = pop @{$entry->{distinguishedName}};
        my $description = pop @{$entry->{description}};
        my $attrs = {
            modify => {
                givenName => $userGivenname,
                sn => $userSurname,
                #homeDirectory => $homeDirectory,
                #homeDrive => $homeDrive,
                #profilePath => $profilePath,
            },
        };
        if (length ($userComment) > 0) {
            $attrs->{modify}->{description} = $userComment;
        } elsif ($description) {
            $attrs->{delete}->{description} = '';
        }
        EBox::debug("Updating user info");
        $self->{ldb}->modify($self->{ldb}->samdb(), $dn, $attrs);
        EBox::debug("Updating user uid mapping");
        $self->{ldb}->xidMapping($userId, $userUid);
        if (length ($password) > 0) {
            EBox::debug("Updating user password");
            my $cmd = $self->{samba}->SAMBATOOL() . " user setpassword $userId --newpassword='$password'";
            EBox::Sudo::root($cmd);
        }
    } else {
        throw EBox::Exceptions::DataNotFound("Couldn't find user '$userId' in LDB");
    }
}

sub _delUser
{
    my ($self, $user) = @_;

    return unless ($self->{samba}->configured());

    my $userId = $user->name();

    my @cmds;
    if (-d PROFILESPATH . "/$userId") {
        push (@cmds, "rm -rf \'" .  PROFILESPATH . "/$userId\'");
    }
    EBox::Sudo::root(@cmds) if (@cmds);

    my $result = $self->{ldb}->search({
            filter => "(sAMAccountName=$userId)",
            attrs => ['distinguishedName']});
    if (scalar @{$result} == 1) {
        my $cmd = $self->{samba}->SAMBATOOL() . " user delete $userId";
        EBox::debug("Deleting user '$userId' from LDB");
        EBox::Sudo::root($cmd);
        # TODO Update shares ACLs
    }
}

sub _addGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $groupId = $group->name();
    my $description = $group->get('description');
    my $groupGid = $group->get('gidNumber');

    my $result = $self->{samba}->ldb->search({
            filter => "(sAMAccountName=$groupId)",
            attrs => ['distinguishedName']});
    if (scalar (@{$result}) == 0) {
        # Group creation
        my $cmd = $self->{samba}->SAMBATOOL() . " group add $groupId";
        if (length ($description) > 0) {
            $cmd .= " --description='$description'";
        }
        EBox::debug("Adding group '$groupId' to LDB");
        EBox::Sudo::root($cmd);
        # Map unix gid
        EBox::debug("Mapping group gid '$groupId' to '$groupGid'");
        $self->{ldb}->xidMapping($groupId, $groupGid);
    }
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $groupId = $group->name();
    my $groupGid = $group->get('gidNumber');
    my $description = $group->get('description');
    my $ldapMembers = $group->users();
    my $sambaMembers = $self->{ldb}->getGroupMembers($groupId);

    my $result = $self->{ldb}->search({
            filter => "(sAMAccountName=$groupId)",
            attrs => ['distinguishedName', 'description']});
    if (scalar (@{$result}) == 1) {
        my $entry = pop @{$result};
        my $dn = pop @{$entry->{distinguishedName}};
        # Here we only update the group description and gid,
        # the users membership is managed by the sync script
        my $attrs = {};
        if (length ($description) > 0) {
            $attrs->{modify}->{description} = $description;
        } elsif (defined ($entry->{description}[0])) {
            $attrs->{delete}->{description} = '';
        }
        EBox::debug("Updating group '$groupId' info");
        $self->{ldb}->modify($self->{ldb}->samdb(), $dn, $attrs);
        EBox::debug("Updating group '$groupId' members");
        $self->{ldb}->syncGroupMembersLdapToLdb($groupId);
        EBox::debug("Updating gid mapping of group '$groupId' to '$groupGid'");
        $self->{ldb}->xidMapping($groupId, $groupGid);
    }
}

sub _delGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $groupId = $group->name();
    my $description = $group->get('description');

    my $result = $self->{samba}->ldb->search({
            filter => "(sAMAccountName=$groupId)",
            attrs => ['distinguishedName']});
    if (scalar (@{$result}) == 1) {
        my $cmd = $self->{samba}->SAMBATOOL() . " group delete $groupId";
        EBox::debug("Deleting group '$groupId' from LDB");
        EBox::Sudo::root($cmd);
        # TODO Update shares ACLs
    }
}

sub _createDir
{
    my ($self, $path, $uid, $gid, $chmod) = @_;

    my @cmds;
    push (@cmds, "mkdir -p \'$path\'");
    push (@cmds, "chown $uid:$gid \'$path\'");

    if ($chmod) {
        push (@cmds, "chmod $chmod \'$path\'");
    }

    EBox::debug("Executing @cmds");
    EBox::Sudo::root(@cmds);
}

sub _directoryEmpty
{
    my ($self, $path) = @_;

    opendir(DIR, $path) or return 1;
    my @ent = readdir(DIR);

    return ($#ent == 1);
}

1;
