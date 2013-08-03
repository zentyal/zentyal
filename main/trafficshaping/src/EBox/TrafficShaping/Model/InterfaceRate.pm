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

package EBox::TrafficShaping::Model::InterfaceRate;

use base 'EBox::Model::DataTable';

use EBox::Gettext;

use EBox::Types::Int;
use EBox::Types::Text;

use constant DEFAULT_KB => 16384;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: syncRows
#
# Overrides:
#
#      <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my $network = $self->global()->modInstance('network');
    my %currentIfaces = map { $_ => 1 } @{$network->ExternalIfaces()};

    my $anyChange = 0;

    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        next unless ($row);
        my $iface = $row->valueByName('interface');
        if (not exists $currentIfaces{$iface}) {
            $self->removeRow($id, 1);
            $anyChange = 1;
        } else {
            delete $currentIfaces{$iface};
        }
    }

    foreach my $iface (keys %currentIfaces) {
        $anyChange = 1;
        $self->addRow(
            interface => $iface,
            upload => DEFAULT_KB,
            download => DEFAULT_KB
           );
    }

    return $anyChange;
}

# Method: headTitle
#
#   Overrid <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
}

sub _table
{
    my @tableHead = (
            new EBox::Types::Text(
                fieldName => 'interface',
                printableName => __('External Interface'),
                size => '4',
                unique => 1,
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
                help => __('Download rate in Kbits/s through this interface')
            )
     );

    my $dataTable =
        {
            tableName => 'InterfaceRate',
            printableTableName => __('External Interface Rates'),
            pageTitle => __('Traffic Shaping'),
            defaultController =>
                '/TrafficShaping/Controller/InterfaceRate',
            defaultActions => [ 'editField', 'changeView' ],
            tableDescription => \@tableHead,
            menuNamespace => 'TrafficShaping/View/InterfaceRate',
            #help => __x(''),
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
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
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

    return __x('Traffic Shaping is applied when Zentyal is acting as '
                   . 'a gateway.'
                   . q{ To achieve so, you'd need, at least, one internal and one external interface.}
                   . ' Check your interface '
                   . 'configuration to match, at '
                   . '{openhref}Network->Interfaces{closehref}',
               openhref  => '<a href="/Network/Ifaces">',
               closehref => '</a>');
}

sub totalDownloadRate
{
    my ($self) = @_;
    my $sumDownload = 0;

    foreach my $id (@{$self->ids()}) {
        $sumDownload += $self->row($id)->valueByName('download');
    }

    return $sumDownload;
}

1;
