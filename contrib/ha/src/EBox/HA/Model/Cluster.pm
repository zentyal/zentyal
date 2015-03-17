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
no warnings 'experimental::smartmatch';

package EBox::HA::Model::Cluster;

# Class: EBox::HA::Model::Cluster
#
#     Model to manage the cluster configuration. Start a new cluster
#     or join to another one.
#

use base 'EBox::Model::DataForm';

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::RESTClient;
use EBox::Types::Composite;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::View::Customizer;
use TryCatch::Lite;

# Group: Public methods

# Method: viewCustomizer
#
# Overrides:
#
#    <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $actions = {
        configuration => {
            create => {
                show => ['name'],
                hide => ['zentyal_host', 'zentyal_port', 'secret'],
            },
            join => {
                show => ['zentyal_host', 'zentyal_port', 'secret'],
                hide => ['name'],
            },
        },
    };

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions($actions);
    $customizer->setInitHTMLStateOrder(['configuration']);

    return $customizer;
}

# Method: validateTypedRow
#
#    In case of joining, check the given data to join.
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if the secret is not correct
#
sub validateTypedRow
{
    my ($self, $action, $changedParams, $allParams) = @_;

    if ($allParams->{'configuration'}->value() eq 'join') {
        # Check if there is changes in any join param
        my $changeJoinParams = grep { $_ ~~ ['zentyal_host', 'zentyal_port', 'secret'] } keys %{$changedParams};
        if ($changeJoinParams) {
            # Check the given params
            my $client = new EBox::RESTClient(
                credentials => {realm => 'Zentyal HA', username => 'zentyal',
                                password => $allParams->{'secret'}->value() },
                server => $allParams->{'zentyal_host'}->value(),
                verifyPeer => 0,
               );
            $client->setPort($allParams->{'zentyal_port'}->value());
            try {
                $client->GET('/cluster/auth');
            } catch (EBox::Exceptions::Internal $e) {
                # 500/400
                throw EBox::Exceptions::External("$e");
            } catch (EBox::Exceptions::External $e) {
                # 401
                throw EBox::Exceptions::External('Cluster secret is not valid');
            }
        }
    }
}

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

    my @fields = (
        new EBox::Types::Select(
            fieldName     => 'configuration',
            printableName => __('Cluster configuration'),
            editable      => 1,
            populate      => \&_populateConfOpts,
            hidden        => \&_isBootstraped,
        ),
        new EBox::Types::Host(
            fieldName     => 'zentyal_host',
            printableName => __('Cluster host'),
            size          => 20,
            hidden        => \&_isBootstraped,
            editable      => 1),
        new EBox::Types::Port(
            fieldName     => 'zentyal_port',
            printableName => __('Cluster host port'),
            hidden        => \&_isBootstraped,
            editable      => 1,
            defaultValue  => 8443,
       ),
        new EBox::Types::Text(
            fieldName     => 'secret',
            printableName => __('Cluster secret'),
            editable      => 1,
            size          => 32,
            hidden        => \&_isBootstraped,
           ),
        new EBox::Types::Text(
            fieldName     => 'name',
            printableName => __('Cluster name'),
            editable      => 1,
            size          => 20,
            defaultValue  => 'my cluster',
            hidden        => \&_isBootstraped,
           ),
        new EBox::Types::Select(
            fieldName     => 'interface',
            printableName => __('Choose network interface'),
            populate      => \&_populateIfaces,
            help          => __('It will be used as communication channel between the cluster members.'),
            editable      => 1),
    );

    my $helpMsg = __('Configure how this server will start a cluster or it will join to an existing one');
    if (_isBootstraped()) {
        $helpMsg = __('If you change any setting, you may suffer a service cluster disruption,');
    }

    my $dataTable =
    {
        tableName => 'Cluster',
        printableTableName => __('Cluster configuration'),
        defaultActions => [ 'editField', 'changeView' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
        help => $helpMsg,
    };

    return $dataTable;
}

# Group: Subroutines

sub _populateConfOpts
{
    return [
        { value => 'create', printableValue => __('Create a new cluster') },
        { value => 'join', printableValue => __('Join this node to an existing cluster') }
       ];
}

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

sub _isBootstraped
{
    my $ha = EBox::Global->getInstance()->modInstance('ha');
    return $ha->clusterBootstraped();
}

1;
