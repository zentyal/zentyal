# Copyright (C) 2009-2012 eBox Technologies S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
use strict;
use warnings;

# Class: EBox::UsersAndGroups::Model::Password
#
#   Class for change password model in user corner
#

package EBox::UsersAndGroups::Model::Password;
use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::UsersAndGroups::Types::Password;

use Apache2::RequestUtil;
use File::Temp qw/tempfile/;

sub precondition
{
    return EBox::Global->modInstance('usercorner')->editableMode();
}

sub preconditionFailMsg
{
    return __('Password change is only available in master or standalone servers. You need to change your password from the user corner of your master server.');
}

sub pageTitle
{
    return __('Password management');
}

sub _table
{
    my @tableHead =
    (
        new EBox::UsersAndGroups::Types::Password(
            'fieldName' => 'pass1',
            'printableName' => __('New password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
        new EBox::UsersAndGroups::Types::Password(
            'fieldName' => 'pass2',
            'printableName' => __('Re-type new password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Password',
        'printableTableName' => __('Password'),
        'modelDomain' => 'Users',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $pass1 = $paramsRef->{'pass1'};
    my $pass2 = $paramsRef->{'pass2'};

    my $r = Apache2::RequestUtil->request;
    my $user = $r->user;

    $user = new EBox::UsersAndGroups::User(uid => $user);

    if ($pass1->cmp($pass2) != 0) {
        throw EBox::Exceptions::External(__('Passwords do not match.'));
    }

    $user->changePassword($pass1->value());

    if (EBox::Global->modExists('samba')) {
        my $samba = EBox::Global->modInstance('samba');
        if ($samba->configured()) {
            my $samAccountName = $user->get('uid');
            my $sambaUser = new EBox::Samba::User(samAccountName => $samAccountName);
            if ($sambaUser->exists()) {
                $sambaUser->changePassword($pass1->value());
            }
        }
    }

    eval 'use EBox::UserCorner::Auth';
    EBox::UserCorner::Auth->updatePassword($user, $pass1->value());

    $self->setMessage(__('Password successfully updated'));
}

1;
