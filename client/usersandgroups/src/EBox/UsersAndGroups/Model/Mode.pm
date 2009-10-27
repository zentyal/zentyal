# Copyright (C) 2009 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Model::Mode
#
# This class extends <EBox::Common::EnableForm> to be used within the
# DNS module.
#
# We extend it and change its name properly

package EBox::UsersAndGroups::Model::Mode;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Password;

use strict;
use warnings;

# eBox uses

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
        new EBox::Types::Select (
            fieldName => 'mode',
            printableName => __('Mode'),
            options => [
                { 'value' => 'master', 'printableValue' => __('Master') },
                { 'value' => 'slave', 'printableValue' => __('Slave') },
                { 'value' => 'ad-slave', 'printableValue' => __('Windows AD Slave') },
            ],
            editable => 1,
            defaultValue => 'master',
        ),
        new EBox::Types::Host (
            fieldName => 'remote',
            printableName => __('Master host'),
            editable => 1,
            optional => 1,
            help => __('Only for slave configuration: IP of the master eBox or Windows')
        ),
        new EBox::Types::Password (
            fieldName => 'password',
            printableName => __('LDAP password'),
            editable => 1,
            help => __('Master eBox LDAP password')
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
            optional => 1,
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
            optional => 1,
            help => __('Secret key to be shared between Windows and eBox (16 chars)')
        )
    );

    my $dataForm = {
        tableName           => 'Mode',
        printableTableName  => __('eBox users mode'),
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

    my $mode = $allFields->{mode};
    if ($mode->value() eq 'slave') {
        my $remote = $allFields->{remote};
        my $password = $allFields->{password};
        if (($remote->value() eq '') or ($password->value() eq '')) {
            throw EBox::Exceptions::External(__('Missing fields to configure eBox as slave'));
        }
    }
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to enable and disable the 'remote' field
#   depending on the 'mode' value
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { mode =>
                {
                  'master'   => {
                        enable  => [ 'password' ],
                        disable => [ 'remote', 'username', 'adpass', 'port', 'secret' ],
                    },
                  'slave'    => {
                        enable  => [ 'remote', 'password' ],
                        disable => [ 'port', 'username', 'adpass', 'secret' ],
                    },
                  'ad-slave' => {
                        enable  => [ 'remote', 'password', 'username', 'adpass', 'port', 'secret' ],
                    },
                }
            });
    return $customizer;
}

1;
