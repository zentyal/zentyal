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

use feature qw(switch);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::HA::NodeList;
use EBox::RESTClient;
use EBox::Sudo;
use JSON::XS;
use File::Temp;
use File::Slurp;
use TryCatch::Lite;

# Constants
use constant {
    COROSYNC_CONF_FILE    => '/etc/corosync/corosync.conf',
    COROSYNC_DEFAULT_FILE => '/etc/default/corosync',
    DEFAULT_MCAST_PORT => 5405,
};

my %REPLICATE_MODULES = map { $_ => 1 } qw(dhcp dns firewall ips network objects services squid trafficshaping ca openvpn);

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
#     Add a node to the cluster.
#
#     * Store the new node
#     * Send info to other members of the cluster (TODO)
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

    use Data::Dumper;
    EBox::info('Add node (params): ' . Dumper($params));

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    $params->{localNode} = 0;  # Local node is always set manually
    $list->set(%{$params});

    # Write corosync conf
    $self->_corosyncSetConf();

    # Dynamically add the new node to corosync
    my $newNode = $list->node($params->{name});
    EBox::Sudo::root('corosync-cmapctl -s nodelist.node.' . ($newNode->{nodeid} - 1)
                     . '.nodeid u32 ' . $newNode->{nodeid},
                     'corosync-cmapctl -s nodelist.node.' . ($newNode->{nodeid} - 1)
                     . '.name str ' . $newNode->{name},
                     'corosync-cmapctl -s nodelist.node.' . ($newNode->{nodeid} - 1)
                     . '.ring0_addr str ' . $newNode->{addr});

}

# Method: deleteNode
#
#    Delete node from the cluster.
#
#    * Delete the node
#    * Send cluster configuration to other members (TODO)
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

    use Data::Dumper;
    EBox::info('delete node (params): ' . Dumper($params));

    # TODO: Check incoming data
    my $list = new EBox::HA::NodeList($self);
    my $deletedNode = $list->node($params->{name});
    $list->remove($params->{name});
    # TODO: Notify other members

    # Write corosync conf
    $self->_corosyncSetConf();

    # Dynamically remove the new node to corosync
    EBox::Sudo::root(
        'corosync-cmapctl -D nodelist.node.' . ($deletedNode->{nodeid} - 1) . '.ring0_addr',
        'corosync-cmapctl -D nodelist.node.' . ($deletedNode->{nodeid} - 1) . '.name',
        'corosync-cmapctl -D nodelist.node.' . ($deletedNode->{nodeid} - 1) . '.nodeid');

}

sub confReplicationStatus
{
    my ($self) = @_;

    return { errors => 0 };
}

sub replicateConf
{
    my ($self, $params, $body, $uploads) = @_;

    my $tmpdir = mkdtemp(EBox::Config::tmp() . 'replication-bundle-XXXX');

    my $file = $uploads->get('file');
    my $path = $file->path;
    system ("tar xzf $path -C $tmpdir");

    # TODO: extract /etc/zentyal and /var/lib/zentyal/CA

    my $modules = decode_json(read_file("$tmpdir/modules.json"));

    foreach my $modname (@{$modules}) {
        EBox::info("Replicating conf of module: $modname");
        my $mod = EBox::Global->modInstance($modname);
        $mod->restoreBackup("$tmpdir/$modname.bak");
    }

    EBox::Global->saveAllModules();

    EBox::Sudo::root("rm -rf $tmpdir");
}

sub askForReplication
{
    my ($self, $modules) = @_;

    foreach my $node (@{$self->nodes()}) {
        next if ($node->{localNode});
        my $addr = $node->{addr};
        $self->askForReplicationInNode($addr, $modules);
    }
}

sub askForReplicationInNode
{
    my ($self, $addr, $modules) = @_;

    my $tarfile = 'bundle.tar.gz';
    my $tmpdir = mkdtemp(EBox::Config::tmp() . 'replication-bundle-XXXX');

    write_file("$tmpdir/modules.json", encode_json($modules));

    foreach my $modname (@{$modules}) {
        next unless $REPLICATE_MODULES{$modname};
        my $mod = EBox::Global->modInstance($modname);
        $mod->makeBackup($tmpdir);
    }

    # TODO: include /etc/zentyal and /var/lib/zentyal/CA

    system ("cd $tmpdir; tar czf $tarfile *");
    my $fullpath = "$tmpdir/$tarfile";
    system ("curl -F file=\@$fullpath http://$addr:5000/conf/replication");

    EBox::Sudo::root("rm -rf $tmpdir");
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

    my $remoteHost = $clusterSettings->row()->valueByName('cluster_zentyal');
    my $client = new EBox::RESTClient(server => $remoteHost->{zentyal_host});
    $client->setPort($remoteHost->{zentyal_port});
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
    my $row = $clusterSettings->row();
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

1;
