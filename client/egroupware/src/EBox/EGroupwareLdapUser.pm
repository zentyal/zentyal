# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::EGroupwareLdapUser;

use strict;
use warnings;

use EBox::Global;
use EBox::Ldap;
use EBox::Gettext;
use EBox::MailUserLdap;

use base qw(EBox::LdapUserBase);

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{egroupware} = EBox::Global->modInstance('egroupware');
    bless($self, $class);
    return $self;
}

# Method: _addUser
#
#   Implements <EBox::LdapUserBase::_addUser>
#
sub _addUser
{
    my ($self, $user) = @_;

    unless ($self->{egroupware}->configured()) {
        return;
    }

    my $users = EBox::Global->modInstance('users');
    my $ldap = $self->{ldap};

    my $dn = "uid=$user," . $users->usersDn;

    my %attrs = (changes => [
                             add => [
                                     objectClass => 'eboxEgwAccount',
                                     egwPermsTemplate => 'default',
                                    ],
                            ]
                );

    my %args = (base => $dn, filter => 'objectClass=eboxEgwAccount');
    my $result = $ldap->search(\%args);

    unless ($result->count > 0) {
        $ldap->modify($dn, \%attrs);
    }

    # Set default permissions template
    my $uid = $users->userInfo($user)->{uid};
    $self->_setTemplate('default', $uid);
}

# Method: _addGroup
#
#   Implements <EBox::LdapUserBase::_addGroup>
#
sub _addGroup
{
    my ($self, $group) = @_;

    unless ($self->{egroupware}->configured()) {
        return;
    }

    my $users = EBox::Global->modInstance('users');
    my $ldap = $self->{ldap};

    my $dn = "cn=$group," . $users->groupsDn;

    my %attrs = (changes => [
                             add => [
                                     objectClass => 'eboxEgwAccount',
                                     egwPermsTemplate => 'default',
                                    ],
                            ]
                );

    my %args = (base => $dn, filter => 'objectClass=eboxEgwAccount');
    my $result = $ldap->search(\%args);

    unless ($result->count > 0) {
        $ldap->modify($dn, \%attrs);
    }

    # Set default permissions template
    my $gid = $users->groupGid($group);
    $self->_setTemplate('default', -$gid);
}

# Method: _userAddOns
#
#   Implements <EBox::LdapUserBase::_userAddOns>
#
sub _userAddOns
{
    my ($self, $username) = @_;
    my $egroupware = $self->{egroupware};

    return unless ($egroupware->configured());

    my $mailUserLdap = new EBox::MailUserLdap();
    my $mailAddr = $mailUserLdap->userAccount($username);

    my $domainModel = $egroupware->model('VMailDomain');
    my $egwDomain = $domainModel->vdomainValue();
    if ($egwDomain eq '_unset_') {
        $egwDomain = '';
    }
    my $egwMailAddr = "$username\@$egwDomain";

    my $validMail = $mailAddr eq $egwMailAddr;

    my $currentTemplate = $self->getUserTemplate($username);
    my $templatesModel = $egroupware->model('PermissionTemplates');
    my @templates;
    foreach my $id (@{$templatesModel->ids()}) {
        my $row = $templatesModel->row($id);
        push (@templates, $row->valueByName('name'));
    }
    unshift (@templates, 'default');

    my $args = {
        'username' => $username,
        'enabled'   => 1,
        'templates' => \@templates,
        'currentTemplate' => $currentTemplate,
        'service' => $egroupware->isEnabled(),
        'validMail' => $validMail,
        'egwDomain' => $egwDomain,
    };

    return { path => '/egroupware/egroupware.mas',
             params => $args };
}

# Method: _groupAddOns
#
#   Implements <EBox::LdapUserBase::_groupAddOns>
#
sub _groupAddOns
{
    my ($self, $groupname) = @_;
    my $egroupware = $self->{egroupware};

    return unless ($egroupware->configured());

    my $currentTemplate = $self->getGroupTemplate($groupname);
    my $model = $egroupware->model('PermissionTemplates');
    my @templates;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push (@templates, $row->valueByName('name'));
    }
    unshift (@templates, 'default');

    my $args = {
        'groupname' => $groupname,
        'enabled'   => 1,
        'templates' => \@templates,
        'currentTemplate' => $currentTemplate,
        'service' => $egroupware->isEnabled(),
    };

    return { path => '/egroupware/egroupware.mas',
             params => $args };
}

