# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::UsersAndGroups::Model::OUs;

# Class: EBox::UsersAndGroups::Model::OUs
#
#       This a class used as a proxy for the OUs present in LDAP.
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

use EBox::Types::Text;
use EBox::UsersAndGroups::OU;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead =
    (
     new EBox::Types::Text(
         'fieldName' => 'dn',
         'printableName' => __('DN'),
         'size' => '12',
         'editable' => 1,
         'allowUnsafeChars' => 1,
         ),
    );

    my $dataTable =
    {
        'tableName' => 'OUs',
        'printableTableName' => __('Organizational Units'),
        'defaultActions'     => ['changeView', 'add', 'del'],
        'modelDomain'        => 'Users',
        'tableDescription'   => \@tableHead,
        'printableRowName'   => __('organizational unit'),
        'sortedBy' => 'dn',
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
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconFail} eq 'notConfigured') {
        return __('You must enable the module Users in the module ' .
                'status section in order to use it.');
    } else {
        my $users = $self->parentModule();
        my $mode = $users->mode();
        if ($mode eq 'master') {
            return __x('There are no users at the moment');
        }
    }
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the users stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    my @ous = map { $_->dn() } @{$users->ous()};
    return \@ous;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the user uid which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $row = $self->_setValueRow(dn => $id);
    $row->setId($id);
    return $row;
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove")
    }

    my $row = $self->row($id);
    if (not defined $row) {
        throw EBox::Exceptions::Internal(
                "Row with id $id does not exist, so it cannot be removed"
                );
    }

    new EBox::UsersAndGroups::OU(dn => $id)->deleteObject();

    $self->setMessage(__x('OU {ou} removed', ou => $id));
}


# Method: addTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::addTypedRow>
#
sub addTypedRow
{
    my ($self, $params_r, %optParams) = @_;

    # Check compulsory fields
    $self->_checkCompulsoryFields($params_r);

    EBox::UsersAndGroups::OU->create($params_r->{dn}->value());

    $self->setMessage(__('OU added'));

    # this is the last row account added and id == pos
    return length($self->ids());
}

1;
