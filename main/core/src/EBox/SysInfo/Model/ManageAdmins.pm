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

use TryCatch::Lite;

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

        # Create user if not exists
        system("id $user");
        if ($?) {
            EBox::Sudo::root("adduser --disabled-password --gecos '' $user");
            
            my $password = $params->{password}->value();
            $self->_changePassword($user, $password);
        }
        
        unless ($self->_userIsAdmin($user)) {
            EBox::Sudo::root("adduser $user $ADMIN_GROUP");
            my $audit = EBox::Global->modInstance('audit');
            $audit->logAction('System', 'General', 'addAdmin', $user, 0);
        }
        if ((not $self->_userIsInGroup($user, $LPADMIN_GROUP)) and $self->_groupExists($LPADMIN_GROUP)) {
            EBox::Sudo::root("adduser $user $LPADMIN_GROUP");
        }

        $self->setMessage($self->message('add'));

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
            EBox::Sudo::root("usermod -l $user $oldName");
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

    EBox::Sudo::root("deluser $user $ADMIN_GROUP");
    if ($self->_userIsInGroup($user, $LPADMIN_GROUP)) {
        EBox::Sudo::root("deluser $user $LPADMIN_GROUP");
    }

    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'delAdmin', $user, 0);
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
