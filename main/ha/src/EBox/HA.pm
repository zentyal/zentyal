# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::HA
#
#    HA module is responsible to have Zentyal server in a cluster.
#
#    It manages the cluster membership configuration (corosync) and
#    cluster resource managing (pacemaker)
#

package EBox::HA;

use base qw(EBox::Module::Service);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::HA::NodeList;
use EBox::RESTClient;
use EBox::Sudo;
use JSON::XS;

# Constants
use constant {
    COROSYNC_CONF_FILE => '/etc/corosync/corosync.conf',
    DEFAULT_MCAST_PORT => 5405,
};

# Constructor: _create
#
# Overrides:
#
#       <Ebox::Module::Base::_create>
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(
        name => 'ha',
        printableName => __('High Availability'),
        @_
    );

    bless ($self, $class);

    return $self;
}

# Group: Public methods

# Method: menu
#
#       Set HA conf under System menu entry
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $system = new EBox::Menu::Folder(
            'name' => 'SysInfo',
            'text' => __('System'),
            'order' => 30
           );

    my $menuURL = 'HA/Composite/Initial';
    if ($self->clusterBootstraped()) {
        $menuURL = 'HA/Composite/Configuration';
    }

    $system->add(new EBox::Menu::Item(
        url => $menuURL,
        text => $self->printableName(),
        separator => 'Core',
        order => 50,
    ));

    $root->add($system);
}

# Method: widgets
#
#   Display the node list
#
# Overrides:
#
#    <EBox::Module::Base::widgets>
#
sub widgets
{
    return {
        'nodelist' => {
            'title' => __("Cluster nodes"),
            'widget' => \&nodeListWidget,
            'order' => 5,
            'default' => 1
        }
    };
}

# Method: clusterBootstraped
#
#     Return if the cluster was bootstraped
#
# Returns:
#
#     Boolean - true if the cluster was bootstraped once
#
sub clusterBootstraped
{
    my ($self) = @_;

    return $self->model('ClusterState')->bootstrapedValue();
}

# Method: clusterConfiguration
#
#     Return the cluster configuration
#
# Returns:
#
#     Hash ref - the cluster configuration, if bootstrapped
#
#        - name: String the cluster name
#        - transport: String 'udp' for multicast and 'udpu' for unicast
#        - multicastConf: Hash ref with addr, port and expected_votes as keys
#        - nodes: Array ref the node list including IP address, name and webadmin port
#
#     Empty hash ref if the cluster is not bootstraped.
#
sub clusterConfiguration
{
    my ($self) = @_;

    my $state = $self->get_state();
    if ($self->clusterBootstraped()) {
        my $transport = $state->{cluster_conf}->{transport};
        my $multicastConf = $state->{cluster_conf}->{multicast};
        my $nodeList = new EBox::HA::NodeList($self)->list();
        if ($transport eq 'udp') {
            $multicastConf->{expected_votes} = scalar(@{$nodeList});
        } elsif ($transport eq 'udpu') {
            $multicastConf = {};
        }
        return {
            name          => $self->model('Cluster')->nameValue(),
            transport     => $transport,
            multicastConf => $multicastConf,
            nodes         => $nodeList
        };
    } else {
        return {};
    }
}

# Method: updateClusterConfiguration
#
#    Update cluster configuration after a change in other node of the cluster
#
# Parameters:
#
#    params - nothing
#    body   - Hash ref new cluster configuration from another node in the cluster
#
sub updateClusterConfiguration
{
    my ($self, $params, $body) = @_;

    # FIXME: TODO
}

# Method: leaveCluster
#
#    Leave the cluster by setting the cluster not boostraped
#
sub leaveCluster
{
    my ($self) = @_;

    my $row = $self->model('ClusterState')->row();
    $row->elementByName('bootstraped')->setValue(0);
    $row->elementByName('leaveRequest')->setValue(1);
    $row->store();
}

# Method: nodes
#
#     Get the active nodes from a cluster
#
# Returns:
#
#     Array ref - See <EBox::HA::NodeList::list> for details
#
sub nodes
{
    my ($self) = @_;

    return new EBox::HA::NodeList($self)->list();
}

# Method: addNode
#
#     Add a node to the cluster
#
# Parameters:
#
#     params - <Hash::MultiValue>, see <EBox::HA::NodeList::set> for details
#     body   - Decoded content from JSON request
#
sub addNode
{
    my ($self, $params, $body) = @_;

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    $params->{localNode} = 0;  # Local node is always set manually
    $list->set(%{$body});
}

