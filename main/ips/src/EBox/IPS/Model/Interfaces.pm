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

use strict;
use warnings;

package EBox::IPS::Model::Interfaces;

use base 'EBox::Model::DataTable';

# Class: EBox::IPS::Model::Interfaces
#
#   Class description
#

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::IPS::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifaces = $net->ifaces();
    my %newIfaces =
        map { $_ => 1 } @{$ifaces};
    my %currentIfaces =
        map { $self->row($_)->valueByName('iface') => 1 } @{$currentRows};

    my $modified = 0;

    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @{$ifaces};
    foreach my $iface (@ifacesToAdd) {
        $self->add(iface => $iface, enabled => 0);
        $modified = 1;
    }

    # Remove old rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $ifaceName = $row->valueByName('iface');
        next if exists $newIfaces{$ifaceName};
        $self->removeRow($id);
        $modified = 1;
    }

    return $modified;
}

# Method: headTitle
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
}

# Group: Protected methods

# Method: _table
#
#       Model description
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Text(
            'fieldName' => 'iface',
            'printableName' => __('Interface'),
            'unique' => 1,
            'editable' => 0),
        new EBox::Types::Boolean (
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'defaultValue' => 0,
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'Interfaces',
        printableTableName => __('Interfaces'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'IPS',
        sortedBy           =>    'iface',
        printableRowName   => __('interface'),
        help               =>
     __('Select in which interfaces IPS system will be enabled'),
    };
    return $dataTable;
}

1;
