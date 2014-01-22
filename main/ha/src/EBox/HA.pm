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
#    It manages the cluster membership configuration (corosync),
#    cluster resource managing (pacemaker) and the layer for conf
#    replication and corosync synchronisation (PSGI server).
#

package EBox::HA;

use base qw(EBox::Module::Service);

use feature qw(switch);

use Data::Dumper;
use EBox::Config;
use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::HA::NodeList;
use EBox::RESTClient;
use EBox::Sudo;
use JSON::XS;
use TryCatch::Lite;

# Constants
use constant {
    COROSYNC_CONF_FILE    => '/etc/corosync/corosync.conf',
    COROSYNC_DEFAULT_FILE => '/etc/default/corosync',
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

# Method: usedFiles
#
# Overrides:
#
#      <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        { 'file'   => COROSYNC_CONF_FILE,
         'reason' => __('To configure corosync daemon'),
         'module' => 'ha' },
        { 'file'   => COROSYNC_DEFAULT_FILE,
         'reason' => __('To start corosync at boot'),
         'module' => 'ha' },
    ];
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

    return ($self->model('ClusterState')->bootstrapedValue() == 1);
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
#     Add a node to the cluster.
#
#     * Store the new node
#     * Send info to other members of the cluster
#     * Write corosync conf
#     * Dynamically add the new node
#
# Parameters:
#
#     params - <Hash::MultiValue>, see <EBox::HA::NodeList::set> for details
#     body   - Decoded content from JSON request
#
sub addNode
{
    my ($self, $params, $body) = @_;

    EBox::info('Add node (params): ' . Dumper($params));

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    $params->{localNode} = 0;  # Local node is always set manually
    $list->set(%{$params});

    # Write corosync conf
    $self->_corosyncSetConf();

    if ($self->_isDaemonRunning('corosync')) {
        if ($self->_multicast()) {
            # Multicast
            my $expectedVotes = $list->size();
            EBox::Sudo::root("corosync-quorumtool -e $expectedVotes");
        } else {
            my $newNode = $list->node($params->{name});
            $self->_addCorosyncNode($newNode);
        }
    }

    try {
        # Notify to other cluster nodes skipping the new added node
        $self->_notifyClusterConfChange($list, [$params->{name}]);
    } catch ($e) {
        EBox::error("Notifying cluster conf change: $e");
    }
}

# Method: deleteNode
#
#    Delete node from the cluster.
#
#    * Delete the node
#    * Send cluster configuration to other members
#    * Write corosync conf
#    * Dynamically add the new node
#
# Parameters:
#
#    params - <Hash::MultiValue> containing the node to delete in the
#             key 'name'
#
# Returns:
#
#     Array ref - See <EBox::HA::NodeList::list> for details
#
sub deleteNode
{
    my ($self, $params) = @_;

    EBox::info('delete node (params): ' . Dumper($params));

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    my $deletedNode = $list->node($params->{name});
    $list->remove($params->{name});

    # Write corosync conf
    $self->_corosyncSetConf();

    if ($self->_isDaemonRunning('corosync')) {
        if ($self->_multicast()) {
            # Multicast
            my $expectedVotes = $list->size();
            EBox::Sudo::root("corosync-quorumtool -e $expectedVotes");
        } else {
            # Dynamically remove the new node to corosync
            $self->_deleteCorosyncNode($deletedNode);
        }
    }

    # Notify to other cluster nodes skipping the new added node
    try {
        $self->_notifyClusterConfChange($list);
    } catch ($e) {
        EBox::error("Notifying cluster conf change: $e");
    }
}

