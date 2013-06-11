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

package EBox::TrafficShaping::Model::SmallPacketPriorization;

use base 'EBox::Model::DataForm';

use EBox::Gettext;

use EBox::Types::Boolean;

sub _table
{
    my @fields = (
        new EBox::Types::Boolean(
            fieldName => 'ack',
            printableName => 'ACK',
            defaultValue => 0,
            editable => 1,
        ),
        new EBox::Types::Boolean(
            fieldName => 'syn',
            printableName =>'SYN',
            defaultValue => 0,
            editable => 1,
        ),
        new EBox::Types::Boolean(
            fieldName => 'fin',
            printableName => 'FIN',
            defaultValue => 0,
            editable => 1,
        ),
        new EBox::Types::Boolean(
            fieldName => 'rst',
            printableName => 'RST',
            defaultValue => 0,
            editable => 1,
        ),
    );

    my $dataTable = {
        tableName => 'SmallPacketPriorization',
        printableTableName => __('Prioritize small packets with these control flags'),
        defaultActions => ['editField', 'changeView'],
        tableDescription => \@fields,
        modelDomain => 'TrafficShaping',
        menuNamespace => 'TrafficShaping/View/SmallPacketPriorization',
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

1;
