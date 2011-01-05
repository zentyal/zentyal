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

# Class: EBox::UsersAndGroups::Model::ADSyncSettings
#
# AD Sync options that can be changed at any moment and are not
# needed to enable the usersandgroups module.

package EBox::UsersAndGroups::Model::ADSyncSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Port;
use EBox::Types::Password;
use EBox::Types::Boolean;

use strict;
use warnings;

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{

    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Boolean (
            fieldName => 'enableADsync',
            printableName => __('Enable AD sync'),
            defaultValue => 1,
            editable => 1,
            help => __('Enable AD syncronization.')
        ),
        new EBox::Types::Text (
            fieldName => 'username',
            printableName => __('AD user'),
            defaultValue => 'eboxadsync',
            editable => 1,
            help => __('Username for binding to Windows AD (it has to be created in the AD)')
        ),
        new EBox::Types::Password (
            fieldName => 'adpass',
            printableName => __('AD password'),
            editable => 1,
            help => __('Password for the above user')
        ),
        new EBox::Types::Port (
            fieldName => 'port',
            printableName => __('Listen port'),
            defaultValue => '6677',
            editable => 1,
            help => __('Port for listening password sync notifications from Windows')
        ),
        new EBox::Types::Password (
            fieldName => 'secret',
            printableName => __('AD Secret Key'),
            editable => 1,
            size => 16,
            help => __('Secret key to be shared between Windows and Zentyal (16 chars)')
        ),
    );

    my $dataForm = {
        tableName           => 'ADSyncSettings',
        printableTableName  => __('Windows AD Sync Settings'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

# Method: validateTypedRow
#
# Overrides:
#
#     <EBox::Model::DataForm::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{secret}) {
        my $secret = $changedFields->{secret};
        if (length($secret) < 16) {
            throw EBox::Exceptions::External(__('The secret key needs to have 16 characters.'));
        }
    }
}

1;