# Method: updateClusterConfiguration
#
#    Update cluster configuration after a change in other node of the cluster
#
# Parameters:
#
#    params - <Hash::MultiValue> see <clusterConfiguration> for details
#    body   - Decoded content from JSON request
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if the cluster is not bootstraped
sub updateClusterConfiguration
{
    my ($self, $params, $body) = @_;

    EBox::info('Update cluster conf (body): ' . Dumper($body));

    # TODO: Check incoming data
    unless ($self->clusterBootstraped()) {
        throw EBox::Exceptions::Internal('Cannot a non-bootstraped module');
    }

    my $state = $self->get_state();
    my $currentClusterConf = $state->{cluster_conf};
    unless (($currentClusterConf->{transport} eq $body->{transport})
            and (($currentClusterConf->{multicast} ~~ $body->{multicastConf})
                 or (not(defined($currentClusterConf->{multicast})) and $body->{multicastConf} ~~ {}))
           ) {
        EBox::warn('Change in multicast or transport is not supported');
    }

    # Update name if required
    my $clusterRow = $self->model('Cluster')->row();
    if ($body->{name} ne $clusterRow->valueByName('name')) {
        EBox::info("Updating cluster name to " . $body->{name});
        $clusterRow->elementByName('name')->setValue($body->{name});
        $clusterRow->storeElementByName('name');
        $self->saveConfig();
    }

    my $list = new EBox::HA::NodeList($self);
    my ($equal, $diff) = $list->diff($body->{nodes});
    unless ($equal) {
        my %currentNodes = map { $_->{name} => $_ } @{$list->list()};
        my %nodes = map { $_->{name} => $_ } @{$body->{nodes}};
        # Update NodeList
        foreach my $nodeName (@{$diff->{new}}, @{$diff->{changed}}) {
            my $node = $nodes{$nodeName};
            $node->{localNode} = 0;  # Supposed the notifications
                                     # never comes from self
            $list->set(%{$node});
        }
        foreach my $nodeName (@{$diff->{old}}) {
            $list->remove($nodeName);
        }

        # Store conf to apply between restarts
        $self->_corosyncSetConf();
        if ($self->_isDaemonRunning('corosync')) {
            if ($self->_multicast()) {
                # Multicast
                unless (scalar(keys(%currentNodes)) == scalar(keys(%nodes))) {
                    my $expectedVotes = $list->size();
                    EBox::Sudo::root("corosync-quorumtool -e $expectedVotes");
                }
            } else {
                foreach my $changedNodeName (@{$diff->{changed}}) {
                    if ($nodes{$changedNodeName}->{addr} ne $currentNodes{$changedNodeName}->{addr}) {
                        $self->_updateCorosyncNode($nodes{$changedNodeName});
                    }
                }
                foreach my $addedNodeName (@{$diff->{new}}) {
                    $self->_addCorosyncNode($nodes{$addedNodeName});
                }
                foreach my $deletedNodeName (@{$diff->{old}}) {
                    $self->_deleteCorosyncNode($nodes{$deletedNodeName});
                }
            }
        }
    }
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
       },
       {
           name => 'zentyal.ha-psgi',
           type => 'upstart'
       },
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
        $self->model('ClusterState')->setValue('leaveRequest', 0);
        $self->_notifyLeave();
    }

    $self->_corosyncSetConf();
    if (not $self->isReadOnly() and $self->global()->modIsChanged($self->name())) {
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
        given ($clusterSettings->configurationValue()) {
            when ('create') { $self->_bootstrap($localNodeAddr, $hostname); }
            when ('join') { $self->_join($clusterSettings, $localNodeAddr, $hostname); }
        }
    }

    my $list = new EBox::HA::NodeList($self);
    my $localNode = $list->localNode();
    if ($localNodeAddr ne $localNode->{addr}) {
        $list->set(name => $localNode->{name}, addr => $localNodeAddr,
                   webAdminPort => 443, localNode => 1);
        $self->_notifyClusterConfChange($list);
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
    $self->writeConfFile(
        COROSYNC_DEFAULT_FILE,
        'ha/default-corosync.mas');
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
                   localNode => 1, nodeid => 1);

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

