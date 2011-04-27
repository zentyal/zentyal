# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::Virt::Model::VirtualMachines;

# Class: EBox::Virt::Model::VirtualMachines
#
#      Table of Virtual Machines
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
# TODO: EBox::Types::ActionButton

# Group: Public methods

# Constructor: new
#
#       Create the new VirtualMachines model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Virt::Model::VirtualMachines> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
       # FIXME: ActionButton Start/Stop
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Name'),
                             size          => 16,
                             unique        => 1,
                             editable      => 1,
                            ),
       new EBox::Types::HasMany(
                                fieldName     => 'settings',
                                printableName => __('Settings'),
                                foreignModel  => 'virt/VMSettings',
                                foreignModelIsComposite => 1,
                                view => '/zentyal/Virt/Composite/VMSettings',
                                backView => '/zentyal/Virt/View/VirtualMachines',
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'autostart',
                                printableName => __('Start on boot'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
    );

    my $dataTable =
    {
        tableName          => 'VirtualMachines',
        printableTableName => __('List of Virtual Machines'),
        pageTitle          => __('Virtual Machines'),
        printableRowName   => __('virtual machine'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of configured Virtual Machines.'),
        modelDomain        => 'Virt',
        enableProperty => 1,
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

1;
