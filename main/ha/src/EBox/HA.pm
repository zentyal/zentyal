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

use base qw(EBox::Module::Service
            EBox::WebAdmin::PortObserver);

no warnings 'experimental::smartmatch';
use feature qw(switch);

use Data::Dumper;
use EBox::Config;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::Global;
use EBox::Gettext;
use EBox::HA::ClusterStatus;
use EBox::HA::NodeList;
use EBox::RESTClient;
use EBox::Sudo;
use EBox::Util::Random;
use EBox::Validate;
use JSON::XS;
use File::Temp;
use File::Slurp;
use MIME::Base64;
use Scalar::Util qw(blessed);
use TryCatch::Lite;
use XML::LibXML;

# Constants
use constant {
    COROSYNC_CONF_FILE    => '/etc/corosync/corosync.conf',
    COROSYNC_DEFAULT_FILE => '/etc/default/corosync',
    COROSYNC_AUTH_FILE    => '/etc/corosync/authkey',
    DEFAULT_MCAST_PORT    => 5405,
    RESOURCE_STICKINESS   => 100,
    PSGI_UPSTART          => 'zentyal.ha-psgi',
    HA_CONF_DIR           => EBox::Config::conf() . 'ha',
    HA_NODES_OBJECT_ID    => 'haNodes',
    HA_FIREWALL_RULES_DESCRIPTION => __('Rule added by Zentyal HA module'),
};
use constant {
    NGINX_INCLUDE_FILE => HA_CONF_DIR . '/uwsgi.conf',
    ZENTYAL_AUTH_FILE  => HA_CONF_DIR . '/authkey',
};

