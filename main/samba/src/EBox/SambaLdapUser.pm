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
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;

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

# Method: _addUser
#
#   This method adds the user to samba LDAP
#   TODO Support multiples OU
#
sub _addUser
{
    my ($self, $zentyalUser, $zentyalPassword) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalUser->dn();
    EBox::debug("Adding user '$dn' to samba");
    my $params = {
        clearPassword => $zentyalPassword,
        uidNumber     => scalar ($zentyalUser->get('uidNumber')),
        description   => scalar ($zentyalUser->get('description')),
        givenName     => scalar ($zentyalUser->get('givenName')),
        sn            => scalar ($zentyalUser->get('sn')),
    };
    EBox::Samba::User->create($zentyalUser->get('uid'), $params);
}

sub _modifyUser
{
    my ($self, $zentyalUser, $zentyalPwd) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalUser->dn();
    EBox::debug("Updating user '$dn'");
    try {
        my $sambaUser = new EBox::Samba::User(samAccountName => $zentyalUser->get('uid'));
        return unless $sambaUser->exists();

        my $gn = $zentyalUser->get('givenName');
        my $sn = $zentyalUser->get('sn');
        my $desc = $zentyalUser->get('description');
        $sambaUser->set('givenName', $gn, 1);
        $sambaUser->set('sn', $sn, 1);
        $sambaUser->set('description', $desc, 1);
        $sambaUser->changePassword($zentyalPwd, 1) if defined $zentyalPwd;
        $sambaUser->save();
    } otherwise {
        my ($error) = @_;
        EBox::error("Error modifying user: $error");
    };
}

sub _delUser
{
    my ($self, $zentyalUser) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalUser->dn();
    EBox::debug("Deleting user '$dn' from samba");
    try {
        my $sambaUser = new EBox::Samba::User(samAccountName => $zentyalUser->get('uid'));
        return unless $sambaUser->exists();
        $sambaUser->deleteObject();
    } otherwise {
        my ($error) = @_;
        EBox::error("Error deleting user: $error");
    };
}

# Method: _addGroup
#
#   This method adds the group to samba LDAP
#   TODO Support multiples OU
#
sub _addGroup
{
    my ($self, $zentyalGroup) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalGroup->dn();
    EBox::debug("Adding group '$dn' to samba");
    my $params = {
        gidNumber     => scalar ($zentyalGroup->get('gidNumber')),
        description   => scalar ($zentyalGroup->get('description')),
    };
    EBox::Samba::Group->create($zentyalGroup->get('cn'), $params);
}

sub _modifyGroup
{
    my ($self, $zentyalGroup) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalGroup->dn();
    EBox::debug("Modifying group '$dn'");
    try {
        my $sambaGroup = new EBox::Samba::Group(samAccountName => $zentyalGroup->get('cn'));
        return unless $sambaGroup->exists();

        my $sambaMembersDNs = [];
        my $zentyalMembers = $zentyalGroup->users();
        foreach my $zentyalMember (@{$zentyalMembers}) {
            my $sambaUser = new EBox::Samba::User(samAccountName => $zentyalMember->get('uid'));
            push (@{$sambaMembersDNs}, $sambaUser->dn());
        }
        $sambaGroup->set('member', $sambaMembersDNs, 1);
        $sambaGroup->set('description', scalar ($zentyalGroup->get('description')), 1);
        $sambaGroup->save();
    } otherwise {
        my ($error) = @_;
        EBox::error("Error modifying group: $error");
    };
}

sub _delGroup
{
    my ($self, $zentyalGroup) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $dn = $zentyalGroup->dn();
    EBox::debug("Deleting group '$dn' from samba");
    try {
        my $sambaGroup = new EBox::Samba::Group(samAccountName => $zentyalGroup->get('cn'));
        return unless $sambaGroup->exists();
        $sambaGroup->deleteObject();
    } otherwise {
        my ($error) = @_;
        EBox::error("Error deleting user: $error");
    };
}

# User and group addons

sub _userAddOns
{
    my ($self, $zentyalUser) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $sambaUser = new EBox::Samba::User(samAccountName => $zentyalUser->get('uid'));
    return undef unless $sambaUser->exists();

    my $serviceEnabled = $self->{samba}->isEnabled();
    my $accountEnabled = $sambaUser->isAccountEnabled();

    my $args = {
        'username'       => $zentyalUser->dn(),
        'accountEnabled' => $accountEnabled,
        'service'        => $serviceEnabled,
    };

    return { path => '/samba/samba.mas', params => $args };
}

# Method: _groupShareEnabled
#
#   Check if there is a share configured for the group
#
# Returns:
#
#   The share name or undef if it is not configured
#
sub _groupShareEnabled
{
    my ($self, $zentyalGroup) = @_;

    my $groupName = $zentyalGroup->get('cn');
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

    my $oldName = $self->_groupShareEnabled($group);
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
    my ($self, $zentyalGroup) = @_;

    my $groupName = $zentyalGroup->get('cn');
    my $sharesModel = $self->{samba}->model('SambaShares');
    my $row = $sharesModel->findValue(groupShare => $groupName);
    $sharesModel->removeRow($row->id()) if $row;
}

sub _groupAddOns
{
    my ($self, $zentyalGroup) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $share = $self->_groupShareEnabled($zentyalGroup);
    my $args =  {
        'groupname' => $zentyalGroup->dn(),
        'share'     => $share,
        'service'   => $self->{samba}->isEnabled(),
    };

    return { path => '/samba/samba.mas', params => $args };
}

1;
