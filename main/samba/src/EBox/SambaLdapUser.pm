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
    my ($self, $user) = @_;

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
        $self->{ldb}->updateUserPassword($user);

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

        # Map UID to SID
        # TODO Samba4 beta2 support rfc2307, reading uidNumber from ldap instead idmap.ldb, but
        # it is not working when the user init session as DOMAIN/user but user@domain.com
        # remove this when fixed
        my $sid   = $self->{ldb}->getSidById($samAccountName);
        my $idmap = $self->{ldb}->idmap();
        $idmap->setupNameMapping($sid, $idmap->TYPE_UID(), $uidNumber);

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
    my ($self, $user, $passwords) = @_;

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

        if (defined $passwords) {
            $self->{ldb}->updateUserPassword($user);
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

        # Map GID to SID
        # TODO Samba4 beta2 support rfc2307, reading gidNumber from ldap instead idmap.ldb, but
        # it is not working when the user init session as DOMAIN/user but user@domain.com
        # remove this when fixed
        my $sid   = $self->{ldb}->getSidById($samAccountName);
        my $idmap = $self->{ldb}->idmap();
        $idmap->setupNameMapping($sid, $idmap->TYPE_GID(), $gidNumber);
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

# User and group addons

# Method: accountEnabled
#
#   Check if the samba account is enabled, reading the userAccountControl
#   attribute. For a description of this attribute check:
#   http://support.microsoft.com/kb/305144/es
#
# Returns:
#
#   boolean - 1 if enabled, 0 if disabled
#
sub accountEnabled
{
    my ($self, $user) = @_;

    my $samAccountName = $user->get('uid');
    my $ldb = $self->{ldb};
    my $args = {
        base   => $ldb->dn(),
        scope  => 'sub',
        filter => "(samAccountName=$samAccountName)",
        attrs  => ['userAccountControl'],
    };
    my $result = $ldb->search($args);
    return undef unless ($result->count() == 1);
    my $entry = $result->entry(0);
    my $flags = $entry->get_value('userAccountControl');
    return not ($flags & 2);
}

# Method: setAccountEnabled
#
#   Enables or Disables the samba account modifying the userAccountControl
#   attribute. For a description of this attribute check:
#   http://support.microsoft.com/kb/305144/es
#
# Parameters:
#
#   enable - 1 to enable, 0 to disable
#
sub setAccountEnabled
{
    my ($self, $user, $enable) = @_;

    return unless (defined $user and defined $enable);

    my $ldb = $self->{ldb};
    my $samAccountName = $user->get('uid');
    my $params = {
        base => $ldb->dn(),
        scope => 'sub',
        filter => "(samAccountName=$samAccountName)",
        attrs => ['userAccountControl']
    };
    my $result = $ldb->search($params);
    return unless ($result->count() == 1);
    my $entry = $result->entry(0);
    my $flags = $entry->get_value('userAccountControl');
    if ($enable) {
        $flags = $flags & ~2;
    } else {
        $flags = $flags | 2;
    }
    try {
        EBox::debug("Setting user account control for user $samAccountName to $flags");
        $ldb->disableZentyalModule();
        $entry->replace(userAccountControl => $flags);
        $entry->update($ldb->ldbCon());
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $ldb->enableZentyalModule();
    };
}

# Method: isAdminUser
#
#   Check if the user is a domain administrator with rights
#   to join computers to the domain
#
# Returns:
#
#   boolean - 1 if the user has admin rights, 0 otherwise
#
sub isAdminUser
{
    my ($self, $user) = @_;

    my $samAccountName = $user->get('uid');
    my $ldb = $self->{ldb};
    my $args = {
        base   => $ldb->dn(),
        scope  => 'sub',
        filter => "(samAccountName=$samAccountName)",
        attrs  => ['memberOf'],
    };
    my $result = $ldb->search($args);
    return undef unless ($result->count() == 1);
    my $entry = $result->entry(0);

    my $domainAdminsDn   = $ldb->getDnById('Domain Admins');
    my $administratorsDn = $ldb->getDnById('Administrators');

    my %userGroups = map { $_ => 1 } ($entry->get_value('memberof'));
    my $isDomainAdmin   = exists $userGroups{$domainAdminsDn};
    my $isAdministrator = exists $userGroups{$administratorsDn};

    if ($isDomainAdmin and $isAdministrator) {
        return 1;
    } elsif ((not $isDomainAdmin) and (not $isAdministrator)) {
        return 0;
    } else {
        EBox::error("The user has incomplete group memberships; to be administrator " .
                    "he must be both member of domain Admins and Administrators group");
    }
    return undef;
}

# Method: setAdminUser
#
#   Set the user as a domain administrator with rights
#   to join computers to the domain
#
# Parameters:
#
#   user  - EBox::UsersAndGroups::User instance
#   admin - If true admin rights will be granted to the user,
#           otherwise rights will be revoked.
#
sub setAdminUser
{
    my ($self, $user, $admin) = @_;

    return unless (defined $user and defined $admin);

    my $ldb = $self->{ldb};
    my $samAccountName = $user->get('uid');
    my $params = {
        base => $ldb->dn(),
        scope => 'sub',
        filter => "(samAccountName=$samAccountName)",
        attrs => []
    };
    my $result = $ldb->search($params);
    return unless ($result->count() == 1);
    my $userEntry = $result->entry(0);
    my $userDn = $userEntry->get_value('distinguishedName');

    $params->{filter} = "(samAccountName=Domain Admins)";
    $result = $ldb->search($params);
    return unless ($result->count() == 1);
    my $domainAdminsEntry = $result->entry(0);
    my %domainAdminsMembers = map { $_ => 1 } ($domainAdminsEntry->get_value('member'));

    $params->{filter} = "(samAccountName=Administrators)";
    $result = $ldb->search($params);
    return unless ($result->count() == 1);
    my $administratorsEntry = $result->entry(0);
    my %administratorsMembers = map { $_ => 1 } ($administratorsEntry->get_value('member'));

    if ($admin) {
        $domainAdminsMembers{$userDn} = 1;
        $administratorsMembers{$userDn} = 1;
    } else {
        delete $domainAdminsMembers{$userDn};
        delete $administratorsMembers{$userDn};
    }

    my @domainAdminsMembers = keys %domainAdminsMembers;
    my @administratorsMembers = keys %administratorsMembers;
    try {
        $ldb->disableZentyalModule();
        $domainAdminsEntry->replace(member => \@domainAdminsMembers);
        $administratorsEntry->replace(member => \@administratorsMembers);
        $domainAdminsEntry->update($ldb->ldbCon());
        $administratorsEntry->update($ldb->ldbCon());
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $ldb->enableZentyalModule();
    };
}

sub _userAddOns
{
    my ($self, $user) = @_;

    return unless ($self->{samba}->configured());

    my $serviceEnabled = $self->{samba}->isEnabled();
    my $accountEnabled = $self->accountEnabled($user);
    my $isAdminUser    = $self->isAdminUser($user);

    my $args = {
        'username'       => $user->dn(),
        'accountEnabled' => $accountEnabled,
        'isAdminUser'    => $isAdminUser,
        'service'        => $serviceEnabled,
    };

    return { path => '/samba/samba.mas', params => $args };
}

# Method: groupShareEnabled
#
#   Check if there is a share configured for the group
#
# Returns:
#
#   The share name or undef if it is not configured
#
sub groupShareEnabled
{
    my ($self, $group) = @_;

    my $groupName = $group->get('cn');
    my $sharesModel = $self->{samba}->model('SambaShares');
    foreach my $id (@{$sharesModel->ids()}) {
        my $row = $sharesModel->row($id);
        my $shareName  = $row->valueByName('share');
        my $groupShare = $row->valueByName('groupShare');
        return $shareName if $groupShare eq $groupName;
    }

    return undef;
}

sub setGroupShare
{
    my ($self, $group, $shareName) = @_;

    if ((not defined $shareName) or ( $shareName =~ /^\s*$/)) {
        throw EBox::Exceptions::External(__("A name should be provided for the share."));
    }

    my $oldName = $self->groupShareEnabled($group);
    return if ($oldName and $oldName eq $shareName);

    my $groupName = $group->get('cn');
    my $sharesModel = $self->{samba}->model('SambaShares');

    # Create or rename the share for the group
    my $row = $sharesModel->findValue(groupShare => $groupName);
    if ($row) {
        # Rename the share
        EBox::debug("Renaming the share for group '$groupName' from '$oldName' to '$shareName'");
        $row->elementByName('share')->setValue($shareName);
        $row->store();
    } else {
        # Add the share
        my %params = ( share => $shareName,
                       path_selected => 'zentyal',
                       zentyal => $shareName,
                       comment => "Share for group $groupName",
                       guest => 0,
                       groupShare => $groupName );
        EBox::debug("Adding share named '$shareName' for group '$groupName'");
        my $shareRowId = $sharesModel->addRow(%params, readOnly => 1, enabled => 1);
        my $shareRow = $sharesModel->row($shareRowId);
        # And set the access control
        my $accessModel = $shareRow->subModel('access');
        %params = ( user_group_selected => 'group',
                    group => $groupName,
                    permissions => 'readWrite' );
        $accessModel->addRow(%params);
    }
}

sub removeGroupShare
{
    my ($self, $group) = @_;

    my $groupName = $group->get('cn');
    my $sharesModel = $self->{samba}->model('SambaShares');
    my $row = $sharesModel->findValue(groupShare => $groupName);
    $sharesModel->removeRow($row->id()) if $row;
}

sub _groupAddOns
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $share = $self->groupShareEnabled($group);

    #my $printers = $samba->_printersForGroup($groupname);
    my $args =  {
        'groupname' => $group->dn(),
        'share'     => $share,
        'service'   => $self->{samba}->isEnabled(),

        'printers' => [], #$printers,
        'printerService' => undef, #$samba->printerService(),
    };

    return { path => '/samba/samba.mas', params => $args };
}

1;
