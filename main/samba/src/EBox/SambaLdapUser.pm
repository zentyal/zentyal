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

use MIME::Base64;
use Encode;
use Error qw(:try);

use EBox::Sudo;
use EBox::Samba;
use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;

use Data::Dumper; # TODO

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
#   TODO Support multiples OU
#
sub _addUser
{
    my ($self, $user, $password) = @_;

    return unless ($self->{samba}->configured());

    my $dn = $user->dn();
    $dn =~ s/OU=Users/CN=Users/i;
    $dn =~ s/uid=/CN=/i;
    EBox::debug("Adding user '$dn' to LDB");

    my $uidNumber  = $user->get('uidNumber');
    my $gidNumber  = $user->get('gidNumber');

    my $samAccountName = $user->get('uid');
    my $sn = $user->get('sn');
    my $givenName = $user->get('givenName');
    my $principal = $user->get('krb5PrincipalName');
    my $description = $user->get('description');

    my $netbiosName = $self->{samba}->netbiosName();
    my $realmName = $self->{samba}->realm();
    my $path = "\\\\$netbiosName.$realmName\\$samAccountName";

    my $attrs = [];
    push ($attrs, objectClass       => ['user', 'posixAccount']);
    push ($attrs, sAMAccountName    => $samAccountName);
    push ($attrs, uidNumber         => $uidNumber);
    push ($attrs, sn                => $sn);
    push ($attrs, givenName         => $givenName);
    push ($attrs, userPrincipalName => $principal);
    push ($attrs, description       => $description) if defined $description;
    push ($attrs, homeDirectory     => $path);
    push ($attrs, homeDrive         => $self->{samba}->drive());

    # Set the romaing profile attribute if enabled
    if ($self->{samba}->roamingProfiles()) {
        my $netbiosName = $self->{samba}->netbiosName();
        my $realmName = $self->{samba}->realm();
        my $profilePath = "\\\\$netbiosName.$realmName\\profiles\\$samAccountName";
        push ($attrs, profilePath => $profilePath);
    }

    try {
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->add($dn, { attrs => $attrs });
        $self->{ldb}->changeUserPassword($dn, $password);

        # Get the entry from samba LDAP to read the SID and create the roaming profile dir
        my $args = { base   => $self->{ldb}->dn(),
                     scope  => 'sub',
                     filter => "(samAccountName=$samAccountName)",
                     attrs  => []};
        my $result = $self->{ldb}->search($args);
        if ($result->count() == 1) {
            my $entry = $result->entry(0);
            $self->{ldb}->createRoamingProfileDirectory($entry);
        }

        # Finally enable the account
        $self->{ldb}->modify($dn, { changes => [ replace => [ userAccountControl => 512 ] ] });
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _modifyUser
{
    my ($self, $user, $password) = @_;

    return unless ($self->{samba}->configured());

    try {
        my $uid = $user->get('uid');
        my $args = { base   => $self->{ldb}->dn(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$uid)",
                     attrs  => [] };
        my $result = $self->{ldb}->search($args);
        return unless ($result->count() == 1);

        my $entry = $result->entry(0);
        $entry->replace(givenName => $user->get('givenName'));
        $entry->replace(sn => $user->get('sn'));
        $entry->replace(description => $user->get('description'));

        $self->{ldb}->disableZentyalModule();
        $entry->update($self->{ldb}->ldbCon());
        if (defined $password) {
            $self->{ldb}->changeUserPassword($entry->dn(), $password);
        }
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _delUser
{
    my ($self, $user) = @_;

    return unless ($self->{samba}->configured());

    my $uid = $user->get('uid');

    my @cmds;
    if (-d PROFILESPATH . "/$uid") {
        push (@cmds, "rm -rf \'" .  PROFILESPATH . "/$uid\'");
    }
    EBox::Sudo::root(@cmds) if (@cmds);

    try {
        my $args = { base   => $self->{ldb}->dn(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$uid)",
                     attrs  => [] };
        my $result = $self->{ldb}->search($args);
        return unless ($result->count() == 1);

        my $entry = $result->entry(0);
        my $dn = $entry->dn();
        my $sid = $self->{ldb}->sidToString($entry->get_value('objectSid'));

        EBox::debug("Deleting user '$dn' from LDB");
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->delete($dn);
        # TODO Update shares ACLs to delete the SID
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _addGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    # TODO Support multiples OU
    my $dn = $group->dn();
    $dn =~ s/OU=Groups/CN=Users/i;
    EBox::debug("Adding group '$dn' to LDB");

    my $gidNumber      = $group->get('gidNumber');
    my $samAccountName = $group->get('cn');
    my $description    = $group->get('description');

    my $attrs = [];
    push ($attrs, objectClass    => 'group');
    push ($attrs, sAMAccountName => $samAccountName);
    push ($attrs, gidNumber      => $gidNumber);
    push ($attrs, description    => $description) if defined $description;

    try {
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->add($dn, { attrs => $attrs });
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    try {
        my $samAccountName = $group->get('cn');
        my $args = { base   => $self->{ldb}->dn(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$samAccountName)",
                     attrs  => [] };
        my $result = $self->{ldb}->search($args);
        return unless ($result->count() == 1);

        my $entry = $result->entry(0);

        # Here we translate the DN of the users in zentyal to the DN
        # of the users in samba
        my $sambaMembers = [];
        my @zentyalMembers = $group->get('member');
        foreach my $memberDN (@zentyalMembers) {
            my $user = new EBox::UsersAndGroups::User(dn => $memberDN);
            next unless defined $user;

            my $userSamAccountName = $user->get('uid');
            $args->{filter} = "(sAMAccountName=$userSamAccountName)";
            $result = $self->{ldb}->search($args);
            next if ($result->count() != 1);

            push ($sambaMembers, $result->entry(0)->dn());
        }

        $entry->replace(description => $group->get('description'));
        $entry->replace(member => $sambaMembers);

        $self->{ldb}->disableZentyalModule();
        $entry->update($self->{ldb}->ldbCon());
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _delGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $samAccountName = $group->get('cn');

    try {
        my $args = { base   => $self->{ldb}->dn(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$samAccountName)",
                     attrs  => [] };
        my $result = $self->{ldb}->search($args);
        return unless ($result->count() == 1);

        my $entry = $result->entry(0);
        my $dn = $entry->dn();
        my $sid = $self->{ldb}->sidToString($entry->get_value('objectSid'));

        EBox::debug("Deleting group '$dn' from LDB");
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->delete($dn);

        # TODO Update shares ACLs to delete the SID
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _directoryEmpty
{
    my ($self, $path) = @_;

    opendir(DIR, $path) or return 1;
    my @ent = readdir(DIR);

    return ($#ent == 1);
}

1;
