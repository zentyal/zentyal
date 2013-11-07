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

use strict;
use warnings;

package EBox::Ntop::Model::Interfaces;

# Class: EBox::Ntop::Model::Interfaces
#
#     Define the interfaces to monitor. If all are selected, then any
#     is returned.
#

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Boolean;
use EBox::Types::Text;

# Group: Public methods

# Method: syncRows
#
#    Override to set the interfaces to monitor depending on the
#    returned value of ntopng -h.
#
# Overrides:
#
#    <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my %currentIfaces = map { $self->row($_)->valueByName('iface') => 1 } @{$currentRows};

    my $output = EBox::Sudo::root(q{/usr/local/bin/ntopng -h | grep -P '^\s+\d+\.'});
    my @newIfaces;
    foreach my $line (@{$output}) {
        my ($iface) = $line =~ m/\s+\d+\.\s(.*)$/;
        push(@newIfaces, $iface) unless ($iface eq 'any');
    }
    my %newIfaces = map { $_ => 1 } @newIfaces;

    my $modified = 0;

    # Add new ones
    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @newIfaces;
    foreach my $iface (@ifacesToAdd) {
        $self->add(iface => $iface);
        $modified = 1;
    }

    # Remove old ones
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $ifaceName = $row->valueByName('iface');
        next if exists $newIfaces{$ifaceName};
        $self->removeRow($id);
        $modified = 1;
    }

    return $modified;
}

# Method: ifacesToMonitor
#
#    Get the network interfaces to monitor
#
# Returns:
#
#    Array ref - the network interfaces to monitor. any is returned if
#    all are selected (default)
#
sub ifacesToMonitor
{
    my ($self) = @_;

    my $allEnabled = 1;
    my @ifaces;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($row->valueByName('enabled')) {
            push(@ifaces, $row->valueByName('iface'));
        } else {
            $allEnabled = 0;
        }
    }
    return [ 'any' ] if ($allEnabled);
    return \@ifaces;
}


# Group: Protected methods

# Method: _table
#
#    Set model description
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHead =
     (
         new EBox::Types::Text(
             fieldName     => 'iface',
             printableName => __('Interface'),
             unique        => 1,
             editable      => 0,
            ),
        );

    my $dataTable =
      {
            'tableName'           => __PACKAGE__->nameFromClass(),
            'printableTableName'  => __('Interfaces to monitor'),
            'automaticRemove'     => 1,
            'defaultController'   => '/Ntop/Controller/Interfaces',
            'defaultActions'      => [ 'editField', 'changeView' ],
            'checkAll'            => [ 'enabled' ],
            'enableProperty'      => 1,
            'defaultEnabledValue' => 1,
            'tableDescription'    => \@tableHead,
            'menuNamespace'       => 'Ntop/View/Interfaces',
            'class'               => 'dataTable',
            'help' => __x('If all selected, then any traffic is monitorised'),
            'printableRowName'    => __('interface'),
        };

    return $dataTable;
}

1;