# Method: _delUser
#
#   Implements <EBox::LdapUserBase::_delUser>
#
sub _delUser
{
    my ($self, $user) = @_;

    unless ($self->{egroupware}->configured()) {
        return;
    }

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $uid = $users->userInfo($user)->{uid};

    # Remove egroupware ACL's associated with this user
    $self->_deletePermissions($uid);

    # TODO: Implement also _delUserWarning ??
}

# Method: _delGroup
#
#   Implements <EBox::LdapUserBase::_delGroup>
#
sub _delGroup
{
    my ($self, $group) = @_;

    unless ($self->{egroupware}->configured()) {
        return;
    }

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $gid = $users->groupGid($group);

    # Remove egroupware ACL's associated with this group
    $self->_deletePermissions(-$gid);

    # TODO: Implement also _delGroupWarning ??
}

sub schemas
{
    return [ EBox::Config::share() . "ebox-egroupware/ebox-egw-account.ldif" ];
}

sub setHasAccount #($username, [01]) 0=disable, 1=enable
{
    my ($self, $username, $option) = @_;

    if ($option) {
        $self->_addUser($username);
    } else {
        $self->_delUser($username);
    }
}

sub setHasGroupAccount #($username, [01]) 0=disable, 1=enable
{
    my ($self, $groupname, $option) = @_;

    if ($option) {
        $self->_addGroup($groupname);
    } else {
        $self->_delGroup($groupname);
    }
}

sub getUserTemplate
{
    my ($self, $user) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = "uid=$user," . $users->usersDn;

    return $self->_ldapSearchTemplate($dn);
}

sub getGroupTemplate
{
    my ($self, $group) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = "cn=$group," . $users->groupsDn;

    return $self->_ldapSearchTemplate($dn);
}

sub setUserTemplate
{
    my ($self, $user, $template) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $uid = $users->userInfo($user)->{uid};

    $self->_setTemplate($template, $uid);

    # Save the applied template name into ldap
    my $dn = "uid=$user," . $users->usersDn;
    $self->_ldapSaveTemplate($dn, $template);
}

sub setGroupTemplate
{
    my ($self, $group, $template) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $gid = $users->groupGid($group);

    $self->_setTemplate($template, -$gid);

    # Save the applied template name into ldap
    my $dn = "cn=$group," . $users->groupsDn;
    $self->_ldapSaveTemplate($dn, $template);
}

sub _setTemplate # (template, account) account = (uid | gid) number
{
    my ($self, $template, $account) = @_;

    # Delete old permissions
    $self->_deletePermissions($account);

    # Get permissions from template
    my $model;
    if ($template eq 'default') {
        $model = $self->{egroupware}->model('DefaultApplications');
    } else {
        my $ptModel = $self->{egroupware}->model('PermissionTemplates');
        my $row = $ptModel->find('name' => $template);
        $model =
            $row->elementByName('applications')->foreignModelInstance();
    }
    my @ids = @{$model->enabledRows()};
    my @apps = map ($model->row($_)->valueByName('app'), @ids);

    unless ($self->_databaseExists()) {
        return;
    }
    # Insert new permissions (changepassword permission only for user accounts)
    my $sql = $account > 0 ?
              'INSERT INTO egw_acl ' .
              "VALUES ('preferences','changepassword',$account,1);" :
              '';
    foreach my $app (@apps) {
        $sql .= "INSERT INTO egw_acl VALUES ('$app','run',$account,1);";
    }
    EBox::Sudo::root("su postgres -c \"psql egroupware -c \\\"$sql\\\"\"");
}

sub _ldapSearchTemplate # (dn)
{
    my ($self, $dn) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (
        base => $dn,
        filter => 'objectclass=eboxEgwAccount',
        scope => 'subtree',
        attrs => ['egwPermsTemplate']
    );

    my $result = $ldap->search(\%args);

    if ($result->count) {
        return $result->entry(0)->get_value('egwPermsTemplate');
    } else {
        return 'default';
    }
}

sub _ldapSaveTemplate # (dn, template)
{
    my ($self, $dn, $template) = @_;

    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    $ldap->modifyAttribute($dn, 'egwPermsTemplate', $template);
}

sub _deletePermissions # (account) account = (uid | gid) number
{
    my ($self, $account) = @_;

    if ($self->_databaseExists()) {
        my $sql = "DELETE FROM egw_acl WHERE acl_account=$account;";
        EBox::Sudo::root("su postgres -c \"psql egroupware -c \\\"$sql\\\"\"");
    }
}

sub _databaseExists
{
    my ($self) = @_;

    my $cmd = "su postgres -c \"psql egroupware -c ''\"";
    EBox::Sudo::rootWithoutException($cmd);
    return ($? == 0);
}


1;
