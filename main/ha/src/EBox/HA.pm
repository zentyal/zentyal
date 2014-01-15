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
use EBox::Global;
use EBox::Gettext;
use EBox::HA::NodeList;
use EBox::RESTClient;
use EBox::Sudo;
use JSON::XS;
use File::Temp;
use File::Slurp;

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

    $system->add(new EBox::Menu::Item(
        url => 'HA/Composite/HA',
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

# Method: clusterConfiguration
#
#     Return the cluster configuration
#
# Returns:
#
#     Hash ref - the cluster configuration
#
#        - transport: String 'udp' for multicast and 'udpu' for unicast
#        - multicastConf: Hash ref with addr, port and expected_votes as keys
#        - nodes: Array ref the node list including IP address, name and webadmin port
#                 Only for unicast configuration
#
sub clusterConfiguration
{
    my ($self) = @_;

    # TODO: Store everything in Redis state
    my ($multicastConf, $transport, $nodes) = ({}, undef, []);
    my $multicastAddr = EBox::Config::configkey('ha_multicast_addr');
    if ($multicastAddr) {
        # Multicast configuration
        my $multicastPort = EBox::Config::configkey('ha_multicast_port') || DEFAULT_MCAST_PORT;
        $multicastConf = { addr => $multicastAddr,
                           port => $multicastPort,
                           expected_votes => scalar(@{new EBox::HA::NodeList($self)->list()}),
                          };
        $transport = 'udp';
    } else {
        # Unicast configuration
        $nodes = new EBox::HA::NodeList($self)->list(),
        $transport = 'udpu';
    }

    return { transport     => $transport,
             multicastConf => $multicastConf,
             nodes         => $nodes };
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

    my $list = new EBox::HA::NodeList($self);
    $params->{localNode} = 0;  # Local node is always set manually
    $list->set(%{$body});
}

# Method: removeNode
#
#     Get the active nodes from a cluster
#
# Returns:
#
#     Array ref - See <EBox::HA::NodeList::list> for details
#
sub removeNode
{
    my ($self) = @_;
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

    my $modules = decode_json(read_file("$tmpdir/modules.json"));

    foreach my $modname (@{$modules}) {
        print "Restoring module $modname...\n";
        my $mod = EBox::Global->modInstance($modname);
        $mod->restoreBackup("$tmpdir/$modname.bak");
    }

    EBox::Sudo::root("rm -rf $tmpdir");
}

sub askForReplication
{
    my ($self) = @_;

    my @REPLICATE_MODULES = qw(dhcp dns firewall ips network objects services squid trafficshaping);

    my $tarfile = 'bundle.tar.gz';
    my $tmpdir = mkdtemp(EBox::Config::tmp() . 'replication-bundle-XXXX');

    my $modules = [];
    for my $modname (@REPLICATE_MODULES) {
        # FIXME: only if unsaved
        if (EBox::Global->modExists($modname)) {
            push (@{$modules}, $modname);
        }
    }
    write_file("$tmpdir/modules.json", encode_json($modules));

    foreach my $modname (@{$modules}) {
        my $mod = EBox::Global->modInstance($modname);
        $mod->makeBackup($tmpdir);
    }

    system ("cd $tmpdir; tar czf $tarfile *");
    my $fullpath = "$tmpdir/$tarfile";
    system ("curl -F file=\@$fullpath http://localhost:5000/conf/replication");

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

    $self->_corosyncSetConf();
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

    my $iface = $clusterSettings->interfaceValue();
    my $network = EBox::Global->getInstance()->modInstance('network');
    # TODO: Launch exception when network addr is undef / Which exception?
    my $ifaces = [ { iface => $iface, netAddr => $network->ifaceNetwork($iface) }];
    my $localNodeAddr = $network->ifaceAddress($iface);
    if (ref($localNodeAddr) eq 'ARRAY') {
        $localNodeAddr = $localNodeAddr->[0];  # Take the first option
    }

    if ($clusterSettings->configurationValue() eq 'start_new') {
        $self->_bootstrap($localNodeAddr);
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
sub _bootstrap
{
    my ($self, $localNodeAddr) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    # TODO: set proper name and port
    $nodeList->set(name => 'local', addr => $localNodeAddr, webAdminPort => 443);
}

1;
