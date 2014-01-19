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
use EBox::Sudo;

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

    my $iface = $clusterSettings->interfaceValue();
    my $network = EBox::Global->getInstance()->modInstance('network');
    # TODO: Launch exception when network addr is undef / Which exception?
    my $ifaces = [ { iface => $iface, netAddr => $network->ifaceNetwork($iface) }];
    my $localNodeAddr = $network->ifaceAddress($iface);
    if (ref($localNodeAddr) eq 'ARRAY') {
        $localNodeAddr = $localNodeAddr->[0];  # Take the first option
    }

    if ($clusterSettings->configurationValue() eq 'start_new') {
        $self->_bootstrapNodes($localNodeAddr);
    }

    my $nodes = [];
    my $multicastConf = {};
    my $transport;
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
    my @params = (
        interfaces    => $ifaces,
        nodes         => $nodes,
        transport     => $transport,
        multicastConf => $multicastConf,
    );

    $self->writeConfFile(
        COROSYNC_CONF_FILE,
        "ha/corosync.conf.mas",
        \@params,
        { uid => '0', gid => '0', mode => '644' }
    );
}

# Bootstrap a node list
sub _bootstrapNodes
{
    my ($self, $localNodeAddr) = @_;

    my $nodeList = new EBox::HA::NodeList($self);
    # TODO: set proper name and port
    $nodeList->set(name => 'local', addr => $localNodeAddr, webAdminPort => 443);
}

1;
