# Copyright (C) 2009-2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::LdapInfo
#
# This class contains the options needed to enable the usersandgroups module.

use strict;
use warnings;

package EBox::Samba::Model::LdapInfo;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'dcHostname',
            printableName => __('External Active Directory'),
        ),
        new EBox::Types::Text(
            fieldName => 'dn',
            printableName => __('Base DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'rootDn',
            printableName => __('Root DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'password',
            printableName => __('Password'),
        ),
        new EBox::Types::Text (
            fieldName => 'usersDn',
            printableName => __('Default Users DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'groupsDn',
            printableName => __('Default Groups DN'),
        ),
        new EBox::Types::Text(
            fieldName => 'dcUser',
            printableName => __('Administrative user of external active directory'),
        ),
    );

    my $dataForm = {
        tableName           => 'LdapInfo',
        printableTableName  => __('LDAP information'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Samba',
    };

    return $dataForm;
}

sub menuFolder
{
    return 'Users';
}

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    my ($self) = @_;
    my %info;

    my $users = $self->parentModule();
    my $ldap = $users->ldap();

    %info = (
        dn => $ldap->dn(),
    );

    $info{usersDn}   = $users->userClass()->defaultContainer()->dn();
    $info{groupsDn}  = $users->groupClass()->defaultContainer()->dn();

    return \%info;
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

    return $self->parentModule()->isEnabled();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    return __('You must enable the Users and Groups module to access the LDAP information.');
}

1;
