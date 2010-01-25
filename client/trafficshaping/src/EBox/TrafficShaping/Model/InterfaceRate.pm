# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::TrafficShaping::Model::InterfaceRate;

use EBox::Global;
use EBox::Gettext;

use EBox::Types::Int;
use EBox::Types::Text;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

use constant DEFAULT_KB => 16384;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


sub syncRows
{
    my ($self, $currentIds) = @_;

    my $network = EBox::Global->modInstance('network');
    my %currentIfaces = map { $_ => 1 } @{$network->ExternalIfaces()};

    my $anyChange = 0;

    my %storedIfaces;
    for my $id (@{$currentIds}) {
        my $row = $self->row($id);
        next unless ($row);
        my $iface = $row->valueByName('interface');
        if (not exists $currentIfaces{$iface}) {
            $self->removeRow($id);
            $anyChange = 1;
        } else {
            $storedIfaces{$iface} = 1;
        }
    }

    for my $iface (keys %currentIfaces) {
        unless (exists $storedIfaces{$iface}) {
            $anyChange = 1;
            $self->addRow(
                interface => $iface,
                upload => DEFAULT_KB,
                download => DEFAULT_KB
            );
        }
    }

    return 1;
}

sub _table
{
    my @tableHead = (
            new EBox::Types::Text(
                fieldName => 'interface',
                printableName => __('External Interface'),
                size => '4',
            ),
            new EBox::Types::Int(
                fieldName => 'upload',
                printableName => __('Upload'),
                editable => 1,
                size => '4',
                trailingText => 'Kb/s',
                help => __('Upload rate in Kbits/s through this interface')
            ),
            new EBox::Types::Int(
                fieldName => 'download',
                printableName => __('Download'),
                editable => 1,
                size => '4',
                trailingText => 'Kb/s',
                help => __('Upload rate in Kbits/s through this interface')
            )
     );

    my $dataTable =
        {
            tableName => 'InterfaceRate',
            printableTableName => __('External Interface Rates'),
            pageTitle => __('External Interface Rates'),
            defaultController =>
                '/ebox/TrafficShaping/Controller/InterfaceRate',
            defaultActions => [ 'editField', 'changeView' ],
            tableDescription => \@tableHead,
            menuNamespace => 'TrafficShaping/View/InterfaceRate',
            help => __x(''),
            printableRowName => __('rate'),
    };

    return $dataTable;
}

# Method: precondition
#
#   Overrid <EBox::Model::DataTable::precondition>
#
#   Num of external interfaces > 0
sub precondition
{
    my $network = EBox::Global->modInstance('network');
    return ((scalar(@{$network->ExternalIfaces()}) > 0)
            and (scalar(@{$network->InternalIfaces()}) > 0)
    );
}

# Method: preconditionFailMsg
#
#   Overrid <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    return __('You need at least one internal interface and one external interface');
}

1;

