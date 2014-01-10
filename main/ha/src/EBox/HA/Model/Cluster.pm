# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Model::Cluster;

# Class: EBox::HA::Model::Cluster
#
#     Model to manage the cluster configuration. Start a new cluster or join to another one.
#

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Composite;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    # TODO: Once it is already configured

    my @fields = (
        new EBox::Types::Union(
            fieldName     => 'configuration',
            printableName => __('Cluster configuration'),
            editable      => 1,
            subtypes      => [
                new EBox::Types::Union::Text(
                    fieldName     => 'start_new',
                    printableName => __('Start a new cluster')
                   ),
                new EBox::Types::Composite(
                    fieldName     => 'join',
                    printableName => __('Join to an existing cluster'),
                    editable      => 1,
                    showTypeName  => 1,
                    types => [
                        new EBox::Types::Host(
                            fieldName     => 'zentyal_host',
                            printableName => __('Zentyal host'),
                            size          => 20,
                            editable      => 1),
                        new EBox::Types::Port(
                            fieldName     => 'zentyal_webadmin_port',
                            printableName => __('WebAdmin port'),
                            editable      => 1,
                            defaultValue  => 443),
                        ],
                   ),
               ]),
        new EBox::Types::Select(
            fieldName     => 'interface',
            printableName => __('Interface for communication'),
            populate      => \&_populateIfaces,
            help          => __('Use a static configured interface is highly recommended'),
            editable      => 1),
       );

    my $dataTable =
    {
        tableName => 'Cluster',
        printableTableName => __('Cluster configuration'),
        defaultActions => [ 'editField' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
        help => __('Configure how this server will start a cluster or it will join to an existing one'),
    };

    return $dataTable;
}

# Group: Subroutines

sub _populateIfaces
{
    my $global  = EBox::Global->instance();
    my $network = $global->modInstance('network');

    my @options;
    foreach my $iface (@{$network->InternalIfaces()}, @{$network->ExternalIfaces()}) {
        push(@options, { value => $iface, printableValue => $iface });
    }
    return \@options;
}

1;
