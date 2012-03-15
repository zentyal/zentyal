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

# Class: EBox::SysInfo::Model::AdminUser
#
#   This model is used to configure the administrator user account
#

package EBox::SysInfo::Model::AdminUser;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Password;

use base 'EBox::Model::DataForm';

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

    my @tableHead = (new EBox::Types::Text( fieldName     => 'username',
                                            printableName => __('User name'),
                                            editable      => 1,
                                            size          => 20),
                     new EBox::Types::Password( fieldName     => 'password',
                                                printableName => __('Current password'),
                                                editable      => 1,
                                                size          => 16),
                     new EBox::Types::Password( fieldName     => 'newPassword',
                                                printableName => __('New password'),
                                                confirmPrintableName => __('Confirm Password'),
                                                editable      => 1,
                                                confirm       => 1,
                                                size          => 16,
                                                help => __('Your password must be at least 6 characters long.')));

    my $dataTable =
    {
        'tableName' => 'AdminUser',
        'printableTableName' => __('Change administrator password'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

# Method: formSubmitted
#
# Overrides:
#
#   <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    #if (defined($self->param('password'))) {
    #    my $username = $self->unsafeParam('username');
    #    if (not $username) {
    #        throw EBox::Exceptions::DataMissing(data =>  __('Username'));
    #    }

    #    my $curpwd = $self->unsafeParam('currentpwd');
    #    if (not $curpwd) {
    #        throw EBox::Exceptions::DataMissing(data =>  __('Password'));
    #    }

    #    my $newpwd1 = $self->unsafeParam('newpwd1');
    #    my $newpwd2 = $self->unsafeParam('newpwd2');
    #    defined($newpwd1) or $newpwd1 = "";
    #    defined($newpwd2) or $newpwd2 = "";

    #    unless (EBox::Auth->checkValidUser($username, $curpwd)) {
    #        throw EBox::Exceptions::External(__('Incorrect '.
    #                    'password.'));
    #    }

    #    unless ($newpwd1 eq $newpwd2) {
    #        throw EBox::Exceptions::External(__('New passwords do'.
    #                    ' not match.'));
    #    }

    #    unless (length($newpwd1) > 5) {
    #        throw EBox::Exceptions::External(__('The password must'.
    #                    ' be at least 6 characters long'));
    #    }
    #    EBox::Auth->setPassword($username, $newpwd1);
    #    $self->{msg} = __('The password was changed successfully.');

    #    my $audit = EBox::Global->modInstance('audit');
    #    $audit->logAction('System', 'General', 'changePassword', $username);
    #}
}

1;
