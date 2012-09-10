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

# Class: EBox::SysInfo::Model::ManageAdmins
#
#   This model is used to configure the administrator user account
#

package EBox::SysInfo::Model::ManageAdmins;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Password;
use EBox::Types::Action;

use base 'EBox::Model::DataTable';

my $ADMIN_GROUP = 'sudo';

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

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $grent = `getent group $ADMIN_GROUP`;
    chomp ($grent);
    my (undef, undef, undef, $usersField) = split (':', $grent);
    my @users = split (',', $usersField);

    my %newUsers = map { $_ => 1 } @users;

    my %currentUsers = map { $self->row($_)->valueByName('username') => $_ } @{$currentRows};

    my $modified = 0;

    my @usersToAdd = grep { not exists $currentUsers{$_} } keys %newUsers;
    my @usersToDel = grep { not exists $newUsers{$_} } keys %currentUsers;

    foreach my $user (@usersToAdd) {
        $self->add(username => $user);
        $modified = 1;
    }

    foreach my $user (@usersToDel) {
        my $id = $currentUsers{$user};
        $self->removeRow($id, 1);
        $modified = 1;
    }

    return $modified;
}

sub addTypedRow
{
    my ($self, $params) = @_;

    my $user = $params->{username}->value();

    # Create user if not exists
    system("id $user");
    if ($?) {
        EBox::Sudo::root("adduser --disabled-password --gecos '' $user");

        my $password = $params->{password}->value();
        $self->_changePassword($user, $password);
    }

    EBox::Sudo::root("adduser $user $ADMIN_GROUP");

    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'addAdmin', $user);
}

sub setTypedRow
{
    my ($self, $id, $params) = @_;

    my $oldRow = $self->row($id);

    my $user = $params->{username}->value();
    my $oldName = $oldRow->valueByName('username');

    EBox::Sudo::root("usermod -l $user $oldName");

    my $password = $params->{password}->value();
    $self->_changePassword($user, $password);

    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'changePassword', $user);
}

sub removeRow
{
    my ($self, $id) = @_;

    my $row = $self->row($id);

    my $user = $row->valueByName('username');
    EBox::Sudo::root("deluser $user $ADMIN_GROUP");

    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'delAdmin', $user);
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

    EBox::Auth->setPassword($username, $password);
    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'changePassword', $username);
}

1;