# Join to a existing cluster
# Params:
#    clusterSettings : the cluster configuration settings model
#    localNodeAddr: the local node address
#    hostname: the local hostname
# Actions:
#  * Get the configuration from the cluster
#  * Notify for adding ourselves in the cluster
#  * Set node list (overriding current values)
#  * Add local node
#  * Store cluster name and configuration
sub _join
{
    my ($self, $clusterSettings, $localNodeAddr, $hostname) = @_;

    my $row = $clusterSettings->row();
    my $client = new EBox::RESTClient(server => $row->valueByName('zentyal_host'));
    $client->setPort($row->valueByName('zentyal_port'));
    # FIXME: Delete this line and not verify servers when using HAProxy
    $client->setScheme('http');
    # TODO: Add secret
    my $response = $client->GET('/cluster/configuration');

    my $clusterConf = new JSON::XS()->decode($response->as_string());

    # TODO: set proper port
    my $localNode = { name => $hostname,
                      addr => $localNodeAddr,
                      webAdminPort => 443 };

    $response = $client->POST('/cluster/nodes',
                              query => $localNode);

    my $nodeList = new EBox::HA::NodeList($self);
    $nodeList->empty();
    foreach my $nodeConf (@{$clusterConf->{nodes}}) {
        $nodeConf->{localNode} = 0;  # Always set as remote node
        $nodeList->set(%{$nodeConf});
    }
    # Add local node
    $nodeList->set(%{$localNode}, localNode => 1);

    # Store cluster configuration
    $row->elementByName('name')->setValue($clusterConf->{name});
    $row->store();

    my $state = $self->get_state();
    $state->{cluster_conf}->{transport} = $clusterConf->{transport};
    $state->{cluster_conf}->{multicast} = $clusterConf->{multicastConf};
    $self->set_state($state);

    # Set as bootstraped
    $self->model('ClusterState')->setValue('bootstraped', 1);
}

# Notify the leave to a member of the cluster
# Take one of the on-line members
sub _notifyLeave
{
    my ($self) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    my $localNode = $nodeList->localNode();
    foreach my $node (@{$nodeList->list()}) {
        next if ($node->{localNode});
        # TODO: Check the node is on-line
        my $last = 0;
        my $client = new EBox::RESTClient(server => $node->{addr});
        $client->setPort(5000); # $node->{port});
        # FIXME: Delete this line and not verify servers when using HAProxy
        $client->setScheme('http');
        try {
            EBox::info('Notify leaving cluster to ' . $node->{name});
            $client->DELETE('/cluster/nodes/' . $localNode->{name});
            $last = 1;
        } catch ($e) {
            # Catch any exception
            EBox::error($e->text());
        }
        last if ($last);
    }
}

# Notify cluster conf change
sub _notifyClusterConfChange
{
    my ($self, $list, $excludes) = @_;

    my $conf = $self->clusterConfiguration();
    foreach my $node (@{$list->list()}) {
        try {
            next if ($node->{localNode});
            next if ($node->{name} ~~ @{$excludes});
            EBox::info('Notifying cluster conf changes to ' . $node->{name});
            my $client = new EBox::RESTClient(server => $node->{addr});
            $client->setPort(5000);  # TODO: Use real port
            # FIXME: Delete this line and not verify servers when using HAProxy
            $client->setScheme('http');
            # TODO: Add secret
            # Use JSON as there is more than one level of depth to use x-form-urlencoded
            my $JSONConf = new JSON::XS()->utf8()->encode($conf);
            my $response = $client->PUT('/cluster/configuration',
                                        query => $JSONConf);
        } catch ($e) {
            EBox::error('Error notifying ' . $node->{name} . " :$e");
        }
    }
}


# Dynamically update a corosync node
# Only update on addr is supported
sub _updateCorosyncNode
{
    my ($self, $node) = @_;

    EBox::Sudo::root('corosync-cmapctl -s nodelist.node.' . ($node->{nodeid} - 1)
                     . '.ring0_addr str ' . $node->{addr});

}

# Dynamically add a corosync node
sub _addCorosyncNode
{
    my ($self, $node) = @_;

    EBox::Sudo::root('corosync-cmapctl -s nodelist.node.' . ($node->{nodeid} - 1)
                     . '.nodeid u32 ' . $node->{nodeid},
                     'corosync-cmapctl -s nodelist.node.' . ($node->{nodeid} - 1)
                     . '.name str ' . $node->{name},
                     'corosync-cmapctl -s nodelist.node.' . ($node->{nodeid} - 1)
                     . '.ring0_addr str ' . $node->{addr});

}

# Dynamically delete a corosync node
sub _deleteCorosyncNode
{
    my ($self, $node) = @_;

    EBox::Sudo::root(
        'corosync-cmapctl -D nodelist.node.' . ($node->{nodeid} - 1) . '.ring0_addr',
        'corosync-cmapctl -D nodelist.node.' . ($node->{nodeid} - 1) . '.name',
        'corosync-cmapctl -D nodelist.node.' . ($node->{nodeid} - 1) . '.nodeid');

}

# Shortcut for knowing the multicast
sub _multicast
{
    my ($self) = @_;

    return ($self->get_state()->{cluster_conf}->{transport} == 'udp');
}

1;
