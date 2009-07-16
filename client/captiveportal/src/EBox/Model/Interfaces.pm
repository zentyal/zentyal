# Copyright
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::CaptivePortal::Model::Interfaces;
#
#   TODO: Document class
#

package EBox::CaptivePortal::Model::Interfaces;

use EBox::Gettext;
use EBox::Validate qw(:all);
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
            'fieldName' => 'interface',
            'printableName' => __('Interface'),
            'editable' => 0,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Interfaces',
        'printableTableName' => __('Interfaces'),
        'modelDomain' => 'CaptivePortal',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'enableProperty' => 1,
        'defaultEnabledValue' => 0,
        'help' => '', # FIXME
    };

    return $dataTable;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#   to pre-add module rows.
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
