# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::UsersAndGroups::Model::Contacts
#
package EBox::UsersAndGroups::Model::Contacts;
use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Types::Text;
use EBox::Types::Link;
use EBox::UsersAndGroups::Contact;

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
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
            optional      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'displayName',
            printableName => __('Display name'),
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Link(
            fieldName               => 'edit',
            printableName           => __('Edit'),
        ),
    );

    my $dataTable =
    {
        tableName => 'Contacts',
        pageTitle => __('Contacts'),
        printableTableName => __('Contacts Handling'),
        printableRowName => __('Contact'),
        defaultActions => ['add', 'del', 'changeView'],
        tableDescription => \@fields,
        modelDomain => 'Users',
        enabledProperty => 0,
        sortedBy => 'fullName',
    };

    return $dataTable;
}

# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        $self->{preconFail} = 'notConfigured';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconFail} eq 'notConfigured') {
        return __('You must enable the module Users in the module status section in order to use it.');
    }
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers based on the contacts stored in LDAP
#
sub ids
{
    my ($self) = @_;
    my $global = $self->global();
    my $users = $global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    my @list = map { $_->dn() } @{$users->contacts()};

    return \@list;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the user uid which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $contact = new EBox::UsersAndGroups::Contact(dn => $id);
    if ($contact->exists()) {
        my %args = ();
        $args{firstName} = $contact->firstname() if ($contact->firstname());
        $args{initials} = $contact->initials() if ($contact->initials());
        $args{surname} = $contact->surname() if ($contact->surname());
        $args{fullName} = $contact->fullname() if ($contact->fullname());
        $args{displayName} = $contact->displayname() if ($contact->displayname());
        $args{edit} = "/UsersAndGroups/Contact?contact=$id";

        my $row = $self->_setValueRow(%args);
        $row->setId($id);
        return $row;
    } else {
        use Devel::StackTrace;
        my $trace = Devel::StackTrace->new;
        EBox::debug($trace->as_string);
        throw EBox::Exceptions::Internal("Contact $id does not exist");
    }
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("Missing row identifier to remove")
    }

    my $row = $self->row($id);
    if (not defined $row) {
        throw EBox::Exceptions::Internal("Row with id $id does not exist, so it cannot be removed");
    }

    new EBox::UsersAndGroups::Contact(dn => $id)->deleteObject();

    $self->setMessage(__x('Contact {contact} removed', contact => $id));
    $self->deletedRowNotify($row, $force);

}

# Method: addTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::addTypedRow>
#
sub addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my %args = ();
    $args{givenname} = $paramsRef->{firstName}->value() if ($paramsRef->{firstName});
    $args{initials} = $paramsRef->{initials}->value() if ($paramsRef->{initials});
    $args{surname} = $paramsRef->{surname}->value() if ($paramsRef->{surname});
    $args{fullname} = $paramsRef->{fullName}->value() if ($paramsRef->{fullName});
    $args{displayname} = $paramsRef->{displayName}->value() if ($paramsRef->{displayName});

    my $contact = EBox::UsersAndGroups::Contact->create(\%args);

    $self->setMessage(__('Contact added'));

    # this is the last row account added and id == pos
    return $contact->{dn};
}

1;
