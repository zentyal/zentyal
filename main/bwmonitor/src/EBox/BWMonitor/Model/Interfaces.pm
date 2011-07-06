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

package EBox::BWMonitor::Model::Interfaces;

# Class: EBox::BWMonitor::Model::Interfaces
#
#   Interfaces where bandwidth monitoring is enabled
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );
    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Types::Text(
            'fieldName' => 'interface',
            'printableName' => __('Interface'),
            'editable' => 0,
        ),
    );

    my $dataTable =
    {
        tableName          => 'Interfaces',
        printableTableName => __('Montiored Interfaces'),
        printableRowName   => __('interface'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of monitored interfaces.'),
        modelDomain        => 'BWMonitor',
        enableProperty     => 1,
        defaultEnabledValue => 0,
    };

    return $dataTable;
}


# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
#   Populate table with internal ifaces
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    my $ifaces = EBox::Global->modInstance('network')->InternalIfaces();

    my %currentIfaces = map { $self->row($_)->valueByName('interface') => 1 }
    @{$currentRows};

    # Check if there is any module that has not been added yet
    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @{$ifaces};

    return 0 unless (@ifacesToAdd);

    for my $iface (@ifacesToAdd) {
        $self->add(interface => $iface, enabled => 0);
    }

    return 1;
}


1;
