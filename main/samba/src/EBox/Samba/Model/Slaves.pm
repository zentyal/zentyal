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

# Class: EBox::Samba::Model::Slaves
#
#   This a class holds the list of registered slave machines
#
package EBox::Samba::Model::Slaves;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;
use EBox::Samba::Group;
use EBox::Samba::Slave;

use EBox::Types::Host;
use EBox::Types::Port;

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
        new EBox::Types::Host(
            'fieldName' => 'host',
            'printableName' => __('Slave'),
            'editable' => 1,
            ),
        new EBox::Types::Port(
            'fieldName' => 'port',
            'printableName' => __('Port'),
            'editable' => 1,
            ),
    );

    my $dataTable =
    {
        'tableName' => 'Slaves',
        'printableTableName' => __('Slaves'),
        'defaultActions' => ['changeView', 'editField', 'del'],
        'defaultController' => '/Samba/Controller/Slaves',
        'tableDescription' => \@tableHead,
        'help' => __('List of slave servers for users and groups synchronization.'),
        'printableRowName' => __('slave'),
    };

    return $dataTable;
}

sub precondition
{
    my ($self) = @_;
    my $usersMod = $self->parentModule();
    return $usersMod->mode() eq $usersMod->STANDALONE_MODE();
}

sub deletedRowNotify
{
    my ($self, $row) = @_;
    EBox::Samba::Slave->addRemoval($row->id());
}

1;