my %REPLICATE_MODULES = map { $_ => 1 } qw(dhcp dns firewall ha ips network objects services squid trafficshaping ca openvpn ntp);
my @SINGLE_INSTANCE_MODULES = qw(dhcp);

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
        $menuURL = 'HA/Composite/General';
    }

    $system->add(new EBox::Menu::Item(
        url => $menuURL,
        text => $self->printableName(),
        tag => 'system',
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
            'title'   => __("Cluster status"),
            'widget'  => \&clusterWidget,
            'order'   => 5,
            'default' => 1,
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

# Method: setIfSingleInstanceModule
#
#     Set the module as changed if the given module is in the list of
#     modules which must have a single instance in the cluster.
#
#     Stop the module and let the cluster decide if it should be enabled.
#
# Parameters:
#
#     moduleName - String the module name
#
sub setIfSingleInstanceModule
{
    my ($self, $moduleName) = @_;

    if ($moduleName ~~ @SINGLE_INSTANCE_MODULES) {
        $self->setAsChanged();
        my $state = $self->get_state();
        $state->{new_enabled_modules}->{$moduleName} = 1;
        $self->set_state($state);
    }
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
#        - auth: String of bytes with the secret
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

        # Auth is a set of bytes
        my $auth = File::Slurp::read_file(ZENTYAL_AUTH_FILE, binmode => ':raw');
        my $authStr = MIME::Base64::encode($auth, '');
        return {
            name          => $self->model('Cluster')->nameValue(),
            transport     => $transport,
            multicastConf => $multicastConf,
            nodes         => $nodeList,
            auth          => $authStr,
        };
    } else {
        return {};
    }
}

# Method: leaveCluster
#
#    Leave the cluster by setting the cluster not boostraped and store
#    the current secret to notify the leave.
#
sub leaveCluster
{
    my ($self) = @_;

    my $row = $self->model('ClusterState')->row();
    $row->elementByName('bootstraped')->setValue(0);
    $row->elementByName('leaveRequest')->setValue($self->model('Cluster')->secretValue());
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
#     * If the cluster has two nodes, then set to ignore in at quorum policy
#
# Parameters:
#
#     params - <Hash::MultiValue>, see <EBox::HA::NodeList::set> for details
#     body   - Decoded content from JSON request
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any mandatory param is missing
#     <EBox::Exceptions::InvalidData> - thrown if any params data is invalid
#
sub addNode
{
    my ($self, $params, $body) = @_;

    EBox::info('Add node (params): ' . Dumper($params));

    # Validation
    foreach my $paramName (qw(name addr port)) {
        unless (exists $params->{$paramName}) {
            throw EBox::Exceptions::MissingArgument($paramName);
        }
    }
    EBox::Validate::checkDomainName($params->{name}, 'name');
    EBox::Validate::checkIP($params->{addr}, 'addr');
    EBox::Validate::checkPort($params->{port}, 'port');

    # Create network object (or member) for the new node
    $self->_addHANetworkObjectNode($params->{name}, $params->{addr});
    $self->_saveObjectsAndFirewallIfNeeded();

    # Start to add
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

    # Pacemaker changes
    # In two-node we have to set no-quorum-policy to ignore
    $self->_setNoQuorumPolicy($list->size());
}

# Method: deleteNode
#
#    Delete node from the cluster.
#
#    * Delete the node
#    * Send cluster configuration to other members
#    * Write corosync conf
#    * Dynamically add the new node
#    * If the cluster become two nodes, then set to ignore at no quorum policy
#
#    Ignore the intention of removing a non existing node.
#
# Parameters:
#
#    params - <Hash::MultiValue> containing the node to delete in the
#             key 'name'
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any mandatory param is missing
#
sub deleteNode
{
    my ($self, $params) = @_;

    EBox::info('delete node (params): ' . Dumper($params));

    unless (exists $params->{name}) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $list = new EBox::HA::NodeList($self);
    my $deletedNode;
    try {
        $deletedNode = $list->node($params->{name});
    } catch (EBox::Exceptions::DataNotFound $e) {
        EBox::warn('Node ' . $params->{name} . ' is not in our list to delete it');
        return;
    }
    $list->remove($params->{name});

    # Create network object (or member) for the new node
    $self->_removeMemberFromHANetworkObject($params->{name});
    $self->_saveObjectsAndFirewallIfNeeded();

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

    # Pacemaker changes
    # In two-node we have to set no-quorum-policy to ignore
    $self->_setNoQuorumPolicy($list->size());
}

sub confReplicationStatus
{
    my ($self) = @_;

    my $errors = $self->get_state()->{errors};

    unless (defined $errors) {
        $errors = {};
    }

    return { errors => $errors };
}

sub replicateConf
{
    my ($self, $params, $body, $uploads) = @_;

    EBox::info("Received replication bundle");
    my $tmpdir = mkdtemp(EBox::Config::tmp() . 'replication-bundle-XXXX');

    my $file = $uploads->get('file');
    my $path = $file->path;

    EBox::Sudo::root("tar xzf $path -C $tmpdir");

    EBox::Sudo::root("cp -a $tmpdir/files/* /");

    my $modules = decode_json(read_file("$tmpdir/modules.json"));

    EBox::info("The following modules are going to be replicated: @{$modules}");
    foreach my $modname (@{$modules}) {
        EBox::info("Restoring conf of module: $modname");
        my $mod = EBox::Global->modInstance($modname);
        my %keysToReplace;
        my @keysToDelete;

        my @excludedKeys = @{$mod->replicationExcludeKeys()};
        push (@excludedKeys, '_serviceModuleStatus');
        foreach my $key (@excludedKeys) {
            my $value = $mod->get($key);
            if (defined ($value)) {
                $keysToReplace{$key} = $value;
            } else {
                push (@keysToDelete, $key);
            }
        }

        my $backupDir = "$tmpdir/$modname.bak";
        next unless (-d $backupDir);
        $mod->restoreBackup($backupDir);

        foreach my $key (keys %keysToReplace) {
            $mod->set($key, $keysToReplace{$key});
        }
        foreach my $key (@keysToDelete) {
            $mod->unset($key);
        }
    }

    # Avoid to save changes in ha module
    EBox::Global->modRestarted('ha');

    my $state = $self->get_state();
    $state->{replicating} = 1;
    $self->set_state($state);
    EBox::info("Configuration replicated, now saving changes...");
    try {
        EBox::Global->saveAllModules(replicating => 1);
    } catch ($ex) {
        # Delete replicating state and rethrow the exception
        delete $state->{replicating};
        $self->set_state($state);
        if (blessed($ex)) {
            $ex->throw();
        } else {
            throw EBox::Exceptions::Internal($ex);
        }
    }
    # Finally block
    delete $state->{replicating};
    $self->set_state($state);

    EBox::info("Changes saved after replication request");

    EBox::Sudo::root("rm -rf $tmpdir");
}

# Method: replicationExcludeKeys
#
#   Overrides: <EBox::Module::Config::replicationExcludeKeys>
#
sub replicationExcludeKeys
{
    return [
        'Cluster/keys/form',
        'ClusterState/keys/form',
        '_serviceModuleStatus',
        'state'
    ];
}

# Method: askForReplication
#
#   Ask for replication in all the nodes except the local one
#
#   Parameters:
#
#       modules - list of modules with changes
#
sub askForReplication
{
    my ($self, $modules) = @_;

    my @nodes = @{$self->nodes()};
    return if (scalar(@nodes) <= 1);

    my $state = $self->get_state();
    if ($state->{joining}) {
        # If we are joining to the cluster, get your data instead of replicate my data
        my $peerNode = $state->{joining};
        delete $state->{joining};
        $self->set_state($state);
        $self->_askForConf($peerNode);
    } else {
        my @modules = grep { $REPLICATE_MODULES{$_} } @{$modules};

        my ($tmpdir, $path) = $self->_generateReplicationBundle(\@modules);

        my $failed = 0;
        my $state = $self->get_state();
        foreach my $node (@nodes) {
            next if ($node->{localNode});
            try {
                $self->_uploadReplicationBundle($node, $path);
            } catch ($e) {
                my $name = $node->{name};
                EBox::error("Replication to node $name failed: $e");
                $state->{errors}->{$name} = 1;
                $failed = 1;
            }
        }
        $self->set_state($state);

        my $msg = 'Replication to the rest of nodes finished';
        if ($failed) {
            $msg .= ' with errors';
            EBox::error($msg);
        } else {
            EBox::info($msg);
        }

        EBox::Sudo::root("rm -rf $tmpdir");
    }
}

# Method: askForReplicationNode
#
#    Ask for replication from a node
#
# Parameters:
#
#    params - <Hash::MultiValue> containing the node to delete in the
#             key 'name'
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any mandatory param is missing
#
#     <EBox::Exceptions::DataNotFound> - thrown if the node name is not valid
#
#     <EBox::Exceptions::External> - thrown if the node name is equals to local node name
#
sub askForReplicationNode
{
    my ($self, $params) = @_;

    EBox::info('ask for replication node (params): ' . Dumper($params));

    unless (exists $params->{name}) {
        throw EBox::Exceptions::MissingArgument('name');
    }
    my $name = $params->{name};

    my $nodeList = new EBox::HA::NodeList($self);
    my $localNode = $nodeList->localNode();
    if ($localNode->{name} eq $name) {
        throw EBox::Exceptions::External('Ask for replication for local node!!');
    }
    my $node = $nodeList->node($name);

    my $global = $self->global();
    my @modules = grep { $global->modExists($_) } keys %REPLICATE_MODULES;

    my ($tmpdir, $path) = $self->_generateReplicationBundle(\@modules);

    my $failed = 0;
    my $state = $self->get_state();
    try {
        $self->_uploadReplicationBundle($node, $path);
        $state->{errors}->{$name} = 0;
    } catch {
        my $name = $node->{name};
        EBox::error("Replication to node $name failed");
        $state->{errors}->{$name} = 1;
        $failed = 1;
    }
    $self->set_state($state);
    EBox::info('Replication to node ' . $node->{name} . $failed ? ' failed' : ' done');

    EBox::Sudo::root("rm -rf $tmpdir");
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
#    <EBox::Exceptions::InvalidData> - thrown if any mandatory argument contains invalid data
#    <EBox::Exceptions::MissingArgument> - thrown if the any mandatory argument is missing from BODY
#
sub updateClusterConfiguration
{
    my ($self, $params, $body) = @_;

    EBox::info('Update cluster conf (body): ' . Dumper($body));

    unless ($self->clusterBootstraped()) {
        throw EBox::Exceptions::Internal('Cannot a non-bootstraped module');
    }

    foreach my $paramName (qw(name transport multicastConf nodes)) {
        unless (exists $body->{$paramName}) {
            throw EBox::Exceptions::MissingArgument($paramName);
        }
    }
    unless ($body->{transport} ~~ ['udp', 'udpu']) {
        throw EBox::Exceptions::InvalidData(data => 'transport', value => $body->{transport},
                                            advice => 'udp or udpu');
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
    my $localNode = $list->localNode();
    my ($equal, $diff) = $list->diff($body->{nodes});
    unless ($equal) {
        my %currentNodes = map { $_->{name} => $_ } @{$list->list()};
        my %nodes = map { $_->{name} => $_ } @{$body->{nodes}};
        # Update NodeList
        foreach my $nodeName (@{$diff->{new}}, @{$diff->{changed}}) {
            next if ($nodeName eq $localNode->{name});  # Updates never come from self
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

# Method: checkAndUpdateClusterConfiguration
#
#     Check if any change happened in cluster configuration and update
#     accordingly.
#
sub checkAndUpdateClusterConfiguration
{
    my ($self) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    my $localNode;

    try {
        $localNode = $nodeList->localNode();
    } catch (EBox::Exceptions::DataNotFound $e) {
        # Then something rotten in our conf
        EBox::warn('There is no local node in our configuration');
        return;
    }

    my $clusterStatus;
    try {
        $clusterStatus = new EBox::HA::ClusterStatus(ha => $self);
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::warn('Cannot get the status from the cluster');
    }
    my $conf;

    my $last = 0;
    foreach my $node (@{$nodeList->list()}) {
        next if ($node->{localNode});
        next unless (not $clusterStatus or $clusterStatus->nodeOnline($node->{name}));

        # Read the user secret from leaveRequest
        my $client = new EBox::RESTClient(
            credentials => {realm => 'Zentyal HA', username => 'zentyal',
                            password => $self->userSecret()},
            server => $node->{addr},
            verifyPeer => 0,
           );
        $client->setPort($node->{port});
        try {
            EBox::info('Read new cluster configuration from ' . $node->{name});
            my $response = $client->GET('/cluster/configuration');
            $conf = new JSON::XS()->decode($response->as_string());
            $last = 1;
        } catch ($e) {
            # Catch any exception
            EBox::error("Error getting new configuration: $e");
        }
        last if ($last);
    }
    if ($last) {
        # TODO: Add versioning to cluster configuration
        $self->updateClusterConfiguration(undef, $conf);
    }
}

# Method: userSecret
#
# Returns:
#
#     String - the user secret to enter to join to this cluster
#
#     undef - if the cluster is not bootstraped
#
sub userSecret
{
    my ($self) = @_;

    if ($self->clusterBootstraped()) {
        return $self->model('Cluster')->secretValue();
    }
    return undef;
}

# Method: destroyClusterConf
#
#    Destroy the cluster configuration leaving the module disabled
#    with the modules stopped. Ready to start over again.
#
#    It saves the configuration.
#
sub destroyClusterConf
{
    my ($self) = @_;

    $self->leaveCluster();
    $self->_notifyLeave();
    $self->model('ClusterState')->setValue('leaveRequest', "");
    $self->_destroyClusterInfo();
    $self->enableService(0);
    $self->saveConfig();
    $self->stopService();
}

# Method: adminPortChanged
#
#     Report to the cluster the port has changed.
#
# Parameters:
#
#     port - Int the new TCP port
#
# Overrides:
#
#     <EBox::WebAdmin::PortObserver::adminPortChanged>
#
sub adminPortChanged
{
    my ($self, $port) = @_;

    if ($self->isEnabled()) {
        try {
            my $list = new EBox::HA::NodeList($self);
            my $localNode = $list->localNode();
            if ($localNode->{port} != $port) {
                EBox::debug("Changing port to $port");
                $list->set(name => $localNode->{name}, addr => $localNode->{addr},
                           port => $port, localNode => 1);
                $self->_notifyClusterConfChange($list);
            }
        } catch (EBox::Exceptions::DataNotFound $e) {
            EBox::error("Cannot locate local node, do not notify the change: $e");
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
           name => PSGI_UPSTART,
           type => 'upstart',
       },
    ];

    return $daemons;
}

# Method: _stopDaemon
#
#     Override as init.d pacemaker return non-required exit codes
#     and upstart for UWSGI is deleted on _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_stopDaemon>
#
sub _stopDaemon
{
    my ($self, $daemon) = @_;

    if ($daemon->{name} eq 'pacemaker') {
        EBox::Sudo::silentRoot("service pacemaker stop");
    } elsif (($daemon->{name} ne PSGI_UPSTART) or (-e '/etc/init/' . PSGI_UPSTART . '.conf')) {
        $self->SUPER::_stopDaemon($daemon);
    }
}

# Method: _enforceServiceState
#
#     Override to do nothing when replicating flag is set
#
# Overrides:
#
#     <EBox::Module::Service::_enforceServiceState>
#
sub _enforceServiceState
{
    my ($self, @params) = @_;

    # FIXME: Do it in the framework as jacalvo suggests
    if ($self->_restartRequired(@params)) {
        $self->SUPER::_enforceServiceState(@params);
    }
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_setPSGI();

    # Notify the leave even when the module is being disabled
    if ($self->model('ClusterState')->leaveRequestValue()) {
        $self->_notifyLeave();
        $self->model('ClusterState')->setValue('leaveRequest', "");
        $self->_destroyClusterInfo();
        $self->{restart_required} = 1;
    }

    if ($self->isEnabled()) {
        $self->_corosyncSetConf();
    }

    if (not $self->isReadOnly() and $self->global()->modIsChanged($self->name())) {
        $self->saveConfig();
    }
}

# Method: _postServiceHook
#
#       Override to set initial cluster operations once we are sure
#       crmd is running
#
# Overrides:
#
#       <EBox::Module::Service::_postServiceHook>
#
sub _postServiceHook
{
    my ($self, $enabled) = @_;

    $self->SUPER::_postServiceHook($enabled);

    if ($enabled) {
        $self->_waitPacemaker();
        my $state = $self->get_state();
        if ($state->{bootstraping}) {
            $self->_initialClusterOperations();
            delete $state->{bootstraping};
            $self->set_state($state);
        }
        $self->_setFloatingIPRscs();
        $self->_setSingleInstanceInClusterModules();
    }
}

# Group: Public methods

# Method: clusterWidget
#
#    Establish the cluster status widget
#
# Parameters:
#
#    widget - <EBox::Dashboard::Widget> the widget to add new sections
#
sub clusterWidget
{
    my ($self, $widget) = @_;

    my $clusterSection = new EBox::Dashboard::Section('status',);
    $widget->add($clusterSection);

    if ($self->isEnabled()) {
        my $clusterStatus;
        my ($lastUpdate, $error, $errorType) = (__('Unknown'), __('None'), 'info');
        try {
            $clusterStatus = new EBox::HA::ClusterStatus(ha => $self);
            $lastUpdate = $clusterStatus->summary()->{last_update};
            my $errors = $clusterStatus->errors();
            if (defined($errors) and keys %{$errors} > 0) {
                $error = __x('{oh}There are errors{ch}',
                             oh => '<a href="/HA/Composite/General#Status">',
                             ch => '</a>');
                $errorType = 'error';
            }
        } catch ($e) {
            # TODO properly
            ;
        }
        $clusterSection->add(new EBox::Dashboard::Value(__('Last update'),
                                                        $lastUpdate));
        $clusterSection->add(new EBox::Dashboard::Value(__('Errors'),
                                                        $error, $errorType
                                                       ));
    } else {
        $clusterSection->add(new EBox::Dashboard::Value(__('Status'),
                                                        __('not enabled')));
    }

    my $nodeSection = new EBox::Dashboard::Section('nodelist', __('Nodes'));
    $widget->add($nodeSection);
    my $titles = [__('Host name'),__('IP address')];

    my $list = new EBox::HA::NodeList($self)->list();

    my @ids = map { $_->{name} } @{$list};
    my %rows = map { $_->{name} => [$_->{name}, $_->{addr}] } @{$list};

    $nodeSection->add(new EBox::Dashboard::List(undef, $titles, \@ids, \%rows,
                                            __('Cluster is not configured')));

}

# Method: floatingIPs
#
#       Return the existing floating IPs
#
# Returns:
#
#   array ref - each element contains a hash ref with keys:
#
#          name - the name of the given floating IP
#          address - the IP address
#
sub floatingIPs
{
    my ($self) = @_;

    my $floatingIpModel = $self->model('FloatingIP');
    my @floatingIps;
    for my $id (@{$floatingIpModel->ids()}) {
        my $row = $floatingIpModel->row($id);
        push (@floatingIps, { name => $row->printableValueByName('name'),
                address  => $row->printableValueByName('floating_ip')});
    }

    return \@floatingIps;
}

# Method: isFloatingIP
#
#       Return if the given IP from the given interface already exists
#       as one of the HA module flaoting IPs
#
# Parameters:
#
# iface - interface name
# ip - IP address we want to check
#
# Returns:
#
#   boolean - weather the IP already exists or not
#
sub isFloatingIP
{
    my ($self, $iface, $ip) = @_;

    my $clusterSettings = $self->model('Cluster');
    my $haIface = $clusterSettings->interfaceValue();

    my $zentyalIP = new Net::IP($ip);

    # Ifaces must be the same to take place an overlapping
    if ($iface ne $haIface) {
        return 0;
    }

    # Compare the IP with all the existing floating IPs
    my $floatingIPs = $self->floatingIPs();
    foreach my $floatingIPRow (@{$floatingIPs}) {
        my $floatingIP = new Net::IP($floatingIPRow->{address});

        if ($zentyalIP->overlaps($floatingIP)) {
            return 1;
        }
    }

    return 0;
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
            when ('create') {
                $self->_bootstrap($localNodeAddr, $hostname);
                my $state = $self->get_state();
                $state->{bootstraping} = 1;
                $self->set_state($state);
            }
            when ('join') {
                $self->_join($clusterSettings, $localNodeAddr, $hostname, $clusterSettings->secretValue());
            }
        }
    }

    my $list = new EBox::HA::NodeList($self);
    my $localNode = $list->localNode();
    if ($localNodeAddr ne $localNode->{addr}) {
        # Update Network Object with the new IP
        $self->_removeMemberFromHANetworkObject($localNode->{name});
        $self->_addHANetworkObjectNode($localNode->{name}, $localNodeAddr);
        $self->_saveObjectsAndFirewallIfNeeded();

        # After updating the network objects we need to propagate those changes
        # to the rest of the cluster.
        $self->askForReplication(['objects', 'firewall']);

        # Update the NodeList
        $list->set(name => $localNode->{name}, addr => $localNodeAddr,
                   port => $self->global()->modInstance('webadmin')->listeningPort(),
                   localNode => 1);
        $self->_notifyClusterConfChange($list);
        $self->{restart_required} = 1;
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
    my $webAdminMod = $self->global()->modInstance('webadmin');
    $nodeList->empty();
    $nodeList->set(name => $hostname, addr => $localNodeAddr,
                   port => $webAdminMod->listeningPort(),
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

    $self->model('Cluster')->setValue('secret',
                                      EBox::Util::Random::generate(8,
                                                                   [split(//, 'abcdefghijklmnopqrstuvwxyz'
                                                                            . 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                                                            . '0123456789')]));

    # Add network objects and firewall rules
    $self->_createNetworkObject();
    $self->_addHANetworkObjectNode($hostname, $localNodeAddr);
    $self->_createFirewallRules();
    $self->_saveObjectsAndFirewallIfNeeded();

    # Finally, store it in Redis
    $self->set_state($state);

    # Create and store the private key in /etc/corosync/authfile
    $self->_createStoreAuthFile();

    # Set as bootstraped
    $self->model('ClusterState')->setValue('bootstraped', 1);
}

# Creates a HA network object, so firewall rules can affect HA nodes
sub _createNetworkObject
{
    my ($self) = @_;

    my $objectsModule = $self->global()->modInstance('objects');

    if (not $objectsModule->objectExists(HA_NODES_OBJECT_ID)) {
        EBox::debug('Creating HA network object');
        $objectsModule->removeObjectMembers(HA_NODES_OBJECT_ID);
        $objectsModule->addObject(id => HA_NODES_OBJECT_ID, name => __('HA Nodes'), members => []);
    } else {
        EBox::debug('Removing existing nodes from HA network object');
        $objectsModule->removeObjectMembers(HA_NODES_OBJECT_ID);
    }

    $self->{objects_restart} = 1;
    $self->{firewall_restart} = 1;
}

# Adds a member to the HA network object
sub _addHANetworkObjectNode
{
    my ($self, $nodeName, $nodeIP) = @_;

    try {
        EBox::debug("Adding member $nodeName - $nodeIP to the HA network object");
        my $objectsModule = $self->global()->modInstance('objects');

        if (not $objectsModule->objectExists(HA_NODES_OBJECT_ID)) {
            $self->_createNetworkObject();
        }

        $objectsModule->addMemberToObject(HA_NODES_OBJECT_ID,
            {
                name => $nodeName,
                address_selected => 'ipaddr',
                ipaddr_ip => $nodeIP,
                ipaddr_mask => '32',
            }
        );

        $self->{objects_restart} = 1;
        $self->{firewall_restart} = 1;
    } catch {
        EBox::error('Error when creating a new HA nodes network object member');
    }
}

# Removes a member from the HA network object
sub _removeMemberFromHANetworkObject
{
    my ($self, $nodeHostname) = @_;

    my $objectsModule = $self->global()->modInstance('objects');

    if ($objectsModule->objectExists(HA_NODES_OBJECT_ID)) {
        my $membersModel = $objectsModule->model('ObjectTable')->row(HA_NODES_OBJECT_ID)->subModel('members');

        for my $id (@{ $membersModel->ids() }) {
            if ($membersModel->row($id)->valueByName('name') eq $nodeHostname) {
                EBox::debug("Removing member $nodeHostname from the HA network object");
                $objectsModule->removeObjectMember(HA_NODES_OBJECT_ID, $id);
                $self->{objects_restart} = 1;
                $self->{firewall_restart} = 1;
            }
        }
    }
}

# Creates a initial firewall rule so each HA node can contact each other
sub _createFirewallRules
{
    my ($self) = @_;

    if ($self->global()->modExists('firewall')) {
        if (not $self->_firewallRuleCreated()) {
            my $rule = {
                source_object => HA_NODES_OBJECT_ID,
                source_selected => 'source_object',
                service => $self->global()->modInstance('services')->serviceId('any'),
                decision => 'accept',
                description => HA_FIREWALL_RULES_DESCRIPTION,
            };

            try {
                EBox::debug('Creating HA firewall rule');
                my $firewallModule = $self->global()->modInstance('firewall');
                $firewallModule->model('InternalToEBoxRuleTable')->addRow(%{ $rule });
                $self->{firewall_restart} = 1;
            } catch {
                EBox::error('Error when creating HA firewall rule');
            }
        }
    }
}

# Restart objects and ferewall to apply new HA network object rules
sub _saveObjectsAndFirewallIfNeeded
{
    my ($self) = @_;

    if ($self->global()->modExists('objects') and $self->{objects_restart}) {
        $self->global()->modInstance('objects')->save();
        $self->{objects_restart} = 0;
    }

    if ($self->global()->modExists('firewall') and $self->{firewall_restart}) {
        $self->global()->modInstance('firewall')->save();
        $self->{firewall_restart} = 0;
    }
}

sub _firewallRuleCreated
{
    my ($self) = @_;

    my $ruleAlreadyExists = 0;

    my $internalRulesModel = $self->global()->modInstance('firewall')->model('InternalToEBoxRuleTable');
    my $any = $self->global()->modInstance('services')->serviceId('any');

    for my $id (@{ $internalRulesModel->ids() }) {
        if ($internalRulesModel->row($id)->valueByName('source') eq HA_NODES_OBJECT_ID
                and $internalRulesModel->row($id)->valueByName('decision') eq 'accept'
                and $internalRulesModel->row($id)->valueByName('service') eq $any) {
            $ruleAlreadyExists = 1;
        }
    }

    return $ruleAlreadyExists;
}

# Create and store the auth
sub _createStoreAuthFile
{
    my ($self) = @_;

    EBox::Sudo::root('corosync-keygen -l');
    try {
        # Quickie & dirty
        EBox::Sudo::root('chown ebox:ebox ' . COROSYNC_AUTH_FILE);  # To read it
        my $auth = File::Slurp::read_file(COROSYNC_AUTH_FILE, binmode => ':raw');
        if (-e ZENTYAL_AUTH_FILE) {  # Delete previous version if it was there
            chmod(0600, ZENTYAL_AUTH_FILE);
            unlink(ZENTYAL_AUTH_FILE);
        }
        File::Slurp::write_file(ZENTYAL_AUTH_FILE, {binmode => ':raw',
                                                    perms   => 0400}, $auth);
    } catch ($e) {
        EBox::Sudo::root('chown root:root ' . COROSYNC_AUTH_FILE);
        throw EBox::Exceptions::Internal("Cannot read/write auth file: $e");
    }
    EBox::Sudo::root('chown root:root ' . COROSYNC_AUTH_FILE);
}

# Join to a existing cluster
# Params:
#    clusterSettings : the cluster configuration settings model
#    localNodeAddr: the local node address
#    hostname: the local hostname
#    userSecret: the user secret
# Actions:
#  * Get the configuration from the cluster
#  * Notify for adding ourselves in the cluster
#  * Set node list (overriding current values)
#  * Add local node
#  * Store cluster name and configuration
sub _join
{
    my ($self, $clusterSettings, $localNodeAddr, $hostname, $userSecret) = @_;

    my $row = $clusterSettings->row();
    my $peerHost = $row->valueByName('zentyal_host');
    my $client = new EBox::RESTClient(
        credentials => {realm => 'Zentyal HA', username => 'zentyal', password => $userSecret},
        server => $peerHost,
        verifyPeer => 0,
       );
    $client->setPort($row->valueByName('zentyal_port'));

    # Add network objects and firewall rules
    $self->_createNetworkObject();
    $self->_addHANetworkObjectNode($hostname, $localNodeAddr);
    $self->_createFirewallRules();
    $self->_saveObjectsAndFirewallIfNeeded();

    # This should not fail as we have a check in validateTypedRow
    my $response = $client->GET('/cluster/configuration');

    my $clusterConf = new JSON::XS()->decode($response->as_string());

    my $webAdminMod = $self->global()->modInstance('webadmin');
    my $localNode = { name => $hostname,
                      addr => $localNodeAddr,
                      port => $webAdminMod->listeningPort() };

    $self->_storeAuthFile($clusterConf->{auth});

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

    # Set as bootstraped
    $self->model('ClusterState')->setValue('bootstraped', 1);

    # Set as joining
    my @matchedNodes = grep { ($_->{name} eq $peerHost) or ($_->{addr} eq $peerHost) } @{$clusterConf->{nodes}};
    if (@matchedNodes > 0) {
        $state->{joining} = $matchedNodes[0];
    }
    $self->set_state($state);
}

# Store the set of bytes to the auth file
sub _storeAuthFile
{
    my ($self, $auth) = @_;

    if (-e ZENTYAL_AUTH_FILE) {  # Delete previous version if it was there
        chmod(0600, ZENTYAL_AUTH_FILE);
        unlink(ZENTYAL_AUTH_FILE);
    }
    my $authBin = MIME::Base64::decode($auth);
    File::Slurp::write_file(ZENTYAL_AUTH_FILE, {binmode => ':raw', perms => 0400},
                            $authBin);
    EBox::Sudo::root('install -D --group=0 --owner=0 --mode=0400 ' . ZENTYAL_AUTH_FILE
                     . ' ' . COROSYNC_AUTH_FILE);
}

# Set the PSGI upstart script
sub _setPSGI
{
    my ($self) = @_;

    my $webadminMod = $self->global()->modInstance('webadmin');
    my $upstartJobFile =  '/etc/init/' . PSGI_UPSTART . '.conf';
    if ($self->isEnabled()) {
        my $socketPath = '/run/zentyal-' . $self->name();
        my $socketName = 'ha-uwsgi.sock';
        my @params = (
            (socketpath => $socketPath),
            (socketname => $socketName),
            (script => EBox::Config::psgi() . 'ha.psgi'),
            (module => $self->printableName()),
            (user   => EBox::Config::user()),
            (group  => EBox::Config::group()),
           );
        $self->writeConfFile($upstartJobFile,
                             'core/upstart-uwsgi.mas',  # Use common UWSGI template
                             \@params,
                             { uid => 0, gid => 0, mode => '0644', force => 1 });

        @params = (
            (path   => '/cluster/'),
            (socket => "$socketPath/$socketName"),
           );
        $self->writeConfFile(NGINX_INCLUDE_FILE,
                             'ha/nginx.conf.mas',
                             \@params);

        $webadminMod->addNginxInclude(NGINX_INCLUDE_FILE);
    } else {
        try {
            $webadminMod->removeNginxInclude(NGINX_INCLUDE_FILE);
        } catch (EBox::Exceptions::Internal $e) {
            # Do nothing if the include has been already removed
        }
    }
    if (not $self->isReadOnly() and $self->global()->modIsChanged('webadmin')) {
        $self->global()->addModuleToPostSave('webadmin');
    }
}

# Notify the leave to a member of the cluster
# Take one of the on-line members
sub _notifyLeave
{
    my ($self) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    my $localNode;
    try {
        $localNode = $nodeList->localNode();
    } catch (EBox::Exceptions::DataNotFound $e) {
        # Then something rotten in our conf
        EBox::warn('There is no local node in our configuration');
        return;
    }
    foreach my $node (@{$nodeList->list()}) {
        next if ($node->{localNode});
        # TODO: Check the node is on-line
        my $last = 0;
        # Read the user secret from leaveRequest
        my $userSecret = $self->model('ClusterState')->leaveRequestValue();
        my $client = new EBox::RESTClient(
            credentials => {realm => 'Zentyal HA', username => 'zentyal',
                            password => $userSecret},
            server => $node->{addr},
            verifyPeer => 0,
           );
        $client->setPort($node->{port});
        try {
            EBox::debug($userSecret);
            EBox::info('Notify leaving cluster to ' . $node->{name});
            $client->DELETE('/cluster/nodes/' . $localNode->{name});
            $last = 1;
        } catch ($e) {
            # Catch any exception
            EBox::error("Error notifying deletion: $e");
        }
        last if ($last);
    }
}

# Destroy any related information stored in cib
sub _destroyClusterInfo
{
    my ($self) = @_;

    EBox::debug("Destroying info from pacemaker");
    my @stateFiles = qw(cib.xml* cib-* core.* hostcache cts.* pe*.bz2 cib.*);
    my @rootCmds = map { qq{find /var/lib/pacemaker -name '$_' | xargs rm -f} } @stateFiles;
    EBox::Sudo::root(@rootCmds);
}

# Notify cluster conf change
sub _notifyClusterConfChange
{
    my ($self, $list, $excludes) = @_;

    my $conf = $self->clusterConfiguration();
    my $clusterSecret = $self->userSecret();
    foreach my $node (@{$list->list()}) {
        try {
            next if ($node->{localNode});
            next if ($node->{name} ~~ @{$excludes});
            EBox::info('Notifying cluster conf changes to ' . $node->{name});
            my $client = new EBox::RESTClient(
                credentials => {realm => 'Zentyal HA', username => 'zentyal',
                                password => $clusterSecret},
                server => $node->{addr},
                verifyPeer => 0,
               );
            $client->setPort($node->{port});
            # Use JSON as there is more than one level of depth to use x-form-urlencoded
            my $JSONConf = new JSON::XS()->utf8()->encode($conf);
            my $response = $client->PUT('/cluster/configuration',
                                        query => $JSONConf);
        } catch ($e) {
            EBox::error('Error notifying ' . $node->{name} . " :$e");
        }
    }
}

# Get the corosync-cmapctl index for nodelist
sub _corosyncNodelistIndex
{
    my ($self, $node) = @_;

    my $output = EBox::Sudo::root(q{corosync-cmapctl nodelist.node | grep -P '= } . $node->{name} . q{'$});
    my ($idx) = $output->[0] =~ m/node\.(\d+)\./;
    return $idx;
}

# Dynamically update a corosync node
# Only update on addr is supported
sub _updateCorosyncNode
{
    my ($self, $node) = @_;

    my $idx = $self->_corosyncNodelistIndex($node);
    EBox::Sudo::root("corosync-cmapctl -s nodelist.node.${idx}.ring0_addr str " . $node->{addr});

}

# Dynamically add a corosync node
sub _addCorosyncNode
{
    my ($self, $node) = @_;

    my $output = EBox::Sudo::root('corosync-cmapctl nodelist.node');
    my ($lastIdx) = $output->[$#{$output}] =~ m/node\.(\d+)\./;
    $lastIdx++;
    EBox::Sudo::root("corosync-cmapctl -s nodelist.node.${lastIdx}.nodeid u32 " . $node->{nodeid},
                     "corosync-cmapctl -s nodelist.node.${lastIdx}.name str " . $node->{name},
                     "corosync-cmapctl -s nodelist.node.${lastIdx}.ring0_addr str " . $node->{addr});

}

# Dynamically delete a corosync node
sub _deleteCorosyncNode
{
    my ($self, $node) = @_;

    my $idx = $self->_corosyncNodelistIndex($node);
    EBox::Sudo::root(
        "corosync-cmapctl -D nodelist.node.${idx}.ring0_addr",
        "corosync-cmapctl -D nodelist.node.${idx}.name",
        "corosync-cmapctl -D nodelist.node.${idx}.nodeid");

}

# Shortcut for knowing the multicast
sub _multicast
{
    my ($self) = @_;

    return ($self->get_state()->{cluster_conf}->{transport} eq 'udp');
}

# _waitPacemaker
# Wait for 60s to have pacemaker running or time out
sub _waitPacemaker
{
    my ($self) = @_;

    my $maxTries = 60;
    my $sleepSeconds = 1;
    my $ready = 0;

    while (not $ready and $maxTries > 0) {
        my $output = EBox::Sudo::silentRoot('crm_mon -1 -s');
        $output = $output->[0];
        given ($output) {
            when (/Ok/) { $ready = 1; }
            when (/^Warning:No DC/) { EBox::debug('waiting for quorum'); }
            when (/^Warning:offline node:/) { $ready = 1; }  # No worries warning
            default { EBox::debug("No parse on $output"); }
        }
        $maxTries--;
        sleep(1) unless ($ready);
    }

    unless ($ready) {
        EBox::warn('Timeout reached while waiting for pacemaker');
    }
}

# Initial pacemaker related operations once the crmd is operational
#
#  * Prevent resources from moving after recovery
#  * Disable STONITH until something proper is implemented
sub _initialClusterOperations
{
    my ($self) = @_;

    EBox::Sudo::root('crm configure property stonith-enabled=false',
                     'crm_attribute --type rsc_defaults --attr-name resource-stickiness --attr-value ' . RESOURCE_STICKINESS);
}

# Get the current resources configuration from cibadmin
sub _rscsConf
{
    my $output = EBox::Sudo::root('cibadmin --query --scope resources');
    my $outputStr = join('', @{$output});
    return XML::LibXML->load_xml(string => $outputStr);
}

# Set the floating IP resources
#
#  * Add new floating IP addresses
#  * Remove floating IP addresses
#  * Update IP address if applied
sub _setFloatingIPRscs
{
    my ($self) = @_;

    my $rsc = $self->floatingIPs();
    my $clusterStatus = new EBox::HA::ClusterStatus(ha => $self);

    # Get the resource configuration from the cib directly
    my $dom = $self->_rscsConf();
    my @ipRscElems = $dom->findnodes('//primitive[@type="IPaddr2"]');

    # For ease to existence checking
    my %currentRscs = map { $_->getAttribute('id') => $_->findnodes('//nvpair[@name="ip"]')->get_node(1)->getAttribute('value') } @ipRscElems;
    my %finalRscs = map { $_->{name} => $_->{address} } @{$rsc};

    my @rootCmds;

    # Process first the deleted one to avoid problems in IP address clashing on renaming
    my @deletedRscs = grep { not exists($finalRscs{$_}) } keys %currentRscs;
    foreach my $rscName (@deletedRscs) {
        push(@rootCmds,
             "crm -w resource stop $rscName",
             "crm configure delete $rscName");
    }

    my $list = new EBox::HA::NodeList($self);
    my $localNode = $list->localNode();

    my $activeNode = $clusterStatus->activeNode();
    my @moves = ();
    while (my ($rscName, $rscAddr) = each(%finalRscs)) {
        if (exists($currentRscs{$rscName})) {
            # Update the IP, if required
            if ($currentRscs{$rscName} ne $rscAddr) {
                # Update it!
                push(@rootCmds, "crm resource param $rscName set ip $rscAddr");
            }
        } else {
            # Add it!
            push(@rootCmds,
                 "crm -w configure primitive $rscName ocf:heartbeat:IPaddr2 params ip=$rscAddr op monitor interval=30s");
            if ($activeNode ne $localNode) {
                push(@moves, $rscName);
            }
        }
    }

    if (@rootCmds > 0) {
        EBox::Sudo::root(@rootCmds);
        if (@moves > 0) {
            # Do the initial movements after adding new primitives
            @rootCmds = ();
            foreach my $rscName (@moves) {
                if ($self->_resourceCanBeMovedToNode($rscName, $activeNode)) {
                    push(@rootCmds,
                         "crm_resource --resource '$rscName' --clear",  # Clear any previous outdated constraint
                         "crm_resource --resource '$rscName' --move --host '$activeNode' --lifetime 'P30S'",
                         );
                }
            }
            if (@rootCmds > 0) {
                EBox::Sudo::root(@rootCmds);
            }
        }
    }
}

# Returns if the resource can be moved to the given node (usually active node)
sub _resourceCanBeMovedToNode
{
    my ($self, $resource, $node) = @_;

    my $clusterStatus = new EBox::HA::ClusterStatus(ha => $self,
                                                    force => 1);

    my $resourceStatus = $clusterStatus->resourceByName($resource);
    if (defined($resourceStatus)) {
        my @runningNodes = @{ $resourceStatus->{nodes} };

        return (not ($node ~~ @runningNodes));
    }

    return 0;
}

# Set up and down the modules with a single instance in the cluster
sub _setSingleInstanceInClusterModules
{
    my ($self) = @_;

    my $dom = $self->_rscsConf();
    my $clusterStatus = new EBox::HA::ClusterStatus(ha => $self);
    my @zentyalRscElems = $dom->findnodes('//primitive[@type="Zentyal"]');

    # For ease to existence checking
    my %currentRscs = map { $_->getAttribute('id') => 1 } @zentyalRscElems;

    my $list = new EBox::HA::NodeList($self);
    my $localNode = $list->localNode();
    my $activeNode = $clusterStatus->activeNode();

    my @rootCmds;
    my @moves = ();
    foreach my $modName (@SINGLE_INSTANCE_MODULES) {
        my $mod = $self->global()->modInstance($modName);
        if (defined($mod) and $mod->configured()) {
            if ($mod->isEnabled()) {
                if (exists $currentRscs{$modName}) {
                    $self->_stopSingleInstanceMods();
                } else {  # Create the new resource
                    push(@rootCmds,
                         "crm -w configure primitive '$modName' "
                         . "ocf:zentyal:Zentyal params module_name='$modName' "
                         . "op monitor interval=60s timeout=10s"
                         . "op monitor interval=300s role=Stopped timeout=10s");
                    if ($activeNode ne $localNode) {
                        push(@moves, $modName);
                    }
                }
            } else {
                if (exists $currentRscs{$modName}) {
                    push(@rootCmds,
                         "crm -w resource stop '$modName'",
                         "crm configure delete '$modName'");
                }
            }
        }
    }
    if (@rootCmds > 0) {
        EBox::Sudo::root(@rootCmds);
        if (@moves > 0) {
            # Do the initial movements after adding new primitives
            @rootCmds = ();
            foreach my $modName (@moves) {
                if ($self->_resourceCanBeMovedToNode($modName, $activeNode)) {
                    push(@rootCmds,
                         "crm_resource --resource '$modName' --clear",  # Clear any previous outdated constraint
                         "crm_resource --resource '$modName' --move --host '$activeNode' --lifetime 'P30S'");
                }
            }
            if (@rootCmds > 0) {
                EBox::Sudo::root(@rootCmds);
            }
        }
    }
}

# Set no-quorum-policy based on the node list size
sub _setNoQuorumPolicy
{
    my ($self, $size) = @_;

    # In two-node we have to set no-quorum-policy to ignore
    my $noQuorumPolicy = 'stop';
    $noQuorumPolicy = 'ignore' if ($size == 2);
    EBox::Sudo::root("crm configure property no-quorum-policy=$noQuorumPolicy");
}

sub _generateReplicationBundle
{
    my ($self, $modules) = @_;

    my @modules = @{$modules};
    EBox::info("Generating replication bundle of the following modules: @modules");
    my $tarfile = 'bundle.tar.gz';
    my $tmpdir = mkdtemp(EBox::Config::tmp() . 'replication-bundle-XXXX');

    write_file("$tmpdir/modules.json", encode_json($modules));

    foreach my $modname (@modules) {
        my $mod = EBox::Global->modInstance($modname);
        $mod->makeBackup($tmpdir);
    }

    system ("mkdir -p $tmpdir/files");
    foreach my $dir (@{EBox::Config::list('ha_conf_dirs')}) {
        next unless (-d $dir);
        EBox::Sudo::root("cp -a --parents $dir $tmpdir/files/");
    }

    EBox::Sudo::root("cd $tmpdir; tar czf $tarfile *");
    EBox::debug("Replication bundle generated");

    my $path = "$tmpdir/$tarfile";
    return ($tmpdir, $path);

}

sub _uploadReplicationBundle
{
    my ($self, $node, $file) = @_;

    my $secret = $self->userSecret();
    my $addr = $node->{addr};
    my $port = $node->{port};
    system ("curl -k -F file=\@$file https://zentyal:$secret\@$addr:$port/cluster/conf/replication");
    if ($? != 0) {
        throw EBox::Exceptions::External("Error uploading replication bundle to $addr");
    }
    EBox::info("Replication bundle uploaded to $addr");
}

sub _askForConf
{
    my ($self, $node) = @_;

    my $clusterSecret = $self->userSecret();
    my $client = new EBox::RESTClient(
        credentials => {realm => 'Zentyal HA', username => 'zentyal',
                        password => $clusterSecret},
            server => $node->{addr},
            verifyPeer => 0,
           );
    $client->setPort($node->{port});

    try {
        my $localNode = new EBox::HA::NodeList($self)->localNode();
        $client->POST('/cluster/conf/ask/replication/' . $localNode->{name});
    } catch ($e) {
        # Catch any exception
        EBox::error('Error asking for replication to ' . $node->{name} . ": $e");
    }
}

# Check if restart is required
# Cases:
#  1 - Not required if replicating flag is set
#  2 - Required if ifup was done
#  3 - Restart from CLI or UI
#  4 - Cluster bootstrap
#  5 - Actions defined in _setConf
#  5.1 - Leaving a cluster
#  5.2 - changing the network communication
#  6 - Changing enabled status
sub _restartRequired
{
    my ($self, %params) = @_;

    my $state = $self->get_state();
    if ($state->{replicating}) {
        return 0;
    }

    my $required = 0;
    my $net = $self->global->modInstance('network');
    if ($net->flagIfUp()) {
        $net->unsetFlagIfUp();
        $required = 1;
    }

    # Set by leaving the cluster and changing the network communication
    if ($self->{restart_required}) {
        delete $self->{restart_required};
        $required = 1;
    }

    if ($required) {
        return 1;
    }

    if (exists $params{restartModules} or exists $params{restartUI}) {
        return 1;
    }

    if ($state->{bootstraping}) {
        return 1;
    }

    # Set restart required if the enabled status has changed
    my $enabled = $self->isEnabled();
    if ($enabled != $self->isRunning() or (not $enabled)) {
        return 1;
    }

    return 0;
}

# Stop single instance modules and let the cluster decide for them to locate
# if not active node
sub _stopSingleInstanceMods
{
    my ($self) = @_;

    my $state = $self->get_state();
    if (exists $state->{new_enabled_modules}) {
        my $gl = $self->global();
        foreach my $modName (keys %{$state->{new_enabled_modules}}) {
            my $mod = $gl->modInstance($modName);
            $mod->stopService();
        }
        delete $state->{new_enabled_modules};
        $self->set_state($state);
    }
}

1;
