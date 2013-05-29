# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::UsersAndGroups::Model::Contact
#
#   This model is used to edit a contact
#

use strict;
use warnings;

package EBox::UsersAndGroups::Model::Contact;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Text;

sub _table
{
    my @fields = (
        new EBox::Types::Text(
            fieldName     => 'firstName',
            printableName => __('First name'),
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'initials',
            printableName => __('Initials'),
            size          => '6',
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'surname',
            printableName => __('Last name'),
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'fullName',
            printableName => __('Full name'),
            unique        => 1,
            editable      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'displayName',
            printableName => __('Display name'),
            editable      => 1,
            optional      => 1,
        ),
    );

    my $dataTable =
    {
        tableName => 'Contacts',
        pageTitle => __('Contact edition'),
        printableTableName => __('Administration of contact'),
        printableRowName => __('Contact'),
        defaultActions => ['editField', 'changeView'],
        tableDescription => \@fields,
        modelDomain => 'Contact',
    };

    return $dataTable;
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return id from the request.
#
sub ids
{
    my ($self) = @_;
    my $global = $self->global();
    my $users = $global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    return [$self->{contact}->dn()];
}

# Method: setTypedRow
#
#      Set the values for a single existing row using typed parameters
#
# Parameters:
#
#      id - String the row identifier
#
#      paramsRef - hash ref Containing the parameter to set. You can
#      update your selected values. Indexed by field name.
#
#      force - Boolean indicating if the update is forced or not
#      *(Optional)* Default value: false
#
#      readOnly - Boolean indicating if the row becomes a read only
#      kind one *(Optional)* Default value: false
#
#     - Optional parameters are NAMED
#
# Exceptions:
#
#      <EBox::Exceptions::Base> - thrown if the update cannot be done
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $contact = $self->{contact};

    if (not $self->_rowStored()) {
        # first set the default row to be sure we have all the defaults
        my $row = $self->_defaultRow();
        $self->SUPER::addTypedRow(
            $row->{'valueHash'},
            id => $contact->dn(),
            noOrder => 1,
            noValidateRow => 1,
        );
    }

    $contact->set('cn', $paramsRef->{fullName}->value(), 1) if ($paramsRef->{fullName});
    $contact->set('givenName', $paramsRef->{firstName}->value(), 1) if ($paramsRef->{firstName});
    $contact->set('initials', $paramsRef->{initials}->value(), 1) if ($paramsRef->{initials});
    $contact->set('sn', $paramsRef->{surname}->value(), 1) if ($paramsRef->{surname});
    $contact->set('displayName', $paramsRef->{displayName}->value(), 1) if ($paramsRef->{displayName});

    $contact->save();
    $self->setMessage(__('Contact saved'));
}

1;
