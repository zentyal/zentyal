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

package EBox::UsersAndGroups::Model::Slaves;

# Class: EBox::UsersAndGroups::Model::Slaves
#
#	This model is used to list the slaves that are subscribed to this master
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;


use EBox::Types::Text;

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
             'fieldName' => 'slave',
             'printableName' => __('Slave'),
             'size' => '12',
             ),
         new EBox::Types::Int(
             'fieldName' => 'port',
             'printableName' => __('Port'),
             ),
        );

    my $dataTable =
    {
        'tableName' => 'Slaves',
        'printableTableName' => __('List of slaves'),
        'defaultController' =>
            '/ebox/Users/Controller/Slaves',
        'defaultActions' =>
            ['changeView', 'del'],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'UsersAndGroups/Slaves',
        'help' => __x('This is a list of those Zentyal slaves which are subscribed to this Zentyal.'),
        'printableRowName' => __('slave'),
        'sortedBy' => 'name',
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
    unless ($users->configured() and ($users->mode() ne 'slave')) {
        $self->{preconFail} = 'notConfigured';
        return undef;
    }

    unless (@{$users->listSlaves()}) {
        $self->{preconFail} = 'noSlaves';
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
        return __('You must enable the module Users in master mode.');
    } else {
        return __('There are no slaves at the moment.');

    }
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the slaves stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    my @slaves = map { $_->{'hostname'} } @{$users->listSlaves()};

    return \@slaves;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the user uid which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $users = EBox::Global->modInstance('users');
    my $slaves = $users->listSlaves();
    my $port;
    for my $slave (@{$slaves}) {
        if ($slave->{'hostname'} eq $id) {
            $port = $slave->{'port'};
        }
    }

    my $row = $self->_setValueRow(slave => $id, port => $port);
    $row->setId($id);
    $row->setReadOnly(0);
    return $row;
}

# Method: removeRow
#
#   Override <EBox::Model::DataTable::removeRow>
#   to remove a slave
#
sub removeRow
{
	my ($self, $id) = @_;

        my $users = EBox::Global->modInstance('users');
        $users->deleteSlave($id);
}

sub Viewer
{
    return '/ajax/tableBodyWithoutEdit.mas';
}

1;
