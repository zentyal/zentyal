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
# Class: EBox::SysInfo::Model::ManageAdmins
#
#   This model is used to configure the administrator user account
#
package EBox::SysInfo::Model::ManageAdmins;

use base 'EBox::Model::DataTable';

use TryCatch;

use EBox::Gettext;
use EBox::Types::Password;
use EBox::Types::Action;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Middleware::AuthPAM;

my $ADMIN_GROUP = 'sudo';
my $LPADMIN_GROUP = 'lpadmin';

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Text(fieldName     => 'username',
                                           printableName => __('User name'),
                                           editable      => 1,
                                           size          => 20,
                                           defaultValue  => ''),
                     new EBox::Types::Password(fieldName     => 'password',
                                               printableName => __('Password'),
                                               confirmPrintableName => __('Confirm Password'),
                                               hiddenOnViewer => 1,
                                               editable      => 1,
                                               disableAutocomplete => 1,
                                               confirm       => 1,
                                               optional      => 1,
                                               optionalLabel => 0,
                                               size          => 16,
                                               minLength     => 6,
                                               help => __('Your password must be at least 6 characters long.')));

    my $dataTable =
    {
        'tableName' => 'ManageAdmins',
        'printableTableName' => __('Administrator Accounts'),
        'printableRowName' => __('administrator'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'disableAutocomplete' => 1,
    };

    return $dataTable;
}

sub ids
{
    my ($self) = @_;
    my (undef, undef, undef, $usersField) = getgrnam($ADMIN_GROUP);
    my @users = split ('\s', $usersField);
    my @ids = map {
        my $id = getpwnam($_);
        (defined $id) ? ($id) : ();
    } @users;
    return \@ids;
}

sub row
{
    my ($self, $id) = @_;
    if (not defined $id) {
        throw EBox::Exceptions::MissingArgument('id');
    }
    my $username = getpwuid($id);
    $username or throw
        EBox::Exceptions::Internal("Inexistent user id: $id");
    # we dont check again membership for sudo group
    my $row = $self->_setValueRow(
        username => $username
    );

    $row->setId($id);
    $row->setReadOnly(0);
    return $row;
}

sub _checkRowExist
{
    my ($self, $id, $text) = @_;
    my $user = getpwuid($id);
    if (not $user) {
        throw EBox::Exceptions::DataNotFound(
            data => 'UserId',
            value => $id);
    }
}

sub addTypedRow
{
    my ($self, $params) = @_;
    my $id;

    try {
        my $user = $params->{username}->value();
        # Forbid creation if user already exists in samba to avoid conflicts
        EBox::Sudo::silentRoot("samba-tool user list | grep ^$user\$");
        if ($? == 0) {
            throw EBox::Exceptions::External(__x('User "{user}" already exist in Active Directory', user => $user));
        }
        # Create user if not exists
        system("id $user");
        my $userNotExists = $?;
        if ($userNotExists) {
            _rootWithExternalEx("adduser --disabled-password --gecos '' $user");

            my $password = $params->{password}->value();
            $self->_changePassword($user, $password);
        }

        unless ($self->_userIsAdmin($user)) {
            _rootWithExternalEx("adduser $user $ADMIN_GROUP");
            my $audit = EBox::Global->modInstance('audit');
            $audit->logAction('System', 'General', 'addAdmin', $user, 0);
        }
        if ((not $self->_userIsInGroup($user, $LPADMIN_GROUP)) and $self->_groupExists($LPADMIN_GROUP)) {
            _rootWithExternalEx("adduser $user $LPADMIN_GROUP");
        }

        my $msg;
        if ($userNotExists) {
            $msg = __x('User "{user}" created and granted Zentyal administrative permissions',
                       user => $user);
        } else {
            $msg = __x('User "{user}" granted Zentyal administrative permissions',
                       user => $user);
        }
        $self->setMessage($msg);

        $id = getpwnam($user);
    } catch ($ex) {
        EBox::Exceptions::Base::rethrowSilently($ex);
    }

    return $id;
}

sub setTypedRow
{
    my ($self, $id, $params) = @_;

    try {
        my $oldRow = $self->row($id);

        my $user = $params->{username}->value();
        my $oldName = getpwuid($id);

        if ($user ne $oldName) {
            _rootWithExternalEx("usermod -l $user $oldName");
            my $audit = EBox::Global->modInstance('audit');
            $audit->logAction('System', 'General', 'changeLogin', "$oldName -> $user", 0);
        }


        my $password = $params->{password}->value();
        if ($password) {
            $self->_changePassword($user, $password);
        }

        $self->SUPER::setTypedRow($id, $params);
    } catch ($ex) {
        EBox::Exceptions::Base::rethrowSilently($ex);
    }
}

sub removeRow
{
    my ($self, $id) = @_;

    my $row = $self->row($id);
    my $user = getpwuid($id);

    my $removed;
    try {
        _rootWithExternalEx("deluser $user $ADMIN_GROUP");
        $removed = 1;
        if ($self->_userIsInGroup($user, $LPADMIN_GROUP)) {
            _rootWithExternalEx("deluser $user $LPADMIN_GROUP");
        }
    } catch($ex) {
        EBox::error("Error removing administration credentials from user $user: $ex");
    }

    if ($removed) {
        my $audit = EBox::Global->modInstance('audit');
        $audit->logAction('System', 'General', 'delAdmin', $user, 0);
    }

    $self->setMessage(__x('User "{user}" has its Zentyal administration permissions revoked',
                         user => $user)
                     );
}

sub _changePassword
{
    my ($self, $username, $password) = @_;
    unless (defined ($username)) {
        throw EBox::Exceptions::DataMissing(data =>  __('Username'));
    }

    unless (defined ($password)) {
        throw EBox::Exceptions::DataMissing(data => __('Password'));
    }

    unless (length ($password) > 5) {
        throw EBox::Exceptions::External(__('The password must be at least 6 characters long'));
    }

    EBox::Middleware::AuthPAM->setPassword($username, $password);
    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'changePassword', $username, 0);
}

sub _userIsInGroup
{
    my ($self, $user, $group) = @_;
    my $groutput = `groups $user`;
    chomp ($groutput);
    my (undef, $groupsField) = split (':', $groutput);
    my @groups = split (' ', $groupsField);
    foreach my $gr (@groups) {
        if ($gr eq $group) {
            return 1;
        }
    }
    return 0;
}

sub _rootWithExternalEx
{
    my ($cmd) = @_;
    try {
        EBox::Sudo::root($cmd);
    } catch (EBox::Exceptions::Command $ex) {
        throw EBox::Exceptions::External($ex->error());
    };

}

sub _groupExists
{
    my ($self, $group) = @_;
    system "grep '$group' /etc/group";
    return ($? == 0);
}

sub _userIsAdmin
{
    my ($self, $user) = @_;
    return $self->_userIsInGroup($ADMIN_GROUP);
}

1;
