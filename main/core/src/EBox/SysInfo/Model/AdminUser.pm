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

# Class: EBox::SysInfo::Model::AdminUser
#
#   This model is used to configure the administrator user account
#
package EBox::SysInfo::Model::AdminUser;

use base 'EBox::Model::DataForm';

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Password;
use EBox::Types::Action;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;

use constant ADMIN_GROUP => 'sudo';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Select( fieldName     => 'username',
                                              printableName => __('Administrator user name'),
                                              editable      => 1,
                                              populate      => \&_populateAdmins,
                                           ),
                     new EBox::Types::Password( fieldName     => 'newPassword',
                                                printableName => __('New password'),
                                                confirmPrintableName => __('Confirm Password'),
                                                editable      => 1,
                                                disableAutocomplete => 1,
                                                confirm       => 1,
                                                size          => 16,
                                                minLength     => 6,
                                                help => __('Your password must be at least 6 characters long.')));

    my $customActions = [
        new EBox::Types::Action( name => 'changePwd',
                                 printableValue => __('Change'),
                                 model => $self,
                                 handler => \&_doChangePassword,
                                 message => __('The password was changed successfully.'))];

    my $dataTable =
    {
        'tableName' => 'AdminUser',
        'printableTableName' => __('Change administrator password'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [],
        'customActions' => $customActions,
        'tableDescription' => \@tableHead,
        'disableAutocomplete' => 1,
    };

    return $dataTable;
}

sub _adminUsers
{
    my ($name,$passwd,$gid,$members) = getgrnam(ADMIN_GROUP);
    return [ split '\s', $members ];
}

sub _populateAdmins
{
    my @values = map {
        { value => $_, printableValue => $_ }
    } @{ _adminUsers() };

    return \@values;
}

sub _doChangePassword
{
    my ($self, $action, $id, %params) = @_;

    my $username = $params{'username'};
    my $newpwd1  = $params{'newPassword'};
    my $newpwd2  = $params{'newPassword_confirm'};

    unless (defined ($username)) {
        throw EBox::Exceptions::DataMissing(data =>  __('Username'));
    }

    unless (defined ($newpwd1) and defined ($newpwd2)) {
        throw EBox::Exceptions::DataMissing(data => __('New password'));
    }

    unless ($newpwd1 eq $newpwd2) {
        throw EBox::Exceptions::External(__('Passwords does not match.'));
    }
    unless (length ($newpwd1) > 5) {
        throw EBox::Exceptions::External(__('The password must be at least 6 characters long'));
    }

    my $userIsAdmin = grep { $_ eq $username } @{ _adminUsers() };
    if (not $userIsAdmin) {
        throw EBox::Exceptions::External(__x("The user {us} is not a administrator user", us => $username));
    }

    EBox::Auth->setPassword($username, $newpwd1);
    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'changePassword', $username);

    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

1;