# Method: deleteNode
#
#    Delete node from the cluster
#
# Parameters:
#
#    params - hash ref containing the node to delete in the key 'name'
#
# Returns:
#
#     Array ref - See <EBox::HA::NodeList::list> for details
#
sub deleteNode
{
    my ($self, $params) = @_;

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    $list->remove($params->{name});
}

# Group: Protected methods

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    # Order is *very* important here
    my $daemons = [
       {
           name => 'corosync',
           type => 'init.d',
           pidfiles => ['/run/corosync.pid']
       },
       {
           name => 'pacemaker',
           type => 'init.d',
           pidfiles => ['/run/pacemakerd.pid']
       }
    ];

    return $daemons;
}

# Method: _setConf
#
# Overrides:
#
#       <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    if ($self->model('ClusterState')->leaveRequestValue()) {
        # TODO: Notify to other cluster members
        $self->model('ClusterState')->setValue('leaveRequest', 0);
    }

    $self->_corosyncSetConf();
    if ($self->global()->modIsChanged($self->name())) {
        $self->saveConfig();
    }
}

# Group: subroutines

sub nodeListWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('nodelist');
    $widget->add($section);
    my $titles = [__('Host name'),__('IP address')];

    my $list = new EBox::HA::NodeList(EBox::Global->getInstance()->modInstance('ha'))->list();

    my @ids = map { $_->{name} } @{$list};
    my %rows = map { $_->{name} => [$_->{name}, $_->{addr}] } @{$list};

    $section->add(new EBox::Dashboard::List(undef, $titles, \@ids, \%rows,
                                            __('Cluster is not configured')));
}

# Group: Private methods

# Corosync configuration
sub _corosyncSetConf
{
    my ($self) = @_;

    my $clusterSettings = $self->model('Cluster');

    # Calculate the localnetaddr
    my $iface = $clusterSettings->interfaceValue();
    my $network = EBox::Global->getInstance()->modInstance('network');
    my $ifaces = [ { iface => $iface, netAddr => $network->ifaceNetwork($iface) }];
    my $localNodeAddr = $network->ifaceAddress($iface);
    if (ref($localNodeAddr) eq 'ARRAY') {
        $localNodeAddr = $localNodeAddr->[0];  # Take the first option
    }
    unless ($localNodeAddr) {
        throw EBox::Exceptions::External(__x('{iface} does not have IP address to use',
                                             iface => $iface));
    }

    # Do bootstraping, if required
    unless ($self->clusterBootstraped()) {
        my $hostname = $self->global()->modInstance('sysinfo')->hostName();
        if ($clusterSettings->configurationValue() eq 'create') {
            $self->_bootstrap($localNodeAddr, $hostname);
        }
    }

    my $list = new EBox::HA::NodeList($self);
    my $localNode = $list->localNode();
    if ($localNodeAddr ne $localNode->{addr}) {
        $list->set(name => $localNode->{name}, addr => $localNodeAddr,
                   webAdminPort => 443, localNode => 1);
        # TODO: Notify to other peers
    }

    my $clusterConf = $self->clusterConfiguration();
    my @params = (
        interfaces    => $ifaces,
        nodes         => $clusterConf->{nodes},
        transport     => $clusterConf->{transport},
        multicastConf => $clusterConf->{multicastConf},
    );

    $self->writeConfFile(
        COROSYNC_CONF_FILE,
        "ha/corosync.conf.mas",
        \@params,
        { uid => '0', gid => '0', mode => '644' }
    );
}

# Bootstrap a cluster
#  * Start node list
#  * Store the transport method in State
#  * Store the cluster as bootstraped
sub _bootstrap
{
    my ($self, $localNodeAddr, $hostname) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    # TODO: set port
    $nodeList->empty();
    $nodeList->set(name => $hostname, addr => $localNodeAddr, webAdminPort => 443,
                   localNode => 1);

    # Store the transport and its configuration in state
    my $state = $self->get_state();

    my ($multicastConf, $transport);
    my $multicastAddr = EBox::Config::configkey('ha_multicast_addr');
    if ($multicastAddr) {
        # Multicast configuration
        my $multicastPort = EBox::Config::configkey('ha_multicast_port') || DEFAULT_MCAST_PORT;
        $multicastConf = { addr => $multicastAddr,
                           port => $multicastPort,
                          };
        $transport = 'udp';
    } else {
        # Unicast configuration
        $transport = 'udpu';
    }
    $state->{cluster_conf}->{transport} = $transport;
    $state->{cluster_conf}->{multicast} = $multicastConf;

    # Finally, store it in Redis
    $self->set_state($state);

    # Set as bootstraped
    $self->model('ClusterState')->setValue('bootstraped', 1);
}

1;
