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
# This class contains the options needed to enable the usersandgroups module.

package EBox::UsersAndGroups::Model::LdapInfo;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;

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

    $self->{'users'} = EBox::Global->modInstance('users');

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
        new EBox::Types::Text(
            fieldName => 'dn',
            printableName => __('Base DN'),
            volatile => 1,
            acquirer => \&_acquirer
        ),
        new EBox::Types::Text (
            fieldName => 'password',
            printableName => __('Password'),
            volatile => 1,
            acquirer => \&_acquirer
        ),
        new EBox::Types::Text (
            fieldName => 'usersDn',
            printableName => __('Users DN'),
            volatile => 1,
            acquirer => \&_acquirer
        ),
        new EBox::Types::Text (
            fieldName => 'groupsDn',
            printableName => __('Groups DN'),
            volatile => 1,
            acquirer => \&_acquirer
        ),
    );

    my $dataForm = {
        tableName           => 'LdapInfo',
        printableTableName  => __('LDAP Info'),
        pageTitle           => __('LDAP Information'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

sub _acquirer
{
    my ($type) = @_;

    my $model = $type->model();
    ($model and $model->precondition()) or return '';

    if ($type->fieldName() eq 'dn') {
        return $model->{'users'}->ldap()->dn();
    } elsif ($type->fieldName() eq 'password') {
        return $model->{'users'}->ldap()->getPassword();
    } elsif ($type->fieldName() eq 'usersDn') {
        return $model->{'users'}->usersDn();
    } elsif ($type->fieldName() eq 'groupsDn') {
        return $model->{'users'}->groupsDn();
    } else {
        return '';
    }
}

# Method: precondition
#
#   Check if usersandgroups is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->{'users'}->isEnabled();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    return __('You must enable the Users and Groups module to access the LDAP information');
}

1;
