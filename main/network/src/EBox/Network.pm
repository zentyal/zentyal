# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Network;

use base qw(EBox::Module::Service);

# Group: Constants

# Interfaces list which will be ignored
use constant ALLIFACES => qw(sit tun tap lo irda eth wlan vlan);
use constant IGNOREIFACES => qw(sit tun tap lo irda ppp virbr vboxnet vnet);
use constant IFNAMSIZ => 16; #Max length name for interfaces
use constant INTERFACES_FILE => '/etc/network/interfaces';
use constant RESOLV_FILE => '/etc/resolv.conf';
use constant DHCLIENTCONF_FILE => '/etc/dhcp/dhclient.conf';
use constant PPP_PROVIDER_FILE => '/etc/ppp/peers/zentyal-ppp-';
use constant CHAP_SECRETS_FILE => '/etc/ppp/chap-secrets';
use constant PAP_SECRETS_FILE => '/etc/ppp/pap-secrets';
use constant APT_PROXY_FILE => '/etc/apt/apt.conf.d/99proxy';
use constant ENV_FILE       => '/etc/environment';
use constant SYSCTL_FILE => '/etc/sysctl.conf';
use constant RESOLVCONF_INTERFACE_ORDER => '/etc/resolvconf/interface-order';
use constant RESOLVCONF_BASE => '/etc/resolvconf/resolv.conf.d/base';
use constant RESOLVCONF_HEAD => '/etc/resolvconf/resolv.conf.d/head';
use constant RESOLVCONF_TAIL => '/etc/resolvconf/resolv.conf.d/tail';
use constant FAILOVER_CRON_FILE => '/etc/cron.d/zentyal-network';

use Net::IP;
use Net::Interface;
use Perl6::Junction qw(any);
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);
use EBox::Config;
use EBox::Service;
use EBox::ServiceManager;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Lock;
use EBox::Exceptions::DataNotFound;
use TryCatch;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Section;
use EBox::Dashboard::CounterGraph;
use EBox::Dashboard::GraphRow;
use EBox::Dashboard::Value;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo;
use EBox::Gettext;
use EBox::Common::Model::EnableForm;
use EBox::Util::Lock;
use EBox::Util::Version;
use EBox::DBEngineFactory;
use File::Basename;
use File::Slurp;
use YAML::XS;

use constant FAILOVER_CHAIN => 'FAILOVER-TEST';
use constant CHECKIP_CHAIN => 'CHECKIP-TEST';

# Group: Public methods

# Method: localGatewayIP
#
#       Return the local IP address that may be used as the gateway for the given IP or undef if Zentyal is not
#       directly connected with the given IP.
#
# Parameters:
#
#       ip - String the IP address for the client that will use the returning IP address as gateway.
#
# Returns:
#
#       String - Zentyal's IP address that would act as the gateway. undef if not reachable.
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory argument is missing
#
sub localGatewayIP
{
    my ($self, $ip) = @_;

    $ip or throw EBox::Exceptions::MissingArgument('ip');

    my $iface = $self->gatewayReachable($ip);
    return undef unless ($iface);
    return $self->ifaceAddress($iface);
}

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'network',
                    printableName => __('Network'),
                    @_);
    $self->{'actions'} = {};

    bless($self, $class);

    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Add default routers to the default table'),
        'reason' => __('This is needed to work with a multigateway ' .
                    'configuration. Note that to list the default routes you ' .
                    'must execute: ') . ' ip route ls table default ',
        'module' => 'network'
    },
    {
        'action' => __('Enable Zentyal DHCP hook'),
        'reason' => __('It will take care of adding the default route' .
                ' given by a DHCP server to the default route table. '),
        'module' => 'network'
    },
    {
        'action' => __('Disable IPv6'),
        'reason' => __('Zentyal does not support yet IPv6, having v6 ' .
                       'addresses asigned to interfaces can cause problems ' .
                       'on some services'),
        'module' => 'network'
    },
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    my ($self) = @_;

    my @files = (
    {
        'file' => INTERFACES_FILE,
        'reason' => __('Zentyal will set your network configuration'),
        'module' => 'network'
    },
    {
        'file' => RESOLVCONF_INTERFACE_ORDER,
        'reason' => __('Zentyal will set the order of systems resolvers'),
        'module' => 'network'
    },
    {
        'file' => RESOLVCONF_BASE,
        'reason' => __('Zentyal will set the resolvconf configuration'),
        'module' => 'network'
    },
    {
        'file' => RESOLVCONF_HEAD,
        'reason' => __('Zentyal will set the resolvconf configuration'),
        'module' => 'network'
    },
    {
        'file' => RESOLVCONF_TAIL,
        'reason' => __('Zentyal will set the resolvconf configuration'),
        'module' => 'network'
    },
    {
        'file' => DHCLIENTCONF_FILE,
        'reason' => __('Zentyal will set your DHCP client configuration'),
        'module' => 'network'
    },
    {
        'file' => SYSCTL_FILE,
        'reason' => __('Zentyal will disable IPV6 on this system'),
        'module' => 'network'
    },
    );

    foreach my $iface (@{$self->pppIfaces()}) {
        push (@files, { 'file' => PPP_PROVIDER_FILE . $iface,
                        'reason' => __('Zentyal will add a DSL provider configuration for PPPoE'),
                        'module' => 'network' });
    }

    my $proxy = $self->model('Proxy');
    if ($proxy->serverValue() and $proxy->portValue()) {
        push (@files, { 'file' => ENV_FILE,
                        'reason' => __('Zentyal will set HTTP proxy for all users'),
                        'module' => 'network' });
        push (@files, { 'file' => APT_PROXY_FILE,
                        'reason' => __('Zentyal will set HTTP proxy for APT'),
                        'module' => 'network' });
    }

    return \@files;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    EBox::Sudo::silentRoot('systemctl stop systemd-resolved');
    EBox::Sudo::silentRoot('systemctl disable systemd-resolved');
    EBox::Sudo::silentRoot('resolvconf -d systemd-resolved');
    EBox::Sudo::silentRoot('rm -f /etc/dhcp/dhclient-enter-hooks.d/resolved');

    foreach my $service (@{$self->_defaultServices()}) {
        $service->{'sourcePort'} = 'any';
        $service->{'readOnly'} = 1;
        if ($self->serviceExists('name' => $service->{'name'})) {
            $self->setService(%{$service});
        } else {
            $self->addService(%{$service});
        }
    }

    # Import network configuration from system
    # only if installing the first time
    unless ($version) {
        try {
            $self->importInterfacesFile();
            $self->_importDHCPAddresses();
            if ($self->changed()) {
                $self->saveConfigRecursive();
            }
        } catch ($e) {
            EBox::warn("Network configuration import failed: $e");
        }
    }

    if (defined ($version) and (EBox::Util::Version::compare($version, '5.0') < 0)) {
        my $redis = $self->redis();
        foreach my $mod (qw(services objects)) {
            my @keys = $redis->_keys("$mod/*");
            foreach my $key (@keys) {
                next if ($key eq "$mod/state");
                my $newkey = $key;
                $newkey =~ s/^$mod/network/;
                $redis->set($newkey, $redis->get($key));
            }
            $redis->unset(@keys);
        }
    }
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Disable IPv6 if it is enabled
    if (-d  '/proc/sys/net/ipv6') {
        my @cmds;
        push (@cmds, 'sed -ri "/net\.ipv6\.conf\.all\.disable_ipv6/d" ' . SYSCTL_FILE);
        push (@cmds, 'sed -ri "/net\.ipv6\.conf\.default\.disable_ipv6/d" ' . SYSCTL_FILE);
        push (@cmds, 'sed -ri "/net\.ipv6\.conf\.lo\.disable_ipv6/d" ' . SYSCTL_FILE);

        push (@cmds, 'echo "net.ipv6.conf.all.disable_ipv6 = 1" >> ' . SYSCTL_FILE);
        push (@cmds, 'echo "net.ipv6.conf.default.disable_ipv6 = 1" >> ' . SYSCTL_FILE);
        push (@cmds, 'echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> ' . SYSCTL_FILE);

        push (@cmds, 'sysctl -p');

        EBox::Sudo::root(@cmds);
    }
    $self->_importDHCPAddresses();
}

# Method: wizardPages
#
#   Override EBox::Module::Base::wizardPages
#
sub wizardPages
{
    my ($self) = @_;

    return [
        { page => '/Network/Wizard/Ifaces', order => 100 },
        { page => '/Network/Wizard/Network', order => 101 },
    ];
}

# Method: ExternalIfaces
#
#   Returns  a list of all external interfaces
#
# Returns:
#
#      array ref - holding the external interfaces
#
sub ExternalIfaces
{
    my $self = shift;
    my @ifaces = @{$self->ifaces};
    my @array = ();
    foreach (@ifaces) {
        ($self->ifaceMethod($_) eq 'notset') and next;
        ($self->ifaceMethod($_) eq 'trunk') and next;
        ($self->ifaceMethod($_) eq 'bundled') and next;
        if ($self->ifaceIsExternal($_)) {
            push(@array, $_);
        }
    }
    return \@array;
}

# Method: externalIpAddresses
#
#   Returs a list of external IP addresses
#
# Returns:
#
#   array ref - Holding the external IP's
#
sub externalIpAddresses
{
    my ($self) = @_;

    my $ips = [];

    my $externalInterfaces = $self->ExternalIfaces();
    foreach my $interface (@{$externalInterfaces}) {
        foreach my $interfaceInfo (@{$self->ifaceAddresses($interface)}) {
            next unless (defined $interfaceInfo);
            push @{$ips}, $interfaceInfo->{address};
        }
    }

    return $ips;
}

# Method: InternalIfaces
#
#   Returns  a list of all internal interfaces
#
# Returns:
#
#      array ref - holding the internal interfaces
#
sub InternalIfaces
{
    my $self = shift;
    my @ifaces = @{$self->ifaces};
    my @array = ();
    foreach (@ifaces) {
        ($self->ifaceMethod($_) eq 'notset') and next;
        ($self->ifaceMethod($_) eq 'trunk') and next;
        ($self->ifaceMethod($_) eq 'bundled') and next;
        unless ($self->ifaceIsExternal($_)) {
            push(@array, $_);
        }
    }
    return \@array;
}

# Method: internalIpAddresses
#
#   Returs a list of internal IP addresses
#
# Returns:
#
#   array ref - Holding the internal IP's
#
sub internalIpAddresses
{
    my ($self) = @_;

    my $ips = [];

    my $internalInterfaces = $self->InternalIfaces();
    foreach my $interface (@{$internalInterfaces}) {
        foreach my $interfaceInfo (@{$self->ifaceAddresses($interface)}) {
            next unless (defined $interfaceInfo);
            push @{$ips}, $interfaceInfo->{address};
        }
    }

    return $ips;
}

# Method: internalNetworks
#
#   Returs a list of internal networks
#
# Returns:
#
#   array ref - Holding the internal network IP addresses using CIDR
#
sub internalNetworks
{
    my ($self) = @_;

    my @intNets;

    foreach my $iface (@{$self->InternalIfaces()}) {
        my $net = $self->ifaceNetwork($iface);
        if ($net) {
            my $fullmask = $self->ifaceNetmask($iface);
            my $mask = EBox::NetWrappers::bits_from_mask($fullmask);
            push(@intNets, "$net/$mask");
        }
    }
    return \@intNets;
}

# Method: ifaceExists
#
#   Checks if a given interface exists
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   boolean - true, if the interface exists, otherwise false
sub ifaceExists # (interface)
{
    my ($self, $name) = @_;
    defined($name) or return undef;
    if ($self->vifaceExists($name)) {
        return 1;
    }
    if (iface_exists($name)) {
        return 1;
    }
    my $ifaces = $self->ifaces;
    if (grep(/^$name$/, @{$ifaces})) {
        return 1;
    }
    return undef;
}

# Method: ifaceIsExternal
#
#   Checks if a given iface exists and is external
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   boolean - true, if the interface is external, otherwise false
sub ifaceIsExternal # (interface)
{
    my ($self, $iface) = @_;
    defined($iface) or return undef;

    if ($self->vifaceExists($iface)) {
        my @aux = $self->_viface2array($iface);
        $iface = $aux[0];
    }
    if ($self->ifaceIsBridge($iface)) {
        # Bridges are external if any of their interfaces is external
        my $ifaces = $self->bridgeIfaces($iface);
        foreach my $bridged ( @{$ifaces} ) {
            return 1 if ($self->ifaceIsExternal($bridged));
        }
        return 0;
    }
    if ($self->ifaceIsBond($iface)) {
        # Bonds are external if any of their interfaces is external
        my $ifaces = $self->bondIfaces($iface);
        foreach my $bundled ( @{$ifaces} ) {
            return 1 if ($self->ifaceIsExternal($bundled));
        }
        return 0;
    }
    return $self->get_hash('interfaces')->{$iface}->{external} ? 1 : 0;
}

# Method: ifaceIsBridge
#
#   Checks if a given iface exists and is a bridge
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   boolean - true, if the interface is external, otherwise false
sub ifaceIsBridge # (interface)
{
    my ($self, $iface) = @_;
    defined($iface) or return undef;

    if ( $self->ifaceExists($iface) and $iface =~ /^br/ and not ($iface =~ /:/)) {
        return 1;
    } else {
        return 0;
    }
}

# Method: ifaceIsBond
#
#   Checks if a given iface exists and is a bond
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   boolean - true, if the interface is external, otherwise false
sub ifaceIsBond # (interface)
{
    my ($self, $iface) = @_;
    defined($iface) or return undef;

    if ( $self->ifaceExists($iface) and $iface =~ /^bond/ and not ($iface =~ /:/)) {
        return 1;
    } else {
        return 0;
    }
}

# Method: ifaceOnConfig
#
#   Checks if a given iface is configured
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   boolean - true, if the interface is configured, otherwise false
#
sub ifaceOnConfig
{
    my ($self, $name) = @_;

    defined($name) or return undef;
    if ($self->vifaceExists($name)) {
        return 1;
    }

    return defined($self->get_hash('interfaces')->{$name}->{method});
}

# Method: netInitRange
#
#   Return the initial host address range for a given interface
#
# Parameters:
#
#   iface - String interface name
#
# Returns:
#
#   String - containing the initial range
#
sub netInitRange # (interface)
{
    my ($self, $iface) = @_;

    my $address = $self->ifaceAddress($iface);
    my $netmask = $self->ifaceNetmask($iface);

    my $network = ip_network($address, $netmask);
    my ($first, $last) = $network =~ /(.*)\.(\d+)$/;
    my $init_range = $first . "." . ($last + 1);

    return $init_range;
}

# Method: netEndRange
#
#   Return the final host address range for a given interface
#
# Parameters:
#
#   iface - String interface name
#
# Returns:
#
#   string - containing the final range
#
sub netEndRange # (interface)
{
    my ($self, $iface) = @_;

    my $address = $self->ifaceAddress($iface);
    my $netmask = $self->ifaceNetmask($iface);

    my $broadcast = ip_broadcast($address, $netmask);
    my ($first, $last) = $broadcast =~ /(.*)\.(\d+)$/;
    my $end_range = $first . "." . ($last - 1);

    return $end_range;
}

sub _ignoreIface
{
    my ($self, $name) = @_;

    my $ignore_ifaces = EBox::Config::configkey('ifaces_to_ignore');
    my @ifaces_to_ignore;
    if (defined($ignore_ifaces)) {
        @ifaces_to_ignore = split(',', $ignore_ifaces);
    } else {
        @ifaces_to_ignore = IGNOREIFACES;
    }
    foreach my $ignore (@ifaces_to_ignore) {
        return 1 if  ($name =~ /$ignore.?/);
    }

    return undef;
}

# given a list of network interfaces appends to it any existing vlan interface
# not already in the list and removes from it any vlan interface which has been
# deleted from the configuration.
sub _vlanIfaceFilter # (\array)
{
    my ($self, $ifaces) = @_;
    my @array = ();

    foreach my $if (@{$ifaces}) {
        unless ($if =~ /^vlan/) {
            push(@array, $if);
        }
    }

    my $vlans = $self->vlans();
    foreach my $id (@{$vlans}) {
        push(@array, "vlan$id");
    }
    return \@array;
}

# given a list of network interfaces appends to it any existing vlan interface
# not already in the list
sub _vlanIfaceFilterWithRemoved # (\array)
{
    my ($self, $ifaces) = @_;
    my $vlans = $self->vlans();
    foreach my $id (@{$vlans}) {
        unless (grep(/^vlan$id$/, @{$ifaces})) {
            push(@{$ifaces}, "vlan$id");
        }
    }
    return $ifaces;
}

sub _cleanupVlanIfaces
{
    my $self = shift;
    my @iflist = list_ifaces();
    my @cmds;
    foreach my $iface (@iflist) {
        if ($iface =~ /^vlan/) {
            $iface =~ s/^vlan//;
            my $vlans = $self->get_hash('vlans');
            unless (exists $vlans->{$iface}) {
                push (@cmds, "/sbin/vconfig rem vlan$iface");
            }
        }
    }
    EBox::Sudo::root(@cmds);
}

# given a list of network interfaces appends to it any existing bridged interface
# not already in the list and removes from it any bridged interface which has been
# deleted from the configuration.
sub _bridgedIfaceFilter # (\array)
{
    my ($self, $ifaces) = @_;
    my @array = ();

    foreach my $if (@{$ifaces}) {
        unless ($if =~ /^br/) {
            push(@array, $if);
        }
    }

    my $bridges = $self->bridges();
    foreach my $id (@{$bridges}) {
        push(@array, "br$id");
    }
    return \@array;
}

# given a list of network interfaces appends to it any existing bonded interface
# not already in the list and removes from it any bonded interface which has been
# deleted from the configuration.
sub _bundledIfaceFilter # (\array)
{
    my ($self, $ifaces) = @_;
    my @array = ();

    foreach my $if (@{$ifaces}) {
        unless ($if =~ /^bond/) {
            push(@array, $if);
        }
    }

    my $bonds = $self->bonds();
    foreach my $id (@{$bonds}) {
        push(@array, "bond$id");
    }
    return \@array;
}

# given a list of network interfaces appends to it any existing bridge interface
# not already in the list
sub _bridgedIfaceFilterWithRemoved # (\array)
{
    my ($self, $ifaces) = @_;
    my $bridges = $self->bridges();
    foreach my $id (@{$bridges}) {
        unless (grep(/^br$id$/, @{$ifaces})) {
            push(@{$ifaces}, "br$id");
        }
    }
    return $ifaces;
}

# given a list of network interfaces appends to it any existing bond interface
# not already in the list
sub _bundledIfaceFilterWithRemoved # (\array)
{
    my ($self, $ifaces) = @_;
    my $bonds = $self->bonds();
    foreach my $id (@{$bonds}) {
        unless (grep(/^bond$id$/, @{$ifaces})) {
            push(@{$ifaces}, "bond$id");
        }
    }
    return $ifaces;
}

sub _ifaces
{
    my $self = shift;
    my @iflist = list_ifaces();
    my @array = ();
    foreach my $iface (@iflist) {
        next if $self->_ignoreIface($iface);
        push(@array, $iface);
    }
    return \@array;
}

# Method: ifaces
#
#   Returns the name of all real interfaces, including vlan interfaces
#
# Returns:
#
#   array ref - holding the names
sub ifaces
{
    my $self = shift;
    my $ifaces = $self->_ifaces();
    $ifaces = $self->_vlanIfaceFilter($ifaces);
    $ifaces = $self->_bridgedIfaceFilter($ifaces);
    $ifaces = $self->_bundledIfaceFilter($ifaces);
    return $ifaces;
}

# Method: ifacesWithRemoved
#
#   Returns the name of all real interfaces, including
#   vlan interfaces (both existing ones and those that are going to be
#   removed when the configuration is saved)
# Returns:
#
#   array ref - holding the names
sub ifacesWithRemoved
{
    my $self = shift;
    my $ifaces = $self->_ifaces();
    $ifaces = $self->_vlanIfaceFilterWithRemoved($ifaces);
    $ifaces = $self->_bridgedIfaceFilterWithRemoved($ifaces);
    $ifaces = $self->_bundledIfaceFilterWithRemoved($ifaces);
    return $ifaces;
}

# Method: ifaceAddresses
#
#   Returns an array of hashes with "address" and "netmask" fields, the
#   array may be empty (i.e. for a dhcp interface that did not get an
#   address)
#
# Parameters:
#
#   iface - the name of a interface
#
# Returns:
#
#   an array ref - holding hashes with keys 'address' and 'netmask'
#
sub ifaceAddresses
{
    my ($self, $iface) = @_;
    my @array = ();

    if ($self->vifaceExists($iface)) {
        return \@array;
    }

    if ($self->ifaceMethod($iface) eq 'static') {
        my $addr = $self->get_hash('interfaces')->{$iface}->{address};
        my $mask = $self->get_hash('interfaces')->{$iface}->{netmask};
        push(@array, {address => $addr, netmask => $mask});
        my $virtual = $self->get_hash('interfaces')->{$iface}->{virtual};
        foreach my $name (keys %{$virtual}) {
            my $viface = $virtual->{$name};
            push(@array, { address => $viface->{address},
                           netmask => $viface->{netmask},
                           name => $name });
        }
    } elsif ($self->ifaceMethod($iface) eq any('dhcp', 'ppp')) {
        my $addr = $self->DHCPAddress($iface);
        my $mask = $self->DHCPNetmask($iface);
        if ($addr) {
            push(@array, {address => $addr, netmask => $mask});
        }
    } elsif ($self->ifaceMethod($iface) eq 'bridged') {
        my $bridge = $self->ifaceBridge($iface);
        if ($self->ifaceExists("br$bridge")) {
            return $self->ifaceAddresses("br$bridge");
        }
    #} elsif ($self->ifaceMethod($iface) eq 'bundled') {
    #    my $bond = $self->ifaceBond($iface);
    #    if ($self->ifaceExists("bond$bond")) {
    #        return $self->ifaceAddresses("bond$bond");
    #    }
    }
    return \@array;
}

# Method: ifaceByAddress
#
# given a IP address it returns the interface which has it local address
# or undef if it is nothing. Loopback interface is also acknowledged
#
#  Parameters:
#    address - IP address
#
#  Limitations:
#    only checks interfaces managed by the network module, with the exception
#    of loopback
sub ifaceByAddress
{
    my ($self, $address) = @_;
    EBox::Validate::checkIP($address) or
          throw EBox::Exceptions::External(__('Argument must be a IP address'));

    foreach my $iface (@{ $self->allIfaces() }) {
        my @addrs = @{ $self->ifaceAddresses($iface) };
        foreach my $addr_r (@addrs) {
            if ($addr_r->{address}  eq $address) {
                return $iface;
            }
        }
    }

    if ($address =~ m/^127\.*/) {
        return 'lo';
    }

    return undef;
}

# Method: vifacesConf
#
#   Gathers virtual interfaces from a real interface with their conf
#   arguments
#
# Parameters:
#
#   iface - the name of a interface
#
# Returns:
#
#   an array ref - holding hashes with keys 'address' and 'netmask'
#                  'name'
#
sub vifacesConf
{
    my ($self, $iface) = @_;
    defined($iface) or return;

    my $vifaces = $self->get_hash('interfaces')->{$iface}->{virtual};
    my @array = ();
    foreach my $name (keys %{$vifaces}) {
        my $viface = $vifaces->{$name};
        if (defined $viface->{'address'}) {
            $viface->{name} = $name;
            push (@array, $viface);
        }
    }
    return \@array;
}

# Method: vifaceNames
#
#       Gathers all the  virtual interface names  from a real interface
#
# Parameters:
#
#       iface - the name of a interface
#
# Returns:
#
#       an array ref - holding the name of the virtual interfaces. Each name
#       is a composed name like this: realinterface:virtualinterface
#       (i.e: eth0:foo)
#
sub vifaceNames
{
    my ($self, $iface) = @_;
    my @array;

    foreach (@{$self->vifacesConf($iface)}) {
        push @array, "$iface:" . $_->{'name'};
    }
    return \@array;
}

sub _allIfaces
{
    my ($self, $ifaces) = @_;
    my @array;
    my @vifaces;

    @array = @{$ifaces};
    foreach (@array) {
        if ($self->ifaceMethod($_) eq 'static') {
            push @vifaces, @{$self->vifaceNames($_)};
        }
    }
    push @array, @vifaces;
    @array = sort @array;
    return \@array;
}

# Method: allIfaces
#
#       Returns all the names for all the interfaces, both real and virtual.
#
# Returns:
#
#       an array ref - holding the name of the interfaces.
#
sub allIfaces
{
    my $self = shift;
    return $self->_allIfaces($self->ifaces());
}

# Method: dhcpIfaces
#
#       Returns the names for all the DHCP interfaces.
#
# Returns:
#
#       an array ref - holding the name of the interfaces.
#
sub dhcpIfaces
{
    my ($self) = @_;
    my @dhcpifaces;

    foreach my $iface (@{$self->ifaces()}) {
        if ($self->ifaceMethod($iface) eq 'dhcp') {
            push (@dhcpifaces, $iface);
        }
    }
    return \@dhcpifaces;
}

# Method: pppIfaces
#
#       Returns the names for all the PPPoE interfaces.
#
# Returns:
#
#       an array ref - holding the name of the interfaces.
#
sub pppIfaces
{
    my ($self) = @_;
    my @pppifaces;

    foreach my $iface (@{$self->ifaces()}) {
        if ($self->ifaceMethod($iface) eq 'ppp') {
            push (@pppifaces, $iface);
        }
    }
    return \@pppifaces;
}

# Method: allIfacesWithRemoved
#
#   Return  the names of all (real and virtual) interfaces. This
#   method is similar to the ifacesWithRemoved method, it includes in the
#   results vlan interfaces which are going to be removed when the
#   configuration is saved.
#
# Returns:
#
#       an array ref - holding the name of the interfaces.
sub allIfacesWithRemoved
{
    my $self = shift;
    return $self->_allIfaces($self->ifacesWithRemoved());
}

# arguments
#   - the name of the real network interface
#   - the name of the virtual interface
# returns
#   - true if exists
#   - false if not
# throws
#   - Internal
#       - If real interface is not configured as static
#
sub _vifaceExists
{
    my ($self, $iface, $viface) = @_;

    unless ($self->ifaceMethod($iface) eq 'static') {
        throw EBox::Exceptions::Internal("Could not exist a virtual " .
                                         "interface in non-static interface");
    }

    return exists $self->get_hash('interfaces')->{$iface}->{virtual}->{$viface};
}

# split a virtual iface name in real interface and virtual interface
# arguments
#   - the composed virtual iface name
# returns
#   - an array with the split name
sub _viface2array # (interface)
{
    my ($self, $name) = @_;
    my @array = $name =~ /(.*):(.*)/;
    return @array;
}

# Method: vifaceExists
#
#   Checks if a given virtual interface exists
#
# Parameters:
#
#   interface - the name of  virtual interface composed by
#   realinterface:virtualinterface
#
# Returns:
#
#   boolean - true, if the interface is virtual and exists, otherwise false
#
sub vifaceExists # (interface)
{
    my ($self, $name) = @_;

    my ($iface, $viface) = $self->_viface2array($name);
    if (not $iface) {
        return undef;
    }
    if (not $viface and ($viface ne '0')) {
        return undef;
    }

    return $self->_vifaceExists($iface, $viface);
}

# Method: setViface
#
#   Configure a virtual  interface with ip and netmask
#   arguments
#
# Parameters:
#
#   iface - the name of a real network interface
#   viface - the name of the virtual interface
#   address - the IP address for the virtual interface
#   netmask - the netmask
#
# Exceptions:
#
#   DataExists - If interface already exists
#   Internal - If the real interface is not configured as static
#
sub setViface
{
    my ($self, $iface, $viface, $address, $netmask) = @_;

    unless ($self->ifaceMethod($iface) eq 'static') {
        throw EBox::Exceptions::Internal("Could not add virtual " .
                       "interface in non-static interface");
    }
    if ($self->_vifaceExists($iface, $viface)) {
        throw EBox::Exceptions::DataExists(
                    'data' => __('Virtual interface name'),
                    'value' => "$viface");
    }
    checkIPNetmask($address, $netmask, __('IP address'), __('Netmask'));
    checkVifaceName($iface, $viface, __('Virtual interface name'));

    my $ifaceSameAddress = $self->ifaceByAddress($address);
    if ($ifaceSameAddress) {
        throw EBox::Exceptions::DataExists(
            text => __x("Address {ip} is already in use by interface {iface}",
                ip => $address,
                iface => $ifaceSameAddress
               )
           );
    }

    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
    foreach my $mod (@mods) {
        $mod->vifaceAdded($iface, $viface, $address, $netmask);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$iface}->{virtual}->{$viface}->{address} = $address;
    $ifaces->{$iface}->{virtual}->{$viface}->{netmask} = $netmask;
    $ifaces->{$iface}->{changed} = 1;
    $self->set('interfaces', $ifaces);
}

# Method: removeViface
#
#   Removes a virtual interface
#
# Parameters:
#
#   iface - the name of a real network interface
#   viface - the name of the virtual interface
#   force - force deletion if in use
#
# Returns:
#
#   boolean - true if exists, otherwise false
#
# Exceptions:
#
#   Internal - If the real interface is not configured as static
#
sub removeViface
{
    my ($self, $iface, $viface, $force) = @_;

    unless ($self->ifaceMethod($iface) eq 'static') {
        throw EBox::Exceptions::Internal("Could not remove virtual " .
                              "interface from a non-static interface");
    }
    unless ($self->_vifaceExists($iface, $viface)) {
        return undef;
    }

    $self->_routersReachableIfChange("$iface:$viface");

    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
    foreach my $mod (@mods) {
        if ($mod->vifaceDelete($iface, $viface)) {
            if ($force) {
                $mod->freeViface($iface, $viface);
            } else {
                throw EBox::Exceptions::DataInUse();
            }
        }
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$iface}->{virtual}->{$viface};
    $ifaces->{$iface}->{changed} = 1;
    $self->set('interfaces', $ifaces);

    return 1;
}

# Method: vifaceAddress
#
#   Returns the configured address for a virutal interface
#
# Parameters:
#
#   interface - the composed name of a virtual interface
#
#  Returns:
#
#   If interface exists it returns its IP, otherwise it returns undef
#
#   string - IP if it exists
sub vifaceAddress # (interface)
{
    my ($self, $name) = @_;
    my $address;

    unless ($self->vifaceExists($name)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    }

    my ($iface, $viface) = $self->_viface2array($name);
    foreach (@{$self->vifacesConf($iface)}) {
        if ($_->{'name'} eq $viface) {
            return $_->{'address'};
        }
    }
    return undef;
}

# Method: vifaceNetmask
#
#   Returns the configured netmask for a virutal interface
#
# Parameters:
#
#   interface - the composed name of a virtual interface
#
#  Returns:
#
#   If interface exists it returns its netmask, otherwise it returns undef
#
#   string - IP if it exists
sub vifaceNetmask # (interface)
{
    my ($self, $name) = @_;
    my $address;

    unless ($self->vifaceExists($name)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    }

    my ($iface, $viface) = $self->_viface2array($name);
    foreach (@{$self->vifacesConf($iface)}) {
        if ($_->{'name'} eq $viface) {
            return $_->{'netmask'};
        }
    }
    return undef;
}

# Method: setIfaceAlias
#
#   Sets the alias for a given interface
#
# Parameters:
#
#   iface - the name of a network interface
#   alias - the alias for the interface
#
sub setIfaceAlias
{
    my ($self, $iface, $alias) = @_;

    my $ifaces = $self->get_hash('interfaces');

    if ($iface eq $alias) {
        # alias == iface name, no problems
        $ifaces->{$iface}->{alias} = $alias;
        $self->set('interfaces', $ifaces);
        return;
    }

    # check that the alias is not repeated or is the same that any interface
    # name
    foreach my $if (@{ $self->allIfaces() }) {
        if ($alias eq $if) {
            throw EBox::Exceptions::External(
                __x('There is already an interface called {al}',
                    al => $alias)
            );
        }

        if ($iface eq $if) {
            next;
        }

        my $ifAlias = $self->ifaceAlias($if);
        if ($ifAlias and ($ifAlias eq $alias)) {
            throw EBox::Exceptions::External(
                __x('There is already a interface with the alias {al}',
                    al => $alias)
            );
        }
    }

    if ($alias =~ m/:/) {
        throw EBox::Exceptions::External(
            __(q{Cannot set an alias with the character ":". This character is reserved for virtual interfaces})
                                        );
    }

    $ifaces->{$iface}->{alias} = $alias;
    $self->set('interfaces', $ifaces);
}

# Method: ifaceAlias
#
#   Returns the alias for a given interface
#
# Parameters:
#
#   iface - the name of a network interface
#
# Returns:
#
#   string - alias for the interface
#
sub ifaceAlias # (iface)
{
    my ($self, $iface) = @_;
    my $viface = undef;
    unless ($self->ifaceExists($iface)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    }
    if($self->vifaceExists($iface)) {
        my @aux = $self->_viface2array($iface);
        $iface = $aux[0];
        $viface = $aux[1];
    }
    my $alias = $self->get_hash('interfaces')->{$iface}->{alias};
    defined($alias) or $alias = $iface;
    defined($viface) and $alias = $alias . ":" . $viface;
    return $alias;
}

# Method: ifaceMethod
#
#   Returns the configured method for a given interface
#
# Parameters:
#
#   interface - the name of a network interface
#
# Returns:
#
#   string - dhcp|static|notset|trunk|ppp|bridged|bundled
#           dhcp -> the interface is configured via dhcp
#           static -> the interface is configured with a static ip
#           ppp -> the interface is configured via PPP
#           notset -> the interface exists but has not been
#                 configured yet
#           trunk -> vlan aware interface
#           bridged -> bridged to other interfaces
#           bundled -> bundled with other interfaces
#
sub ifaceMethod
{
    my ($self, $name) = @_;

    unless ($self->ifaceExists($name)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $name);
    }
    if ($self->vifaceExists($name)) {
        return 'static';
    }
    $self->ifaceOnConfig($name) or return 'notset';

    return $self->get_hash('interfaces')->{$name}->{method};
}

# Method: setIfaceDHCP
#
#   Configure an interface via DHCP
#
# Parameters:
#
#   interface - the name of a network interface
#   external - boolean to indicate if it's  a external interface
#   force - boolean to indicate if an exception should be raised when
#   method is changed or it should be forced
#
sub setIfaceDHCP
{
    my ($self, $name, $ext, $force) = @_;
    defined $ext or $ext = 0;

    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    my $oldm = $self->ifaceMethod($name);
    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
        $self->_checkStatic($name, $force);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    } elsif ($oldm eq 'bundled') {
        $self->BundledCleanUp($name);
    }

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ($ext != $self->ifaceIsExternal($name) ) {
      # Tell observers the interface way has changed
      foreach my $obs (@observers) {
        if ($obs->ifaceExternalChanged($name, $ext)) {
          if ($force) {
        $obs->changeIfaceExternalProperty($name, $ext);
          }
          else {
        throw EBox::Exceptions::DataInUse();
          }
        }
      }
    }
    if ($oldm ne 'dhcp') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'dhcp',
            action => 'prechange',
            force  => $force,
        );
    } else {
        my $oldm = $self->ifaceIsExternal($name);

        if ((defined($oldm) and defined($ext)) and ($oldm == $ext)) {
            return;
        }
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$name}->{external} = $ext;
    delete $ifaces->{$name}->{address};
    delete $ifaces->{$name}->{netmask};
    $ifaces->{$name}->{method} = 'dhcp';
    $ifaces->{$name}->{name} = $name;
    $ifaces->{$name}->{changed} = 1;
    $self->set('interfaces', $ifaces);

    if ($oldm ne 'dhcp') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'dhcp',
            action => 'postchange'
        );
    }
}

# Method: setIfaceStatic
#
#   Configure with a static ip address
#
# Parameters:
#
#   interface - the name of a network interface
#   address - IPv4 address
#   netmask - network mask
#   external - boolean to indicate if it's an external interface
#   force - boolean to indicate if an exception should be raised when
#   method is changed or it should be forced
#
sub setIfaceStatic
{
    my ($self, $name, $address, $netmask, $ext, $force) = @_;
    defined $ext or $ext = 0;

    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    checkIPNetmask($address, $netmask, __('IP address'), __('Netmask'));

    $self->_checkStaticIP($name, $address, $netmask);

    my $oldm = $self->ifaceMethod($name);
    my $oldaddr = $self->ifaceAddress($name);
    my $oldmask = $self->ifaceNetmask($name);
    my $oldext = $self->ifaceIsExternal($name);

    if (($oldm eq 'static') and
        ($oldaddr eq $address) and
        ($oldmask eq $netmask) and
        (! ($oldext xor $ext))) {
        return;
    }

    if ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    }

    if ((!defined($oldaddr) or ($oldaddr ne $address))) {
        my $ifaceSameAddress = $self->ifaceByAddress($address);
        if ($ifaceSameAddress) {
            throw EBox::Exceptions::DataExists(
                text => __x(
                    'The IP {ip} is already assigned to interface {iface}',
                    ip => $address,
                    iface => $ifaceSameAddress,
                   ));
        }
    }

    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name, $address, $netmask);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    } elsif ($oldm eq 'bundled') {
        $self->BundledCleanUp($name);
    }

    # Calling observers
    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if (defined $ext and $ext != $self->ifaceIsExternal($name) ) {
        # Tell observers the interface way has changed
        foreach my $obs (@observers) {
            if ($obs->ifaceExternalChanged($name, $ext)) {
                if ($force) {
                    $obs->changeIfaceExternalProperty($name, $ext);
                } else {
                    throw EBox::Exceptions::DataInUse();
                }
            }
        }
    }

    if ($oldm ne 'static') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'static',
            action => 'prechange',
            force => $force
        );
    } else {
        foreach my $obs (@observers) {
            if ($obs->staticIfaceAddressChanged($name,
                            $oldaddr,
                            $oldmask,
                            $address,
                            $netmask)) {
                if ($force) {
                    $obs->freeIface($name);
                } else {
                    throw EBox::Exceptions::DataInUse();
                }
            }
        }
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$name}->{external} = $ext;
    $ifaces->{$name}->{method} = 'static';
    $ifaces->{$name}->{address} = $address;
    $ifaces->{$name}->{netmask} = $netmask;
    $ifaces->{$name}->{name}    = $name;
    $ifaces->{$name}->{changed} = 1;
    $self->set('interfaces', $ifaces);

    if ($oldm ne 'static') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'static',
            action => 'postchange'
        );
    } else {
        foreach my $obs (@observers) {
            $obs->staticIfaceAddressChangedDone($name,
                                                $oldaddr,
                                                $oldmask,
                                                $address,
                                                $netmask);
        }
    }
}

sub _checkStatic # (iface, force)
{
    my ($self, $iface, $force) = @_;

    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    foreach my $vif (@{$self->vifaceNames($iface)}) {
        foreach my $mod (@mods) {
            my ($tmp, $viface) = $self->_viface2array($vif);
            if ($mod->vifaceDelete($iface, $viface)) {
                if ($force) {
                    $mod->freeViface($iface, $viface);
                } else {
                    throw EBox::Exceptions::DataInUse();
                }
            }
        }
    }
}

# check that no IP are in the same network
# limitation: we could only check against the current
# value of dynamic addresses
sub _checkStaticIP
{
    my ($self, $iface, $address, $netmask) = @_;
    my $network = EBox::NetWrappers::ip_network($address, $netmask);
    foreach my $if (@{$self->allIfaces()} ) {
        if ($if eq $iface) {
            next;
        }

        # don't check against other ifaces in this bridge
        if ($self->ifaceIsBridge($iface)) {
            my $brIfaces = $self->bridgeIfaces($iface);
            if ($if eq any(@{$brIfaces})) {
                next;
            }
        }
        if ($self->ifaceIsBond($iface)) {
            my $bondIfaces = $self->bondIfaces($iface);
            if ($if eq any(@{$bondIfaces})) {
                next;
            }
        }

        foreach my $addr_r (@{ $self->ifaceAddresses($if)} ) {
            my $ifNetwork =  EBox::NetWrappers::ip_network($addr_r->{address},
                                                            $addr_r->{netmask});
            if ($ifNetwork eq $network) {
                throw EBox::Exceptions::External(
                 __x('Cannot use the address {addr} because interface {if} has already an address in the same network',
                     addr => $address,
                     if => $if
                    )
                );
            }
        }
    }
}

# Method: setIfacePPP
#
#   Configure with PPP method
#
# Parameters:
#
#   interface - the name of a network interface
#   ppp_user - PPP user name
#   ppp_pass - PPP password
#   external - boolean to indicate if it's an external interface
#   force - boolean to indicate if an exception should be raised when
#           method is changed or it should be forced
#
sub setIfacePPP
{
    my ($self, $name, $ppp_user, $ppp_pass, $ext, $force) = @_;
    defined $ext or $ext = 0;

    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    my $oldm = $self->ifaceMethod($name);
    my $olduser = $self->ifacePPPUser($name);
    my $oldpass = $self->ifacePPPPass($name);
    my $oldext = $self->ifaceIsExternal($name);

    if (($oldm eq 'ppp') and
        ($olduser eq $ppp_user) and
        ($oldpass eq $ppp_pass) and
        (! ($oldext xor $ext))) {
        return;
    }

    if ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    } elsif ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    } elsif ($oldm eq 'bundled') {
        $self->BundledCleanUp($name);
    }

    # Calling observers
    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ($ext != $self->ifaceIsExternal($name) ) {
        # Tell observers the interface way has changed
        foreach my $obs (@observers) {
            if ($obs->ifaceExternalChanged($name, $ext)) {
                if ($force) {
                    $obs->changeIfaceExternalProperty($name, $ext);
                } else {
                    throw EBox::Exceptions::DataInUse();
                }
            }
        }
    }

    if ($oldm ne 'ppp') {
            $self->_notifyChangedIface(
                name => $name,
                oldMethod => $oldm,
                newMethod => 'ppp',
                action => 'prechange',
                force => $force,
            );
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$name}->{external} = $ext;
    $ifaces->{$name}->{method} = 'ppp';
    $ifaces->{$name}->{ppp_user} = $ppp_user;
    $ifaces->{$name}->{ppp_pass} = $ppp_pass;
    $ifaces->{$name}->{name}     = $name;
    $ifaces->{$name}->{changed} = 1;
    $self->set('interfaces', $ifaces);

    if ($oldm ne 'ppp') {
            $self->_notifyChangedIface(
                name => $name,
                oldMethod => $oldm,
                newMethod => 'ppp',
                action => 'postchange'
            );
    }
}

# Method: setIfaceTrunk
#
#   configures an interface in trunk mode, making it possible to create vlan
#   interfaces on it.
#
# Parameters:
#
#   interface - the name of a network interface
#   force - boolean to indicate if an exception should be raised when
#   method is changed or it should be forced
#
sub setIfaceTrunk # (iface, force)
{
    my ($self, $name, $force) = @_;

    unless ($self->ifaceExists($name)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    }

    if ($name =~ /^vlan/) {
        throw EBox::Exceptions::External(__('This interface cannot '.
            'be put in trunk mode, it is an vlan interface.'));
    }

    my $oldm = $self->ifaceMethod($name);

    ($oldm eq 'trunk') and return;

    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
        $self->_checkStatic($name, $force);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    } elsif ($oldm eq 'bundled') {
        $self->BundledCleanUp($name);
    }

    if ($oldm ne 'notset') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'notset',
            action => 'prechange',
            force => $force,
        );
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$name}->{address};
    delete $ifaces->{$name}->{netmask};
    $ifaces->{$name}->{method}  = 'trunk';
    $ifaces->{$name}->{changed} = 1;
    $ifaces->{$name}->{name}    = $name;
    $self->set('interfaces', $ifaces);

    if ($oldm ne 'notset') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'notset',
            action => 'postchange'
        );
    }
}

# returns true if the given interface is in trunk mode an has at least one vlan
# interface added to it which is configured as dhcp or static.
sub _trunkIfaceIsUsed # (iface)
{
    my ($self, $iface) = @_;
    my $vlans = $self->ifaceVlans($iface);
    foreach my $vlan (@{$vlans}) {
        defined($vlan) or next;
        ($iface eq $vlan->{interface}) or next;
        my $meth = $self->ifaceMethod("vlan$vlan->{id}");
        if ($meth ne 'notset') {
            throw EBox::Exceptions::External(
                __('This interface is in trunk mode, you '.
                   'should unconfigure all the vlan '.
                   'interfaces in this trunk before changing '.
                   'its configuration mode.'));
        }
    }
    return undef;
}

# remove all vlanes from a trunk interface
sub _removeTrunkIfaceVlanes
{
    my ($self, $iface) = @_;
    my $vlans = $self->ifaceVlans($iface);
    foreach my $vlan (@{$vlans}) {
        defined($vlan) or next;
        $self->removeVlan($vlan->{id});
    }
}

# Method: setIfaceBridged
#
#   configures an interface in bridged mode attached to a new or
#   defined bridge
#
# Parameters:
#
#   interface - the name of a network interface
#   external - boolean to indicate if it's  a external interface
#   bridge - bridge id number or -1 to create new one
#   force - boolean to indicate if an exception should be raised when
#   method is changed or it should be forced
#
sub setIfaceBridged
{
    my ($self, $name, $ext, $bridge, $force) = @_;
    defined $ext or $ext = 0;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    # check if bridge exists
    if ( $bridge >= 0 ) {
        $self->ifaceExists("br$bridge") or
            throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                                 value => "br$bridge");
    }

    my $oldm = $self->ifaceMethod($name);
    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
        $self->_checkStatic($name, $force);
    } elsif ($oldm eq 'bridged' and $self->ifaceBridge($name) ne $bridge) {
        $self->BridgedCleanUp($name);
    }

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ($ext != $self->ifaceIsExternal($name) ) {
      # Tell observers the interface way has changed
      foreach my $obs (@observers) {
        if ($obs->ifaceExternalChanged($name, $ext)) {
          if ($force) {
            $obs->changeIfaceExternalProperty($name, $ext);
          }
          else {
            throw EBox::Exceptions::DataInUse();
          }
        }
      }
    }
    if ($oldm ne 'bridged') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'bridged',
            action => 'prechange',
            force  => $force,
        );
    } else {
        my $oldm = $self->ifaceIsExternal($name);
        my $oldbr = $self->ifaceBridge($name);

        if (defined($oldm) and defined($ext) and ($oldm == $ext) and
            defined($oldbr) and defined($bridge) and ($oldbr eq $bridge)) {
            return;
        }
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }
    # new bridge
    if ($bridge < 0) {
        my @bridges = @{$self->bridges()};
        my $last = int(pop(@bridges));
        $bridge = $last+1;
        $self->_createBridge($bridge);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$name}->{external} = $ext;
    delete $ifaces->{$name}->{address};
    delete $ifaces->{$name}->{netmask};
    $ifaces->{$name}->{method} = 'bridged';
    $ifaces->{$name}->{changed} = 1;
    $ifaces->{$name}->{bridge_id} = $bridge;
    $ifaces->{$name}->{name} = $name;
    $self->set('interfaces', $ifaces);

    # mark bridge as changed
    $self->_setChanged("br$bridge");

    if ($oldm ne 'bridged') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'bridged',
            action => 'postchange'
        );
    }
}

# Method: setIfaceBonded
#
#   configures an interface in bundled mode attached to a new or
#   defined bond
#
# Parameters:
#
#   interface - the name of a network interface
#   external - boolean to indicate if it's  a external interface
#   bond - bond id number or -1 to create new one
#   force - boolean to indicate if an exception should be raised when
#   method is changed or it should be forced
#
sub setIfaceBonded
{
    my ($self, $name, $ext, $bond, $force) = @_;
    defined $ext or $ext = 0;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    # check if bond exists
    if ( $bond >= 0 ) {
        $self->ifaceExists("bond$bond") or
            throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                                 value => "bond$bond");
    }

    my $oldm = $self->ifaceMethod($name);
    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
        $self->_checkStatic($name, $force);
    } elsif ($oldm eq 'bundled' and $self->ifaceBond($name) ne $bond) {
        $self->BundledCleanUp($name);
    }

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ($ext != $self->ifaceIsExternal($name) ) {
      # Tell observers the interface way has changed
      foreach my $obs (@observers) {
        if ($obs->ifaceExternalChanged($name, $ext)) {
          if ($force) {
            $obs->changeIfaceExternalProperty($name, $ext);
          }
          else {
            throw EBox::Exceptions::DataInUse();
          }
        }
      }
    }
    if ($oldm ne 'bundled') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'bundled',
            action => 'prechange',
            force  => $force,
        );
    } else {
        my $oldm = $self->ifaceIsExternal($name);
        my $oldbr = $self->ifaceBond($name);

        if (defined($oldm) and defined($ext) and ($oldm == $ext) and
            defined($oldbr) and defined($bond) and ($oldbr eq $bond)) {
            return;
        }
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }
    # new bond
    if ($bond < 0) {
        my @bonds = @{$self->bonds()};
        my $last = int(pop(@bonds));
        $bond = $last;
        $self->_createBond($bond);
    }

    my $ifaces = $self->get_hash('interfaces');
    $ifaces->{$name}->{external} = $ext;
    delete $ifaces->{$name}->{address};
    delete $ifaces->{$name}->{netmask};
    $ifaces->{$name}->{method} = 'bundled';
    $ifaces->{$name}->{changed} = 1;
    $ifaces->{$name}->{bond_id} = $bond;
    $ifaces->{$name}->{name} = $name;
    $self->set('interfaces', $ifaces);

    # mark bond as changed
    $self->_setChanged("bond$bond");

    if ($oldm ne 'bundled') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'bundled',
            action => 'postchange'
        );
    }
}

# Method: createVlan
#
#   creates an vlan on a trunk interface.
#
# Parameters:
#
#   id - vlan identifier
#   name - name
#   interface - the name of a network interface
#
sub createVlan # (id, name, iface)
{
    my ($self, $id, $name, $iface) = @_;

    checkVlanID($id, __('VLAN Id'));
    defined($name) or $name = '';

    my $vlans = $self->get_hash('vlans');
    if (exists $vlans->{$id}) {
        throw EBox::Exceptions::DataExists('data' => 'vlan',
                          'value' => "$id");
    }

    if ($self->ifaceMethod($iface) ne 'trunk') {
        throw EBox::Exceptions::External(__('Network interfaces need '.
            'to be in trunk mode before adding vlans to them.'));
    }

    $vlans->{$id}->{id} = $id;
    $vlans->{$id}->{name} = $name;
    $vlans->{$id}->{interface} = $iface;
    $self->set('vlans', $vlans);
}

# Method: removeVlan
#
#   Removes a vlan
#
# Parameters:
#
#   id - vlan identifier
#
sub removeVlan # (id)
{
    my ($self, $id, $force) = @_;
    checkVlanID($id, __('VLAN Id'));

    my $vlans = $self->get_hash('vlans');
    delete $vlans->{$id};
    $self->set_hash('vlans', $vlans);
}

# Method: vlans
#
#   Returns a reference to an array with all existing vlan ID's
#
# Returns:
#
#   an array ref - holding the vlan ID's
sub vlans
{
    my ($self) = @_;

    my @ids = keys %{$self->get_hash('vlans')};
    return \@ids;
}

#
# Method: vlanExists
#
#   Checks if a given vlan id exists
#
# Parameters:
#
#   id - vlan identifier
#
#  Returns:
#
#   boolean - true if it exits, otherwise false
sub vlanExists # (vlanID)
{
    my ($self, $vlan) = @_;

    return exists $self->get_hash('vlans')->{$vlan};
}

# Method: ifaceVlans
#
#   Returns information about every vlan that exists on the given trunk
#   interface.
#
# Parameters:
#
#   iface - interface name
#
#  Returns:
#
#   array ref - The elements of the array are hashesh. The hashes contain
#   these keys: 'id' (vlan ID), 'name' (user given description for the vlan)
#   and 'interface' (the name of the trunk interface)
#
sub ifaceVlans
{
    my ($self, $name) = @_;

    my @array = ();
    my $vlans = $self->get_hash('vlans');
    foreach my $id (keys %{$vlans}) {
        my $vlan = $vlans->{$id};
        if ($vlan->{interface} eq $name) {
            $vlan->{id} = $id;
            push(@array, $vlan);
        }
    }
    return \@array;
}

sub vlan
{
    my ($self, $vlan) = @_;

    defined($vlan) or return undef;
    if ($vlan =~ /^vlan/) {
        $vlan =~ s/^vlan//;
    }
    if ($vlan =~ /:/) {
        $vlan =~ s/:.*$//;
    }
    my $vlans = $self->get_hash('vlans');
    unless (exists $vlans->{$vlan}) {
        return undef;
    }
    $vlans->{$vlan}->{id} = $vlan;
    return $vlans->{$vlan};
}

# Method: _createBridge
#
#   creates a new bridge interface.
#
# Parameters:
#
#   id - bridge identifier
#
sub _createBridge
{
    my ($self, $id) = @_;

    my $bridge = "br$id";
    my $interfaces = $self->get_hash('interfaces');
    if (exists $interfaces->{$bridge}) {
        throw EBox::Exceptions::DataExists('data' => 'bridge',
                                           'value' => $id);
    }

    $self->setIfaceAlias($bridge, $bridge);
}

# Method: _removeBridge
#
#   Removes a bridge
#
# Parameters:
#
#   id - bridge identifier
#
sub _removeBridge # (id)
{
    my ($self, $id, $force) = @_;
    $self->_removeIface("br$id");
}

# Method: _removeEmptyBridges
#
# Removes bridges which has no bridged interfaces
sub _removeEmptyBridges
{
    my ($self) = @_;
    my %seen;

    for my $if ( @{$self->ifaces()} ) {
        if ( $self->ifaceMethod($if) eq 'bridged' ) {
            $seen{$self->ifaceBridge($if)}++;
        }
    }

    # remove unseen bridges
    for my $bridge ( @{$self->bridges()} ) {
        next if ( $seen{$bridge} );
        $self->_removeBridge($bridge);
    }
}

# Method: bridges
#
#   Returns a reference to a sorted array with existing bridges ID's
#
# Returns:
#
#   an array ref - holding the bridges ID's
sub bridges
{
    my $self = shift;
    my @bridges;

    for my $iface (keys %{$self->get_hash('interfaces')}) {
        if ($iface =~ /^br/) {
            $iface =~ s/^br//;
            push(@bridges, $iface);
        }
    }
    @bridges = sort @bridges;
    return \@bridges;
}

# Method: bridgeIfaces
#
#   Returns a reference to an array of ifaces bridged to
#   the given bridge ifname
#
# Parameters:
#
#   bridge - Bridge ifname
#
# Returns:
#
#   an array ref - holding the iface names
sub bridgeIfaces
{
    my ($self, $bridge) = @_;

    # get the bridge's id
    $bridge =~ s/^br//;

    my @ifaces = ();
    for my $iface (@{$self->ifaces}) {
        if ($self->ifaceMethod($iface) eq 'bridged') {
            if ($self->ifaceBridge($iface) eq $bridge) {
               push(@ifaces, $iface);
            }
        }
    }

    return \@ifaces;
}

# Method: _createBond
#
#   creates a new bond interface.
#
# Parameters:
#
#   id - bond identifier
#
sub _createBond
{
    my ($self, $id) = @_;

    my $bond = "bond$id";
    my $interfaces = $self->get_hash('interfaces');
    if (exists $interfaces->{$bond}) {
        throw EBox::Exceptions::DataExists('data' => 'bond',
                                           'value' => $id);
    }

    $self->setIfaceAlias($bond, $bond);
}

# Method: _removeBond
#
#   Removes a bond
#
# Parameters:
#
#   id - bond identifier
#
sub _removeBond # (id)
{
    my ($self, $id, $force) = @_;
    $self->_removeIface("bond$id");
}

# Method: _removeEmptyBonds
#
# Removes bonds which has no bundled interfaces
sub _removeEmptyBonds
{
    my ($self) = @_;
    my %seen;

    for my $if ( @{$self->ifaces()} ) {
        if ( $self->ifaceMethod($if) eq 'bundled' ) {
            $seen{$self->ifaceBond($if)}++;
        }
    }

    # remove unseen bonds
    for my $bond ( @{$self->bonds()} ) {
        next if ( $seen{$bond} );
        $self->_removeBond($bond);
    }
}

# Method: bonds
#
#   Returns a reference to a sorted array with existing bonds ID's
#
# Returns:
#
#   an array ref - holding the bonds ID's
sub bonds
{
    my $self = shift;
    my @bonds;

    for my $iface (keys %{$self->get_hash('interfaces')}) {
        if ($iface =~ /^bond/) {
            $iface =~ s/^bond//;
            push(@bonds, $iface);
        }
    }
    @bonds = sort @bonds;
    return \@bonds;
}

# Method: bondIfaces
#
#   Returns a reference to an array of ifaces bundled to
#   the given bond ifname
#
# Parameters:
#
#   bond - Bond ifname
#
# Returns:
#
#   an array ref - holding the iface names
sub bondIfaces
{
    my ($self, $bond) = @_;

    # get the bond's id
    $bond =~ s/^bond//;

    my @ifaces = ();
    for my $iface (@{$self->ifaces}) {
        if ($self->ifaceMethod($iface) eq 'bundled') {
            if ($self->ifaceBond($iface) eq $bond) {
               push(@ifaces, $iface);
            }
        }
    }

    return \@ifaces;
}

# Method: unsetIface
#
#   Unset an interface
#
# Parameters:
#
#   interface - the name of a network interface
#   force - boolean to indicate if an exception should be raised when
#   interface is changed or it should be forced
sub unsetIface # (interface, force)
{
    my ($self, $name, $force) = @_;
    unless ($self->ifaceExists($name)) {
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    }
    unless ($self->ifaceOnConfig($name)) {
        return;
    }

    my $oldm = $self->ifaceMethod($name);
    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'trunk') {
        $self->_trunkIfaceIsUsed($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name);
        $self->_checkStatic($name, $force);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    } elsif ($oldm eq 'bundled') {
        $self->BundledCleanUp($name);
    }

    if ($oldm ne 'notset') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'notset',
            action => 'prechange',
            force  => $force,
        );
    }

    if ($oldm eq 'trunk') {
        $self->_removeTrunkIfaceVlanes($name);
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$name}->{address};
    delete $ifaces->{$name}->{netmask};
    $ifaces->{$name}->{method} = 'notset';
    $ifaces->{$name}->{name} = $name;
    $ifaces->{$name}->{changed} = 1;
    $self->set('interfaces', $ifaces);

    if ($oldm ne 'notset') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'notset',
            action => 'postchange',
            force  => $force,
        );
    }

}

# Method: ifaceAddress
#
#   Returns the configured address for a real interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For static interfaces: the configured IP Address of the interface.
#   - For dhcp and ppp interfaces:
#       - the current address if the interface is up
#       - undef if the interface is down
#   - For bridged interfaces: its bridge ifaces address (static or dhcp)
#   - For bundled interfaces: its bond ifaces address (static or dhcp)
#   - For not-yet-configured interfaces
#       - undef
sub ifaceAddress # (name)
{
    my ($self, $name) = @_;

    my $address;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    if ($self->vifaceExists($name)) {
        return $self->vifaceAddress($name);
    }
    if ($self->ifaceMethod($name) eq 'static') {
        return $self->get_hash('interfaces')->{$name}->{address};
    } elsif ($self->ifaceMethod($name) eq any('dhcp', 'ppp')) {
        return $self->DHCPAddress($name);
    } elsif ($self->ifaceMethod($name) eq 'bridged') {
        my $bridge = $self->ifaceBridge($name);
        if ($self->ifaceExists("br$bridge")) {
            return $self->ifaceAddress("br$bridge");
        }
    #} elsif ($self->ifaceMethod($name) eq 'bundled') {
    #    my $bond = $self->ifaceBond($name);
    #    if ($self->ifaceExists("bond$bond")) {
    #        return $self->ifaceAddress("bond$bond");
    #    }
    }
    return undef;
}

# Method: ifacePPPUser
#
#   Returns the configured username for a PPP interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For ppp interfaces: the configured user of the interface.
#   - For the rest: undef
#
sub ifacePPPUser # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceMethod($name) eq 'ppp') {
        return $self->get_hash('interfaces')->{$name}->{ppp_user};
    } else {
        return undef;
    }
}

# Method: ifacePPPPass
#
#   Returns the configured password for a PPP interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For ppp interfaces: the configured password of the interface.
#   - For the rest: undef
#
sub ifacePPPPass # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceMethod($name) eq 'ppp') {
        return $self->get_hash('interfaces')->{$name}->{ppp_pass};
    } else {
        return undef;
    }
}

# Method: ifaceBridge
#
#   Returns the bridge id for an interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For bridged interfaces: the bridge id
#   - For the rest: undef
#
sub ifaceBridge # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceMethod($name) eq 'bridged') {
        return $self->get_hash('interfaces')->{$name}->{bridge_id};
    } else {
        return undef;
    }
}

# Method: ifaceBond
#
#   Returns the bond id for an interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For bundled interfaces: the bond id
#   - For the rest: undef
#
sub ifaceBond # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceMethod($name) eq 'bundled') {
        return $self->get_hash('interfaces')->{$name}->{bond_id};
    } else {
        return undef;
    }
}

# Method: bondMode
#
#   Returns the bonding mode for a bond interface
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For bond: the bonding mode
#   - For the rest: undef
#
sub bondMode # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceIsBond($name)) {
        return $self->get_hash('interfaces')->{$name}->{bond_mode};
    }
    return undef;
}

# Method: realIface
#
#   Returns the associated PPP interface in case of a Ethernet
#   interface configured for PPPoE, or the same value in any other case.
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For ppp interfaces: the associated interface, if it is up
#   - For the rest: the unaltered name
#
sub realIface # (name)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->ifaceMethod($name) eq 'ppp') {
        my $ppp_iface = $self->get_state()->{interfaces}->{$name}->{ppp_iface};
        if ($ppp_iface) {
            return $ppp_iface;
        }
    }
    return $name;
}

# Method: etherIface
#
#   Returns the associated Ethernet interface in case of a ppp
#   interface configured for PPPoE, or the same value in any other case.
#
#   This is somehow the inverse function of <EBox::Network::realIface>
#   - For ppp interfaces: the associated Ethernet interface, if it is up
#   - For the rest: the unaltered name
#
sub etherIface # (name)
{
    my ($self, $name) = @_;

    for my $iface (@{$self->allIfaces()}) {
        if ($self->ifaceMethod($iface) eq 'ppp') {
            my $ppp_iface = $self->get_state()->{interfaces}->{$iface}->{ppp_iface};
            return $iface if ($ppp_iface eq $name);
        }
    }
    return $name;
}

# Method: ifaceNetmask
#
#   Returns the configured network mask for a real interface
#
# Parameters:
#
#   interface - interface name
#
#  Returns:
#
#   - For static interfaces: the configured network mask  of the interface.
#   - For dhcp interfaces:
#       - the current network mask the interface is up
#       - undef if the interface is down
#   - For not-yet-configured interfaces
#       - undef
#
sub ifaceNetmask
{
    my ($self, $name) = @_;
    my $address;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);

    if ($self->vifaceExists($name)) {
        return $self->vifaceNetmask($name);
    }
    if ($self->ifaceMethod($name) eq 'static') {
        return $self->get_hash('interfaces')->{$name}->{netmask};
    } elsif ($self->ifaceMethod($name) eq any('dhcp', 'ppp')) {
        return $self->DHCPNetmask($name);
    } elsif ($self->ifaceMethod($name) eq 'bridged') {
        my $bridge = $self->ifaceBridge($name);
        if ($self->ifaceExists("br$bridge")) {
            return $self->ifaceNetmask("br$bridge");
        }
    #} elsif ($self->ifaceMethod($name) eq 'bundled') {
    #    my $bond = $self->ifaceBond($name);
    #    if ($self->ifaceExists("bond$bond")) {
    #        return $self->ifaceNetmask("bond$bond");
    #    }
    }

    return undef;
}

# Method: ifaceNetwork
#
#   Returns the configured network address  for a real interface
#
# Parameters:
#
#   interface - interface name
#
#  Returns:
#
#   - For static interfaces: the configured network address of the interface.
#   - For dhcp interfaces:
#       - the current network address the interface is up
#       - undef if the interface is down
#   - For not-yet-configured interfaces
#       - undef
sub ifaceNetwork # (interface)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    my $address;
    my $netmask;

    $address = $self->ifaceAddress($name);
    $netmask = $self->ifaceNetmask($name);
    if ($address) {
        return ip_network($address, $netmask);
    }
    return undef;
}

# Method: ifaceBroadcast
#
#   Returns the configured broadcast address  for a real interface
#
# Parameters:
#
#   interface - interface name
#
#  Returns:
#
#   - For static interfaces: the configured broadcast address of the
#   interface.
#   - For dhcp interfaces:
#       - the current broadcast address if the interface is up
#       - undef if the interface is down
#   - For not-yet-configured interfaces
sub ifaceBroadcast # (interface)
{
    my ($self, $name) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);
    my $address;
    my $netmask;

    $address = $self->ifaceAddress($name);
    $netmask = $self->ifaceNetmask($name);
    if ($address) {
        return ip_broadcast($address, $netmask);
    }
    return undef;
}

# Method: nameservers
#
#   Return a list of the configured name servers
#
#  Returns:
#
#   Array ref - each element contains a string holding the nameserver
#
sub nameservers
{
    my ($self) = @_;
    my $samba = $self->global()->modInstance('samba');
    if ($samba) {
        return ['127.0.0.1']
    }

    return $self->model('DNSResolver')->nameservers();
}

sub searchdomain
{
    my ($self) = @_;

    return $self->model('SearchDomain')->domainValue();
}

# Method: nameserverOne
#
#   Return the primary nameserver's IP address
#
#  Returns:
#
#   String - nameserver's IP address
#
#       empty string - if there is not primary nameserver
#
sub nameserverOne
{
    my ($self) = @_;

    my $nss = $self->nameservers();
    return $nss->[0] if (scalar(@{$nss}) >= 1);
    return '';
}

# Method: nameserverTwo
#
#   Return the secondary nameserver's IP address
#
#  Returns:
#
#   string - nameserver's IP address
#
#       empty string - if there is not secondary nameserver
#
sub nameserverTwo
{
    my ($self) = @_;

    my $nss = $self->nameservers();
    return $nss->[1] if (scalar(@{$nss}) >= 2);
    return '';
}

# Method: gateway
#
#       Returns the default gateway's ip address
#
# Returns:
#
#       If the gateway has not been set it will return undef
#
#   string - the default gateway's ip address (undef if not set)
sub gateway
{
    my $self = shift;

    return  $self->model('GatewayTable')->defaultGateway();
}

# Method: routes
#
#       Return the configured static routes
#
# Returns:
#
#   array ref - each element contains a hash ref with keys:
#
#          network - an IP block in CIDR format
#          gateway - an IP address
#
sub routes
{
    my ($self) = @_;

    my $staticRouteModel = $self->model('StaticRoute');
    my @routes;
    for my $id (@{$staticRouteModel->ids()}) {
        my $row = $staticRouteModel->row($id);
        push (@routes, { network => $row->printableValueByName('network'),
                         gateway => $row->printableValueByName('gateway')});
    }
    return \@routes;
}

# Method: gatewayDeleted
#
#    Mark an interface as changed for a route delete. The selected
#    interface to be restarted must be the one which the gateway is
#    in.
#
# Parameters:
#
#    gateway - String the gateway IP address
#
# Exceptions:
#
#    <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#    argument is missing
#
sub gatewayDeleted
{
    my ($self, $gw) = @_;

    $gw or throw EBox::Exceptions::MissingArgument('gateway');

    foreach my $iface (@{$self->allIfaces()}) {
        my $host = $self->ifaceAddress($iface);
        my $mask = $self->ifaceNetmask($iface);
        my $meth = $self->ifaceMethod($iface);
        (defined($meth) eq 'static') or next;
        (defined($host) and defined($mask)) or next;
        if (isIPInNetwork($host,$mask,$gw)) {
            $self->_setChanged($iface);
        }
    }

}

#returns true if the interface has been marked as changed
sub _hasChanged
{
    my ($self, $iface) = @_;

    my $real = $iface;
    if ($self->vifaceExists($iface)) {
        ($real) = $self->_viface2array($iface);
    }
    my $ifaces = $self->get_hash('interfaces');
    if (exists $ifaces->{$real}) {
        return $ifaces->{$real}->{changed};
    } else {
        return 1; # deleted => has changed
    }
}

#returns true if the interface is empty (ready to be removed)
sub _isEmpty
{
    my ($self, $ifc) = @_;

    if ($self->vifaceExists($ifc)) {
        my ($real, $vir) = $self->_viface2array($ifc);
        return (not defined($self->get_hash('interfaces')->{$real}->{virtual}->{$vir}->{address}));
    } else {
        return (not defined($self->get_hash('interfaces')->{$ifc}->{method}));
    }
}

sub _removeIface
{
    my ($self, $iface) = @_;

    my $ifaces = $self->get_hash('interfaces');
    if ($self->vifaceExists($iface)) {
        my ($real, $virtual) = $self->_viface2array($iface);
        delete $ifaces->{$real}->{virtual}->{$virtual};
    } else {
        delete $ifaces->{$iface};
    }
    $self->set('interfaces', $ifaces);
}

sub _unsetChanged # (interface)
{
    my ($self, $iface) = @_;
    if ($self->vifaceExists($iface)) {
        return;
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$iface}->{changed};
    $self->set('interfaces', $ifaces);
}

sub _setChanged # (interface)
{
    my ($self, $iface) = @_;

    my $ifaces = $self->get_hash('interfaces');
    if ($self->vifaceExists($iface)) {
        my ($real, $vir) = $self->_viface2array($iface);
        $ifaces->{$real}->{changed} = 1;
    } else {
        $ifaces->{$iface}->{changed} = 1;
    }
    $self->set('interfaces', $ifaces);
}

# Method: _generateResolvconfConfig
#
#   This method write the /etc/resolvconf/interface-order file. This file
#   contain the order in which the files under /var/run/resolvconf/interfaces
#   are processes and finally result en the resolver order in /etc/resolv.conf
#
#   After write the order, resolvers manually configured in the webadmin
#   (those which interface field is zentyal.<row id>) are removed or added
#   to the resolvconf configuration.
#
sub _generateResolvconfConfig
{
    my ($self) = @_;

    # Generate base, head and tail
    $self->writeConfFile(RESOLVCONF_BASE,
        'network/resolvconf-base.mas', [],
        { mode => '0644', uid => 0, gid => 0 });
    $self->writeConfFile(RESOLVCONF_HEAD,
        'network/resolvconf-head.mas', [],
        { mode => '0644', uid => 0, gid => 0 });
    $self->writeConfFile(RESOLVCONF_TAIL,
        'network/resolvconf-tail.mas', [],
        { mode => '0644', uid => 0, gid => 0 });

    # First step, write the order list
    my $interfaces = [];
    my $model = $self->model('DNSResolver');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $interface = $row->valueByName('interface');
        next unless defined $interface and length $interface;
        push (@{$interfaces}, $interface);
    }

    # TODO SearchDomain should be a table model. Multiple search domains
    #      can be defined
    my $searchDomainModel = $self->model('SearchDomain');
    my $searchDomain = $searchDomainModel->value('domain');
    my $searchDomainIface = $searchDomainModel->value('interface');
    if ($searchDomainIface) {
        push (@{$interfaces}, $searchDomainIface);
    }

    my $ifaces = $self->ifaces();
    foreach my $iface (@{$ifaces}) {
        next unless $self->ifaceMethod($iface) eq 'dhcp';

        $iface = "$iface.dhclient";
        next if grep (/$iface/, @{$interfaces});

        push (@{$interfaces}, $iface);
    }

    my $array = [];
    push (@{$array}, interfaces => $interfaces);
    $self->writeConfFile(RESOLVCONF_INTERFACE_ORDER,
        'network/resolvconf-interface-order.mas', $array,
        { mode => '0644', uid => 0, gid => 0 });

    # Second step, trigger the updates
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $interface = $row->valueByName('interface');
        next unless defined $interface and length $interface;

        my $resolver = $row->valueByName('nameserver');
        next unless defined $resolver and length $resolver;

        next unless ($interface =~ m/^zentyal\..+$/);
        EBox::Sudo::root("resolvconf -d '$interface'");
        EBox::Sudo::root("echo 'nameserver $resolver' | resolvconf -a '$interface'");
    }

    if ($searchDomainIface and ($searchDomainIface =~ m/^zentyal\..+$/)) {
        EBox::Sudo::root("resolvconf -d '$searchDomainIface'");
        if ($searchDomain) {
            EBox::Sudo::root("echo 'search $searchDomain' | resolvconf -a '$searchDomainIface'");
        }
    }

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $domain = $sysinfo->hostDomain();
    EBox::Sudo::root("echo 'domain $domain' | resolvconf -a 'zentyal.domain'");
}

# Generate the configuration if a HTTP proxy has been set
sub _generateProxyConfig
{
    my ($self) = @_;

    my $proxy = $self->model('Proxy');
    my $proxyConf;

    if ($proxy->serverValue() and $proxy->portValue()) {
        $proxyConf = "http://".$proxy->serverValue().":".$proxy->portValue()."/";
        if ($proxy->usernameValue() and $proxy->passwordValue()) {
            $proxyConf = "http://".$proxy->usernameValue().":".$proxy->passwordValue();
            $proxyConf .= "@".$proxy->serverValue().":".$proxy->portValue()."/";
        }
    }

    # Write environment file by edition not overwritting
    my @contents = File::Slurp::read_file(ENV_FILE);
    my @finalContents = ();
    my $inMark = 0;
    foreach my $line (@contents) {
        if ($inMark) {
            $inMark = ($line !~ m/^#\s*END Zentyal Proxy Settings\s*$/);
            next;
        }
        $inMark = ($line =~ m/^#\s*Zentyal Proxy Settings\s*$/);
        push(@finalContents, $line) unless ($inMark);
    }
    if ($proxyConf) {
        push(@finalContents, "# Zentyal Proxy Settings\n",
                             qq{http_proxy="$proxyConf"\n},
                             qq{HTTP_PROXY="$proxyConf"\n},
                             "# END Zentyal Proxy Settings\n");
    }
    EBox::Module::Base::writeFile(ENV_FILE, join("", @finalContents));

    $self->writeConfFile(APT_PROXY_FILE,
                        'network/99proxy.conf.mas',
                        [ proxyConf => $proxyConf ]);
}

# Method: proxySettings
#
#    Return the proxy settings if configured
#
# Returns:
#
#    Hash ref - the following keys are included
#
#        server   - the HTTP proxy's name
#        port     - the HTTP proxy's port
#        username - the username to authenticate (optional)
#        password - the password (optional)
#
#    undef - if there is not proxy settings
#
sub proxySettings
{
    my ($self) = @_;

    my $proxy  = $self->model('Proxy');
    my $server = $proxy->serverValue();
    my $port   = $proxy->portValue();
    if ( $server and $port ) {
        my $retValue = { server => $server, port => $port };
        my $username = $proxy->usernameValue();
        my $password = $proxy->passwordValue();
        if ( $username and $password ) {
            $retValue->{username} = $username;
            $retValue->{password} = $password;
        }
        return $retValue;
    } else {
        return undef;
    }
}

sub _generatePPPConfig
{
    my ($self) = @_;

    my $pppSecrets = {};

    my $usepeerdns = scalar (@{$self->nameservers()}) == 0;

    # clear up PPP provide files
    my $clearCmd = 'rm -f ' . PPP_PROVIDER_FILE . '*';
    EBox::Sudo::root($clearCmd);

    foreach my $iface (@{$self->pppIfaces()}) {
        my $user = $self->ifacePPPUser($iface);
        my $pass = $self->ifacePPPPass($iface);
        $pppSecrets->{$user} = $pass;
        $self->writeConfFile(PPP_PROVIDER_FILE . $iface,
                             'network/dsl-provider.mas',
                             [ iface => $iface,
                               ppp_user => $user,
                               usepeerdns => $usepeerdns
                             ]);
    }

    $self->writeConfFile(PAP_SECRETS_FILE,
                         'network/pap-secrets.mas',
                         [ passwords  => $pppSecrets ],
                         { mode => '0600' }
                        );

    # Do not overwrite the entire chap-secrets file every time
    # to avoid conflicts with the PPTP module

    my $file;
    try {
        $file = read_file(CHAP_SECRETS_FILE);
    } catch {
        # Write it with permissions for ebox if we can't read it
        my $gid = getgrnam('ebox');
        $self->writeConfFile(CHAP_SECRETS_FILE,
                             'network/chap-secrets.mas', [],
                             { mode => '0660', gid => $gid });
        $file = read_file(CHAP_SECRETS_FILE);
    }
    my $pppoeConf = '';
    foreach my $user (keys %{$pppSecrets}) {
        $pppoeConf .= "$user * $pppSecrets->{$user}\n";
    }

    my $oldMark = '# PPPOE_CONFIG #';
    my $mark    =  '# PPPOE_CONFIG - managed by Zentyal. Don not edit this section #';
    my $endMark = '# End of PPPOE_CONFIG section #';
    $file =~ s/$mark.*$mark/$mark\n$pppoeConf$mark/sm;
    if ($file =~ m/$mark/sm) {
        $file =~ s/$mark.*$endMark/$mark\n$pppoeConf$endMark/sm;
    } elsif ($file =~ m/$oldMark/) {
        # convert to new format
        $file =~ s/$oldMark.*$oldMark/$mark\n$pppoeConf$endMark/sm;
    } else {
        $file .= $mark . "\n" . $pppoeConf . $endMark . "\n";
    }
    write_file(CHAP_SECRETS_FILE, $file);
}

sub generateInterfaces
{
    my ($self) = @_;
    my $iflist = $self->allIfacesWithRemoved();
    $self->writeConfFile(INTERFACES_FILE,
                         'network/interfaces.mas',
                         [
                             iflist => $iflist,
                             networkMod => $self,
                         ],
                         {'uid' => 0, 'gid' => 0, mode => '755' }
                        );
}

# Generate the static routes from routes() with "ip" command
sub _generateRoutes
{
    my ($self) = @_;
    my @routes = @{$self->routes()};

    # clean up unnecesary rotues
    $self->_removeRoutes(\@routes);
    @routes or return;

    my @cmds;
    foreach my $route (@routes) {
        my $net    = $route->{network};
        $net =~ s[/32$][]; # route_is_up needs no /24 mask
        my $gw     = $route->{gateway};
        # check if route already is up
        if (route_is_up($net, $gw)) {
            next;
        }

        my $cmd = "/sbin/ip route add $net via $gw table main";
        EBox::Sudo::root($cmd)
    }
}

# Remove not configured routes
sub _removeRoutes
{
    my ($self, $storedRoutes) = @_;
    my %toKeep = map {
        $_->{network} => $_
    } @{ $storedRoutes  };

    # Delete those routes which are not defined by Zentyal
    my @currentRoutes = list_routes(1, 0); # routes via gateway
    foreach my $currentRoute (@currentRoutes) {
        my $network = $currentRoute->{network};
        unless (($network =~ m{/}) or ($network eq 'default')) {
            # add /32 mask to ips without it so we can compare same format
            $network .= '/32';
        }

        my $gw   = $currentRoute->{router};

        if ((exists $toKeep{$network}) and
            ($toKeep{$network}->{gateway} eq $gw)) {
                next;
        }

        my $cmd =  "/sbin/ip route del $network via $gw";
        EBox::Sudo::root($cmd);
    }
}

# disable reverse path for gateway interfaces
sub _disableReversePath
{
    my ($self) = @_;

    my $routers = $self->gatewaysWithMac();

    my @cmds;
    push (@cmds, '/sbin/sysctl -q -w net.ipv4.conf.all.rp_filter=0');

    my %seen;
    for my $router ( reverse @{$routers} ) {
        my $iface = $router->{'interface'};
        $iface = $self->realIface($iface);
        # remove viface portion
        $iface =~ s/:.*$//;

        next if $seen{$iface};
        $seen{$iface} = 1;

        # Skipping vlan interfaces as it seems rp_filter key doesn't
        # exist for them
        next if ($iface =~ /^vlan/);

        push (@cmds, "/sbin/sysctl -q -w net.ipv4.conf.$iface.rp_filter=0");
    }

    EBox::Sudo::root(@cmds);
}

sub _multigwRoutes
{
    my ($self, $dynIfaces) = @_;

    # Flush the rules
    #
    # Add a rule to match every fwmark to pass through its
    # corresponding table.
    #
    # Each table only has a default
    # gateway, and there are as many tables as routers the user
    # has added.
    #
    # To route packets towards local networks, the highest
    # priority rule points to the main table. Note that
    # we do not have a default route in the main table, otherwise
    # we could not do the multipath stuff. Instead, we set the
    # default route within the default table.
    #
    #
    # We enclose iptables rules containing CONNMARK target
    # within a try/catch block because
    # kernels < 2.6.12 do not include such module.

    my $marks = $self->marksForRouters();
    my $routers = $self->gatewaysWithMac();
    my @cmds; # commands to run

    push(@cmds, EBox::Config::share() . 'zentyal-network/flush-fwmarks');
    my %interfaces;
    for my $router ( reverse @{$routers} ) {
        # Skip gateways with unassigned address
        my $ip = $router->{'ip'};
        next unless $ip;

        my $iface = $router->{'interface'};
        $interfaces{$iface}++;
    }

    my @markRules;
    my @addrRules;
    for my $router ( reverse @{$routers} ) {

        # Skip gateways with unassigned address
        my $ip = $router->{'ip'};
        next unless $ip;

        my $iface = $router->{'interface'};
        my $method = $self->ifaceMethod($iface);
        $interfaces{$iface}++;

        my $mark = $marks->{$router->{'id'}};
        my $table = 100 + $mark;

        $iface = $self->realIface($iface);

        my $net = $self->ifaceNetwork($iface);
        my $address = $self->ifaceAddress($iface);
        unless ($address) {
            EBox::warn("Interface $iface used by gateway " .
                            $router ->{name} . " has not address." .
                        " Not adding multi-gateway rules for this gateway.");
            next;
        }

        my $route = "via $ip dev $iface src $address";
        if ($method eq 'ppp') {
            $route = "dev $iface";
            (undef, $ip) = split ('/', $ip);
        }

        # Write mark rules first to avoid local output problems
        push(@cmds, "/sbin/ip route flush table $table");
        push(@markRules, "/sbin/ip rule add fwmark $mark/0xFF table $table");
        push(@addrRules, "/sbin/ip rule add from $ip table $table");

        # Add rule by source in multi interface configuration
        if (scalar keys %interfaces > 1) {
            push(@addrRules, "/sbin/ip rule add from $address table $table");
        }

        push(@cmds, "/sbin/ip route add default $route table $table");
    }

    push(@cmds, @addrRules, @markRules);
    push(@cmds,'/sbin/ip rule add table main');

    # Not in @cmds array because of possible CONNMARK exception
    my @fcmds;
    push(@fcmds, '/sbin/iptables -t mangle -F');
    push(@fcmds, '/sbin/iptables -t mangle -X');
    push(@fcmds, '/sbin/iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark');
    push(@fcmds, '/sbin/iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark');
    if ($dynIfaces) {
        sleep 1;
    }
    EBox::Sudo::silentRoot(@fcmds);

    my $defaultRouterMark;
    foreach my $router (@{$routers}) {

        # Skip gateways with unassigned address
        next unless $router->{'ip'};

        if ($router->{'default'} and $router->{'enabled'}) {
            $defaultRouterMark = $marks->{$router->{'id'}};
        }

        my $mark = $marks->{$router->{'id'}};

        # Match interface instead of mac for pppoe and dhcp
        my $mac = $router->{'mac'};
        my $iface = $self->realIface($router->{'interface'});
        my $origin;
        if ($mac) {
            # Skip unknown macs for static interfaces
            next if ($mac eq 'unknown');

            $origin = "-m mac --mac-source $mac";
        } else {
            $origin = "-i $iface";
        }
        push(@cmds, '/sbin/iptables -t mangle -A PREROUTING '
                  . "-m mark --mark 0/0xff $origin "
                  . "-j MARK --set-mark $mark");
    }

    push(@cmds, @{$self->_pppoeRules()});

    for my $rule (@{$self->model('MultiGwRulesDataTable')->iptablesRules()}) {
        push(@cmds, "/sbin/iptables $rule");
    }

    # send unmarked packets through default router
    if ((not $self->balanceTraffic()) and $defaultRouterMark) {
        push(@cmds, "/sbin/iptables -t mangle -A PREROUTING  -m mark --mark 0/0xff " .
                    "-j  MARK --set-mark $defaultRouterMark");
        push(@cmds, "/sbin/iptables -t mangle -A OUTPUT -m mark --mark 0/0xff " .
                    "-j  MARK --set-mark $defaultRouterMark");
    }

    # always before CONNMARK save commands
    EBox::Sudo::root(@cmds);

    try {
        my @fcmds;
        push(@fcmds, '/sbin/iptables -t mangle -A PREROUTING -j CONNMARK --save-mark');
        push(@fcmds, '/sbin/iptables -t mangle -A OUTPUT -j CONNMARK --save-mark');

        foreach my $chain (FAILOVER_CHAIN, CHECKIP_CHAIN) {
            push(@fcmds, "/sbin/iptables -t mangle -N $chain");
            push(@fcmds, "/sbin/iptables -t mangle -A OUTPUT -j $chain");
        }

        EBox::Sudo::root(@fcmds);
    } catch {
    }
}

sub isRunning
{
    my ($self) = @_;
    return $self->isEnabled();
}

sub _supportActions
{
    return undef;
}

# Method: _preSetConf
#
#   Overrides <EBox::Module::Base::_preSetConf>
#
sub _preSetConf
{
    my ($self, %opts) = @_;

    # Don't do anything during boot to avoid bringing down interfaces
    # which are already bringed up by the networking service
    unless ((exists $ENV{USER}) or (exists $ENV{PLACK_ENV})) {
        return;
    }

    my $file = INTERFACES_FILE;
    my $restart = delete $opts{restart};

    try {
        EBox::Sudo::root(
            '/sbin/modprobe 8021q',
            '/sbin/vconfig set_name_type VLAN_PLUS_VID_NO_PAD'
        );
    } catch (EBox::Exceptions::Internal $e) {
    }

    $self->{restartResolvconf} = 0;

    # Ensure /var/run/resolvconf/resolv.conf exists
    if (not EBox::Sudo::fileTest('-f', '/var/run/resolvconf/resolv.conf')) {
        EBox::info("Creating file /var/run/resolvconf/resolv.conf");
        EBox::Sudo::root('touch /var/run/resolvconf/resolv.conf');
        $self->{restartResolvconf} = 1;
    }

    # Ensure /etc/resolv.conf is a symlink to /var/run/resolvconf/resolv.conf
    if (not EBox::Sudo::fileTest('-L', RESOLV_FILE)) {
        EBox::info("Restoring symlink /etc/resolv.conf");
        EBox::Sudo::root('rm -f ' . RESOLV_FILE);
        EBox::Sudo::root('ln -s /var/run/resolvconf/resolv.conf ' . RESOLV_FILE);
        $self->{restartResolvconf} = 1;
    }

    # Write DHCP client configuration
    my $hostname = $self->global()->modInstance('sysinfo')->hostName();
    $self->writeConfFile(DHCLIENTCONF_FILE, 'network/dhclient.conf.mas', [ hostname =>  $hostname]);

    # Bring down changed interfaces
    my $iflist = $self->allIfacesWithRemoved();
    foreach my $if (@{$iflist}) {
        my $dhcpIface = $self->ifaceMethod($if) eq 'dhcp';
        if ($self->_hasChanged($if) or $dhcpIface) {
            try {
                my @cmds;
                if ($self->ifaceExists($if)) {
                    my $ifname = $if;
                    if ($self->ifaceMethod($if) eq 'ppp') {
                        $ifname = "zentyal-ppp-$if";
                    } else {
                        push (@cmds, "/sbin/ip address flush label $if");
                        push (@cmds, "/sbin/ip address flush label $if:*");
                    }
                    if ($self->ifaceMethod($if) eq 'bundled') {
                        my $bond = $self->ifaceBond($if);
                        if($self->ifaceIsBond($if)) {
                            push (@cmds, "/sbin/ifenslave --force -d bond$bond $if");
                        }
                    }
                    EBox::Sudo::silentRoot("grep ^'iface $ifname inet' $file");
                    if ($? == 0) {
                        push (@cmds, "/sbin/ifdown --force -i $file $ifname");
                    }
                    if ($self->ifaceMethod($if) eq 'bridged') {
                        push (@cmds, "/sbin/brctl delbr $if");
                    }
                }

                EBox::Sudo::root(@cmds);
            } catch (EBox::Exceptions::Internal $e) {
            }
            #remove if empty
            if ($self->_isEmpty($if)) {
                unless ($self->isReadOnly()) {
                    $self->_removeIface($if);
                }
            }
        }
        # Clean up dhcp state if interface is not DHCP or
        # PPPoE it should be done by the dhcp, but sometimes
        # cruft is left
        if ($self->ifaceExists($if)) {
            unless ($self->ifaceMethod($if) eq any('dhcp', 'ppp')) {
                $self->DHCPCleanUp($if);
            }
        }
    }

    EBox::NetWrappers::clean_ifaces_list_cache();
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled and $self->{restartResolvconf}) {
        EBox::Service::manage('resolvconf', 'restart');
    }

    $self->SUPER::_postServiceHook($enabled);
}

sub _setConf
{
    my ($self) = @_;
    $self->generateInterfaces();
    $self->_generatePPPConfig();
    $self->_generateProxyConfig();
    $self->_writeFailoverCron();
}

# Method: _enforceServiceState
#
#   Overrides base method. It regenerates the network configuration.
#   It will set up the network interfaces, routes, dns...
sub _enforceServiceState
{
    my ($self, %opts) = @_;

    my $restart = delete $opts{restart};

    my $file = INTERFACES_FILE;

    EBox::Sudo::silentRoot("ip addr add 127.0.1.1/8 dev lo");

    my $dynIfaces = 0;
    my @ifups = ();
    my $iflist = $self->allIfacesWithRemoved();
    foreach my $iface (@{$iflist}) {
        next if ($self->ifaceMethod($iface) eq 'notset');

        my $dhcpIface = $self->ifaceMethod($iface) eq 'dhcp';
        if ($dhcpIface) {
            $dynIfaces = 1;
        }
        if ($self->_hasChanged($iface) or $dhcpIface or $restart) {
            if ($self->ifaceMethod($iface) eq 'ppp') {
                $iface = "zentyal-ppp-$iface";
                $dynIfaces = 1;
            }
            if ($self->ifaceIsBond($iface)) {
                # ifup bond slaves first
                my $bondIfaces = $self->bondIfaces($iface);
                foreach my $slaveIface (@{$bondIfaces}) {
                     push(@ifups, $slaveIface);
                }
            }
            push(@ifups, $iface);
        }
    }

    # Only execute ifups if we are not running from init on boot
    # The interfaces are already up thanks to the networking start
    if ((exists $ENV{USER}) or (exists $ENV{PLACK_ENV})) {
        EBox::Util::Lock::lock('ifup');
        foreach my $iface (@ifups) {
            EBox::Sudo::silentRoot("grep ^'iface $iface inet' $file");
            if ($? == 0) {
                EBox::Sudo::root(EBox::Config::scripts() . "unblock-exec /sbin/ifup --force -i $file $iface");
            }
            unless ($self->isReadOnly()) {
                $self->_unsetChanged($iface);
            }
        }
        EBox::Util::Lock::unlock('ifup');
        # Notify if ifup has been done
        $self->_flagIfUp(\@ifups);
    }
    EBox::NetWrappers::clean_ifaces_list_cache();

    $self->_generateResolvconfConfig();

    EBox::Sudo::silentRoot('/sbin/ip route del default table default',
                           '/sbin/ip route del default');

    my $cmd = $self->_multipathCommand();
    if ($cmd) {
        try {
            EBox::Sudo::root($cmd);
        } catch (EBox::Exceptions::Internal $e) {
            throw EBox::Exceptions::External("An error happened ".
                    "trying to set the default gateway. Make sure the ".
                    "gateway you specified is reachable.");
        }
    }

    $self->_generateRoutes();
    $self->_disableReversePath();
    $self->_multigwRoutes($dynIfaces);
    $self->_cleanupVlanIfaces();

    EBox::Sudo::root('/sbin/ip route flush cache');

    $self->SUPER::_enforceServiceState();
}

# Method:  restoreConfig
#
#   Restore its configuration from the backup file.
#
# Parameters:
#  dir - Directory where are located the backup files
#
sub restoreConfig
{
    my ($self, $dir) = @_;

    # Set all configured ifaces as changed
    foreach my $iface (@{$self->allIfaces()}) {
        $self->_setChanged($iface);
    }

    $self->SUPER::restoreConfig();
}

sub _stopService
{
    my ($self) = @_;

    return unless ($self->configured());

    my @cmds;
    my $file = INTERFACES_FILE;
    my $iflist = $self->allIfaces();
    foreach my $if (@{$iflist}) {
        try {
            my $ifname = $if;
            if ($self->ifaceMethod($if) eq 'ppp') {
                $ifname = "zentyal-ppp-$if";
            } else {
                push @cmds, "/sbin/ip address flush label $if";
                push @cmds, "/sbin/ip address flush label $if:*";
            }
            EBox::Sudo::silentRoot("grep ^'iface $ifname inet' $file");
            if ($? == 0) {
                push @cmds, "/sbin/ifdown --force -i $file $ifname";
            }
        } catch (EBox::Exceptions::Internal $e) {
        }
    }

    EBox::Sudo::root(@cmds);

    $self->SUPER::_stopService();
}

sub _routersReachableIfChange # (interface, newaddress?, newmask?)
{
    my ($self, $iface, $newaddr, $newmask) = @_;

    my @routes = @{$self->routes()};
    my @ifaces = @{$self->allIfaces()};
    my @gws = ();
    foreach my $route (@routes) {
        push(@gws, $route->{gateway});
    }

    foreach my $gw (@{$self->model('GatewayTable')->gateways()}) {
        next if $gw->{'auto'};
        my $ip = $gw->{'ip'};
        next unless $ip;
        push (@gws, $ip);
    }

    foreach my $gw (@gws) {
        $gw .= "/32";
        my $reachable = undef;
        foreach my $if (@ifaces) {
            my $host; my $mask; my $meth;
            if ($iface eq $if) {
                $host = $newaddr;
                $mask = $newmask;
            } else {
                $meth = $self->ifaceMethod($if);
                ($meth eq 'static') or next;
                $host = $self->ifaceAddress($if);
                $mask = $self->ifaceNetmask($if);
            }
            (defined($host) and defined($mask)) or next;
            if (isIPInNetwork($host, $mask, $gw)) {
                $reachable = 1;
            }
        }
        ($reachable) or throw EBox::Exceptions::External(
            __('The requested operation will cause one of the '.
               'configured gateways or static routes to become unreachable. ' .
               'Please remove it first if you really want to '.
               'make this change.'));
    }
    return 1;
}

# Method: gatewayReachable
#
#       Check if a given gateway address is reachable with the current
#       network configuration
#
# Parameters:
#
#       gw - String the IP address for the gateway
#
#       name - String A name to be shown if exception is launched. If
#       no given, then an exception is not launched. *(Optional)*
#       Default value: undef
#
# Returns:
#
#       Boolean - name of the interface used to reach the gateway
#                 undef if not reachable
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
#       <EBox::Exceptions::External> - thrown if name is supplied and
#       the gateway is not reachable
#
sub gatewayReachable
{
    my ($self, $gw, $name) = @_;

    $gw or throw EBox::Exceptions::MissingArgument('gw');

    my $reachableByNoStaticIface = undef;

    my $cidr_gw = "$gw/32";
    foreach my $iface (@{$self->allIfaces()}) {
        my $host = $self->ifaceAddress($iface);
        my $mask = $self->ifaceNetmask($iface);

        (defined($host) and defined($mask)) or next;

        checkIPNetmask($gw, $mask) or next;

        if (isIPInNetwork($host,$mask,$cidr_gw)) {
            my $meth = $self->ifaceMethod($iface);
            if ($meth ne 'static') {
                $reachableByNoStaticIface = $iface;
                next;
            }

            return $iface;
        }
    }

    if ($name) {
        if (not $reachableByNoStaticIface) {
        throw EBox::Exceptions::External(
                __x("Gateway {gw} must be in the same network that a static interface", gw => $gw));
        } else {
        throw EBox::Exceptions::External(
                __x("Gateway {gw} must be in the same network that static interface. "
                    . "Currently it belongs to the network of {iface} which is not static",
                    gw => $gw, iface => $reachableByNoStaticIface) );
        }

    } else {
        return undef;
    }
}

# Method: setDHCPAddress
#
#   Sets the parameters for a DHCP configured interface. For instance,
#   this function is primaraly used from a DHCP hook.
#
# Parameters:
#
#   iface - interface name
#   address - IPv4 address
#   mask - networking mask
sub setDHCPAddress # (interface, ip, mask)
{
    my ($self, $iface, $ip, $mask) = @_;

    if (not $iface =~ m{^/dev/pts/}) {
        $self->ifaceExists($iface) or
            throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                                 value => $iface);
    }
    checkIPNetmask($ip, $mask,  __("IP address"), __('Netmask'));

    my $state = $self->get_state();
    my $oldAddr = $state->{dhcp}->{$iface}->{address};
    my $oldMask = $state->{dhcp}->{$iface}->{mask};
    $state->{dhcp}->{$iface}->{address} = $ip;
    $state->{dhcp}->{$iface}->{mask} = $mask;
    $self->set_state($state);

    # Calling observers
    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    # Tell observers the interface way has changed
    foreach my $obs (@observers) {
        if ($self->ifaceIsExternal($iface)) {
            $obs->externalDhcpIfaceAddressChangedDone($iface, $oldAddr, $oldMask, $ip, $mask);
        } else {
            $obs->internalDhcpIfaceAddressChangedDone($iface, $oldAddr, $oldMask, $ip, $mask);
        }
    }
}

# Method: setDHCPGateway
#
#   Sets the obtained gateway via DHCP
#
# Parameters:
#
#   iface   - ethernet interface
#   gateway - gateway's IPv4 address
sub setDHCPGateway # (iface, gateway)
{
    my ($self, $iface, $gw) = @_;
    checkIP($gw, __("IP address"));
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);


    my $state = $self->get_state();
    $state->{dhcp}->{$iface}->{gateway} = $gw;
    $self->set_state($state);
}

# Method: setRealPPPIface
#
#   Sets the real PPP interface associated with the Ethernet one.
#
# Parameters:
#
#   iface     - ethernet interface name
#   ppp_iface - ppp interface name
#   ppp_addr  - IP address of the ppp interface
#
sub setRealPPPIface # (iface, ppp_iface, ppp_addr)
{
    my ($self, $iface, $ppp_iface, $ppp_addr) = @_;

   if (not $iface =~ m{^/dev/pts/}) {
        $self->ifaceExists($iface) or
            throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                                 value => $iface);
    }

    my $state = $self->get_state();
    $state->{interfaces}->{$iface}->{ppp_iface} = $ppp_iface;
    $self->set_state($state);

    checkIP($ppp_addr, __("IP address"));
    $state->{interfaces}->{$iface}->{ppp_addr} = $ppp_addr;
    $self->set_state($state);
}

# Method: DHCPCleanUp
#
#   Removes the dhcp configuration for a given interface
#   Also removes the PPPoE iface if exists
#
# Parameters:
#
#   interface - interface name
#
sub DHCPCleanUp # (interface)
{
    my ($self, $iface) = @_;

    if (not $iface =~ m{^/dev/pts/}) {
        $self->ifaceExists($iface) or
            throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                                 value => $iface);
    }

    my $state = $self->get_state();
    delete $state->{dhcp}->{$iface};
    delete $state->{interfaces}->{$iface}->{ppp_iface};
    $self->set_state($state);
}

# Method: BridgedCleanUp
#
#   Removes the bridge configuration for a given bridged interface
#
# Parameters:
#
#   interface - interface name
#
sub BridgedCleanUp # (interface)
{
    my ($self, $iface) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);

    my $bridge = $self->ifaceBridge($iface);

    # this changes the bridge
    if ($self->ifaceIsBridge("br$bridge")) {
        $self->_setChanged("br$bridge");
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$iface}->{bridge_id};
    $self->set('interfaces', $ifaces);

    $self->_removeEmptyBridges();
}

# Method: BundledCleanUp
#
#   Removes the bond configuration for a given bundled interface
#
# Parameters:
#
#   interface - interface name
#
sub BundledCleanUp # (interface)
{
    my ($self, $iface) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);

    my $bond = $self->ifaceBond($iface);

    # this changes the bond
    if ($self->ifaceIsBond("bond$bond")) {
        $self->_setChanged("bond$bond");
    }

    my $ifaces = $self->get_hash('interfaces');
    delete $ifaces->{$iface}->{bond_id};
    $self->set('interfaces', $ifaces);

    $self->_removeEmptyBonds();
}

# Method: selectedDefaultGateway
#
#   Returns the selected default gateway
#
sub selectedDefaultGateway
{
    my ($self) = @_;

    return $self->get('default/gateway');
}

# Method: storeSelectedDefaultGateway
#
#   Store the selected default gateway
#
# Parameters:
#
#   gateway - gateway id
#
sub storeSelectedDefaultGateway
{
    my ($self, $gateway) = @_;
    return $self->set('default/gateway', $gateway);
}

# Method: DHCPGateway
#
#   Returns the gateway from a dhcp configured interface
#
# Parameters:
#
#   iface - interface name (DHCP or PPPoE)
#
# Returns:
#
#   string - gateway
#
sub DHCPGateway
{
    my ($self, $iface) = @_;

    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);

    return $self->get_state()->{dhcp}->{$iface}->{gateway};
}

# Method: DHCPAddress
#
#   Returns the ip address from a dhcp configured interface
#
# Parameters:
#
#   interface - interface name
#
# Returns:
#
#   string - IPv4 address
#
sub DHCPAddress
{
    my ($self, $iface) = @_;

    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                                             value => $iface);

    return $self->get_state()->{dhcp}->{$iface}->{address};
}

# Method: DHCPNetmask
#
#   Returns the network mask from a dhcp configured interface
#
# Parameters:
#
#   interface - interface name
#
# Returns:
#
#   string - network mask
#
sub DHCPNetmask
{
    my ($self, $iface) = @_;

    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);

    return $self->get_state()->{dhcp}->{$iface}->{mask};
}

# Method: ping
#
#   Performs a ping test and returns the output
#
# Parameters:
#
#   host - host to ping (either ip or hostname)
#
# Returns:
#
#   string - output of the ping command
#
sub ping # (host)
{
    my ($self, $host) = @_;
    (checkIP($host) or checkDomainName($host)) or
        throw EBox::Exceptions::InvalidData
            ('data' => __('Host name'), 'value' => $host);
    return `ping -c 3 $host 2>&1`;
}

# Method: traceroute
#
#   Performs a traceroute test and returns it output
#
# Parameters:
#
#   host - host to trace the route (either ip or hostname)
#
# Returns:
#
#   string - output of the traceroute command
#
sub traceroute # (host)
{
    my ($self, $host) = @_;
    (checkIP($host) or checkDomainName($host)) or
        throw EBox::Exceptions::InvalidData
            ('data' => __('Host name'), 'value' => $host);
    my $out = EBox::Sudo::rootWithoutException("traceroute -I -n $host 2>&1");
    return join("\n", @{$out});
}

# Method: resolv
#
#   Performs a name resolution (using dig) and returns the output
#
# Parameters:
#
#   host - host name to resolve
#
# Returns:
#
#   string - output of the dig command
#
sub resolv # (host)
{
    my ($self, $host) = @_;
    checkDomainName($host, __("host name"));
    # +time=3 sets the timeout (the default is 5), it tries three times
    # so in the worst case it should take 9 seconds to return from this
    # call
    # FIXME: study which options make sense in dig, remove some stuff
    # from the output
    return `dig +time=3 $host 2>&1`;
}

# Method: wakeonlan
#
#   Performs a wakeonlan and returns the output
#
# Parameters:
#
#   broadcast - IP broadcast address to be used
#   macs - Array of MAC addresses of the computers to wake
#
# Returns:
#
#   string - output of the wakeonlan command
#
sub wakeonlan
{
    my ($self, $broadcast, @macs) = @_;
    my $param = "-i '$broadcast'";
    foreach my $mac (@macs) {
        $param .= " '$mac'";
    }

    return `wakeonlan $param 2>&1`;
}

# Method: externalConnectionWarning
#
#   Checks if the given iface is being used to connect to the Zentyal UI.
#   This is used to warn when trying to set is as external in the Interfaces
#   configuration or in the initial wizard.
#
# Parameters:
#
#   iface - name of the iface to check
#   request - Plack::Request reference.
#
sub externalConnectionWarning
{
    my ($self, $iface, $request) =  @_;

    my $remote = $request->address();
    my $command = "/sbin/ip route get to $remote" . ' | head -n 1 | sed -e "s/.*dev \(\w\+\).*/\1/" ';
    my $routeIface = `$command`;
    return 0 unless ($? == 0);
    chop($routeIface);
    if (defined($routeIface) and ($routeIface eq $iface)) {
        return 1;
    }
}

sub interfacesWidget
{
    my ($self, $widget) = @_;

    my @ifaces = @{$self->ifacesWithRemoved()};
    my $size = scalar (@ifaces) * 1.25;
    $size = 0.1 unless defined ($size);
    $widget->{size} = "'$size'";

    my $linkstatus = {};
    EBox::Sudo::silentRoot('/sbin/mii-tool > ' . EBox::Config::tmp . 'linkstatus');
    if (open(LINKF, EBox::Config::tmp . 'linkstatus')) {
        while (<LINKF>) {
            if (/link ok/) {
                my $i = (split(" ",$_))[0];
                chop($i);
                $linkstatus->{$i} = 1;
            } elsif(/no link/) {
                my $i = (split(" ",$_))[0];
                chop($i);
                $linkstatus->{$i} = 0;
            }
        }
    }
    foreach my $iface (@ifaces) {
        iface_exists($iface) or next;
        my $upStr = __("down");
        my $section = new EBox::Dashboard::Section($iface, $self->ifaceAlias($iface));
        $widget->add($section);

        if (iface_is_up($iface)) {
            $upStr = __("up");
        }

        my $externalStr;
        if ($self->ifaceIsExternal($iface)) {
            $externalStr = __('external');
        } else {
            $externalStr = __('internal');
        }

        my $linkStatusStr;
        if (defined($linkstatus->{$iface})) {
            if($linkstatus->{$iface}){
                $linkStatusStr =  __("link ok");
            }else{
                $linkStatusStr =  __("no link");
            }
        }

        my $status = "$upStr, $externalStr";
        if ($linkStatusStr) {
            $status .= ", $linkStatusStr";
        }

        $section->add(new EBox::Dashboard::Value (__("Status"), $status));

        my $ether = iface_mac_address($iface);
        if ($ether) {
            $section->add(new EBox::Dashboard::Value
                (__("MAC address"), $ether));
        }

        my @ips = iface_addresses($iface);
        foreach my $ip (@ips) {
            $section->add(new EBox::Dashboard::Value
                (__("IP address"), $ip));
        }
        my $graphs = new EBox::Dashboard::GraphRow();
        $section->add($graphs);

        my $cmd;

        my $statistics = "/sys/class/net/$iface/statistics";
        my $statsFile;

        open ($statsFile, "$statistics/tx_bytes");
        my $tx_bytes = <$statsFile>;
        close ($statsFile);
        chomp ($tx_bytes);
        $graphs->add(new EBox::Dashboard::CounterGraph
            (__("Tx bytes"),
            $iface . "_txbytes",
            $tx_bytes,
            'small'));

        open ($statsFile, "$statistics/rx_bytes");
        my $rx_bytes = <$statsFile>;
        close ($statsFile);
        chomp ($rx_bytes);
        $graphs->add(new EBox::Dashboard::CounterGraph
            (__("Rx bytes"),
            $iface . "_rxbytes",
            $rx_bytes,
            'small'));
    }
}

sub widgets
{
    return {
        'interfaces' => {
            'title' => __("Network Interfaces"),
            'widget' => \&interfacesWidget,
            'order' => 3,
            'default' => 1
        }
    };
}

# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Network',
                                        'icon' => 'network',
                                        'text' => __('Network'),
                                        'tag' => 'system',
                                        'order' => 40);

    $folder->add(new EBox::Menu::Item('url' => 'Network/Ifaces',
                                      'text' => __('Interfaces'),
                                      'order' => 10));

    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/GatewaysGeneral',
                                      'text' => __('Gateways'),
                                      'order' => 20));

    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/DNS',
                                      'text' => 'DNS',
                                      'order' => 30));

    $folder->add(new EBox::Menu::Item('url' => 'Network/View/ObjectTable',
                                    'text' => __('Objects'),
                                    'order' => 40));

    $folder->add(new EBox::Menu::Item('url' => 'Network/View/ServiceTable',
                                    'text' => __('Services'),
                                    'order' => 50));

    $folder->add(new EBox::Menu::Item('url' => 'Network/View/StaticRoute',
                                      'text' => __('Static Routes'),
                                      'order' => 60));

    $folder->add(new EBox::Menu::Item('url' => 'Network/Diag',
                                      'text' => __('Tools'),
                                      'order' => 80));

    $root->add($folder);
}

# Method: gateways
#
#   Return the enabled gateways
#
# Returns:
#
#   array ref of hash refs containing name, ip,
#   if it is the default gateway or not and the id  for the gateway.
#
#   Example:
#
#   [
#     {
#       name => 'gw1', ip => '192.168.1.1' , interface => 'eth0',
#       default => '1', id => 'foo1234'
#     }
#   ]
#
sub gateways
{
    my ($self) = @_;

    my $gatewayModel = $self->model('GatewayTable');

    return $gatewayModel->gateways();
}

sub _defaultGwAndIface
{
    my ($self) = @_;

    my $gw = $self->model('GatewayTable')->find('default' => 1);

    if ($gw and $gw->valueByName('enabled')) {
        return ($gw->valueByName('interface'), $gw->valueByName('ip'));
    } else {
        return (undef, undef);
    }
}

# Method: gatewaysWithMac
#
#   Return the enabled gateways and its mac address
#
# Returns:
#
#   array ref of hash refs containing name, ip,
#   if it is the default gateway or not and the id  for the gateway.
#
#   Example:
#
#   [
#     {
#       name => 'gw1', ip => '192.168.1.1' ,
#       defalut => '1', id => 'foo1234', mac => '00:00:fa:ba:da'
#     }
#   ]
#
sub gatewaysWithMac
{
    my ($self) = @_;

    my $gatewayModel = $self->model('GatewayTable');

    return $gatewayModel->gatewaysWithMac();

}

sub marksForRouters
{
    my ($self) = @_;

    my $marks = $self->model('GatewayTable')->marksForRouters();
}

# Method: balanceTraffic
#
#   Return if the traffic balancing is enabled or not
#
# Returns:
#
#   bool - true if enabled, otherwise false
#
sub balanceTraffic
{
    my ($self) = @_;

    my $multiGwOptions = $self->model('MultiGwRulesOptions');
    my $balanceTraffic =  $multiGwOptions->balanceTrafficValue();

    return ($balanceTraffic and (@{$self->gateways} > 1));
}

# Method: regenGateways
#
#   Recreate the default route table. This method is currently used
#   for the WAN failover and dynamic multi-gateway.
#
#
sub regenGateways
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();

    my $timeout = 180;
    my $locked = 0;

    while ((not $locked) and ($timeout > 0)) {
        try {
            EBox::Util::Lock::lock('network');
            $locked = 1;
        } catch (EBox::Exceptions::Lock $e) {
            sleep 5;
            $timeout -= 5;
        }
    }

    unless ($locked) {
        EBox::error('Network module has been locked for 60 seconds');
        return;
    }

    $self->saveConfig();
    my @commands;
    push (@commands, '/sbin/ip route flush table default || true');
    my $cmd = $self->_multipathCommand();
    if ($cmd) {
        push (@commands, $cmd);
    }

    # Silently delete duplicated MTU rules for PPPoE interfaces and
    # add them to the commands array
    push(@commands, @{$self->_pppoeRules(1)});

    try {
        EBox::Sudo::root(@commands);
    } catch {
        EBox::error('Something bad happened reseting default gateways');
    }
    $self->_multigwRoutes();

    EBox::Sudo::root('/sbin/ip route flush cache');

    $global->modRestarted('network');

    EBox::Util::Lock::unlock('network');
}

# Method: replicationExcludeKeys
#
#      Exclude these keys from replication.
#
# Overrides: <EBox::Module::Config::replicationExcludeKeys>
#
sub replicationExcludeKeys
{
    return [ 'interfaces', 'vlans' ];
}

# Group: Ifup flag methods

# Method: flagIfUp
#
# Returns:
#
#    Array ref - containing the ifaces that have set up in last setConf
#
#    undef - if the flag is not set
sub flagIfUp
{
    my ($self) = @_;

    my $state = $self->get_state();
    if (exists $state->{ifup}) {
        return $state->{ifup};
    }
    return undef;
}

# Method: unsetFlagIfUp
#
#    Delete flag if up
#
sub unsetFlagIfUp
{
    my ($self) = @_;

    my $state = $self->get_state();
    if (exists $state->{ifup}) {
        delete $state->{ifup};
        $self->set_state($state);
    }
}

# Group: Other methods

sub _pppoeRules
{
    my ($self, $flush) = @_;

    my @add;

    # Warning (if flush=1):
    #   Delete rules are immediately executed, add rules are returned
    #   this is for performance reasons, to allow to integrate them in other
    #   arrays, but the delete ones need to be executed with silentRoot,
    #   so they are executed separately.
    my @delete;

    # Special rule for PPPoE interfaces to avoid problems with large packets
    foreach my $if (@{$self->pppIfaces()}) {
        $if = $self->realIface($if);
        my $cmd = '/sbin/iptables -t mangle';
        my $params = "POSTROUTING -o $if -p tcp " .
            "-m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu";

        if ($flush) {
            push (@delete, "$cmd -D $params");
        }
        push (@add, "$cmd -A $params");
    }

    if ($flush) {
        EBox::Sudo::silentRoot(@delete);
    }

    return \@add;
}

sub _multipathCommand
{
    my ($self) = @_;

    my @gateways = @{$self->gateways()};

    if (scalar(@gateways) == 0) {
        # If WAN failover is enabled we put the default one
        if ($self->_failoverEnabled()) {
            my $row = $self->model('GatewayTable')->findValue(default => 1);
            unless ($row) {
                return undef;
            }
            my $ip = $row->valueByName('ip');
            my $iface = $row->valueByName('interface');
            my $weight = $row->valueByName('weight');
            push (@gateways, {ip => $ip, interface => $iface, weight => $weight});
        } else {
            return undef;
        }
    }

    my $numGWs = 0;

    my $cmd = 'ip route add table default default';
    for my $gw (@gateways) {

        # Skip gateways with unassigned address
        my $ip = $gw->{'ip'};
        next unless $ip;

        # Skip gateways with traffic balance disabled
        # except if we just have one gateway
        next unless ($gw->{'balance'} or (@gateways == 1));

        my $iface = $gw->{'interface'};
        my $method = $self->ifaceMethod($iface);

        $iface = $self->realIface($iface);
        my $if = new Net::Interface($iface);
        next unless $if->address;

        my $route = "via $ip dev $iface";
        if ($method eq 'ppp') {
            $route = "dev $iface";
        }

        $cmd .= " nexthop $route weight $gw->{'weight'}";

        $numGWs++;
    }

    if ($numGWs) {
        return $cmd;
    } else {
        return undef;
    }
}

# Method: _notifyChangedIface
#
#   Notify network observers the change of a interface has taken place
#
# Parameters:
#   (Named)
#
#   name - interface's name
#   oldMethod - old method
#   newMethod - new method
#   force - force
#   action - 'prechange' or 'postchange'
sub _notifyChangedIface
{
    my ($self, %args) = @_;
    my $name = $args{name};
    my $oldMethod = $args{oldMethod};
    my $newMethod = $args{newMethod};
    my $force = $args{force};
    my $action = $args{action};

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};
    foreach my $objs (@observers) {
            if ($action eq 'prechange') {
                if ($objs->ifaceMethodChanged($name, $oldMethod, $newMethod)) {
                    if ($force) {
                        $objs->freeIface($name);
                    } else {
                        throw EBox::Exceptions::DataInUse();
                    }
                }
            } else {
                $objs->ifaceMethodChangeDone($name);
            }
    }
}

# Method: importInterfacesFile
#
#   Parses /etc/network/interfaces and imports values
#   to the Zentyal network module configuration
#
sub importInterfacesFile
{
    my ($self) = @_;

    my $netcfg = '/etc/netplan/01-netcfg.yaml';

    return unless (-f $netcfg);

    my $DEFAULT_GW_NAME = 'default';

    my $yaml = YAML::XS::LoadFile($netcfg);
    my $network = $yaml->{network};
    return unless ($network);
    my $ifaces = $network->{ethernets};
    return unless ($ifaces);

    foreach my $name (keys %{$ifaces}) {
        my $iface = $ifaces->{$name};
        my $dhcp = $iface->{dhcp4};
        if ($dhcp and ($dhcp eq 'yes')) {
            $self->setIfaceDHCP($name, 0, 1);
        } elsif ($iface->{addresses}) {
            my ($ip, $bits) = split ('/', $iface->{addresses}->[0]);
            $self->setIfaceStatic($name, $ip, EBox::NetWrappers::mask_from_bits($bits), undef, 1);
            if ($iface->{gateway4}) {
                my $gwModel = $self->model('GatewayTable');
                my $defaultGwRow = $gwModel->find(name => $DEFAULT_GW_NAME);
                if ($defaultGwRow) {
                    EBox::info("Already a default gateway, keeping it");
                } else {
                    $gwModel->add(name      => $DEFAULT_GW_NAME,
                                  ip        => $iface->{gateway4},
                                  interface => $name,
                                  default   => 1);
                }
            }
            my $ns = $iface->{nameservers};
            if ($ns) {
                my $search = $ns->{search};
                if ($search) {
                    $self->model('SearchDomain')->importSystemSearchDomain($name, $search->[0]);
                }
                my $addresses = $ns->{addresses};
                if ($addresses) {
                    $self->model('DNSResolver')->importSystemResolvers($name, $addresses);
                }
            }
        }
    }

    $self->saveConfig();
}

sub _importDHCPAddresses
{
    my ($self) = @_;
    EBox::NetWrappers::clean_ifaces_list_cache();
    foreach my $iface (@{ $self->allIfaces() }) {
        if ($self->ifaceMethod($iface) eq 'dhcp') {
            my %addr;
            try {
                %addr = %{ iface_addresses_with_netmask($iface) };
            } catch {
                # ignore errors, just skip this interface;
            }
            if (not %addr) {
                next;
            }
            my ($address, $netmask) = each %addr;
            EBox::debug("_importDHCPAdress $iface $address $netmask");
            $self->setDHCPAddress($iface, $address, $netmask);
        }
    }
}

# Flag the iface is up
# Only useful to ha by now
sub _flagIfUp
{
    my ($self, $ifups) = @_;

    if (@{$ifups}) {
        my $state = $self->get_state();
        $state->{ifup} = $ifups;
        $self->set_state($state);
    }
}

sub searchContents
{
    my ($self, $searchStringRe) = @_;
    my @matches;
    my ($modelMatches) = $self->_searchRedisConfKeys($searchStringRe);

    push @matches, @{ $self->_interfaceSearchMatch($searchStringRe) };
    push @matches, @{ $self->_vlanSearchMatch($searchStringRe) };

    push @matches, @{ $modelMatches };


    return \@matches;
}

sub _interfaceSearchMatch
{
    my ($self, $searchStringRe) = @_;
    my @matches;
    my $interfaces = $self->get('interfaces', {});
    while (my ($iface, $attrs) = each %{$interfaces}) {
        my $ifMatchs = 0;
        if ($iface =~ m/$searchStringRe/) {
            $ifMatchs = 1;
        } else {
            while (my ($attrName, $attr) = each %{$attrs}) {
                if ($attrName eq 'virtual') {
                    while (my ($vname, $vattrs) = each %{$attr}) {
                        if ($vname =~ m/$searchStringRe/) {
                            $ifMatchs = 1;
                            last;
                        }
                        foreach my $vattrVal (values %{ $vattrs }) {
                            if ($vattrVal =~ m/$searchStringRe/) {
                                $ifMatchs = 1;
                                last;
                            }
                        }
                        if ($ifMatchs) {
                            last;
                        }
                    }
                } elsif ($attr =~ m/$searchStringRe/) {
                    $ifMatchs = 1;
                    last;
                }
            }
        }

        if ($ifMatchs) {
            my $ifName = $attrs->{alias} ? $attrs->{alias} : $iface;
            my $linkElements =  [
                {
                    title => $self->printableName(),
                },
                {
                    title => __('Interfaces'),
                    link => '/Network/Ifaces'
                },
                {
                    title => $ifName,
                    link => "/Network/Ifaces?iface=$iface"
                }
              ];
            my $match = {
                module => 'network',
                linkElements => $linkElements
               };
            push @matches, $match;
        }
    }

    return \@matches;
}

sub _vlanSearchMatch
{
    my ($self, $searchStringRe) = @_;
    my @matches;
    my $vlans = $self->get('vlans', {});
    foreach my $vlAttrs (values %{$vlans}) {
        my $vlanMatchs = 0;
        foreach my $attrVal (values %{$vlAttrs}) {
            if ($attrVal =~ m/$searchStringRe/) {
                $vlanMatchs = 1;
                last;
            }
        }

        if ($vlanMatchs) {
            my $linkElements =  [
                {
                    title => $self->printableName(),
                },
                {
                    title => __('Interfaces'),
                    link => '/Network/Ifaces'
                },
                {
                    title => $vlAttrs->{name},
                    link => "/Network/Ifaces?iface=" . $vlAttrs->{name}
                }
              ];
            my $match = {
                module => 'network',
                linkElements => $linkElements,
            };
            push @matches, $match;
        }
    }

    return \@matches;
}

sub _failoverEnabled
{
    my ($self) = @_;

    my $rules = $self->model('WANFailoverRules');
    return (@{$rules->enabledRows()} > 0);
}

sub _writeFailoverCron
{
    my ($self) = @_;

    my $cronFile = FAILOVER_CRON_FILE;

    if ($self->_failoverEnabled()) {
        my $failoverOptions = $self->model('WANFailoverOptions');
        my $minutes = $failoverOptions->value('period');
        EBox::Module::Base::writeConfFileNoCheck($cronFile, 'network/failover-checker.cron.mas',
                                                 [ minutes => $minutes ],
                                                 {
                                                  uid  => 'root',
                                                  gid  => 'root',
                                                  mode =>  '0644'
                                                 });
    } else {
        EBox::Sudo::root("rm -f $cronFile");
    }
}


### SERVICES ###

sub _defaultServices
{
    my ($self) = @_;

    my $webadminMod = $self->global()->modInstance('webadmin');
    my $webAdminPort;
    try {
        $webAdminPort = $webadminMod->listeningPort();
    } catch {
        $webAdminPort = $webadminMod->defaultPort();
    }

    return [
        {
         'name' => 'any',
         'printableName' => __('Any'),
         'description' => __('Any protocol and port'),
         'protocol' => 'any',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'any UDP',
         'printableName' => __('Any UDP'),
         'description' => __('Any UDP port'),
         'protocol' => 'udp',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'any TCP',
         'printableName' => __('Any TCP'),
         'description' => __('Any TCP port'),
         'protocol' => 'tcp',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'any ICMP',
         'printableName' => __('Any ICMP'),
         'description' => __('Any ICMP packet'),
         'protocol' => 'icmp',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'zentyal_' . $webadminMod->name(),
         'printableName' => $webadminMod->printableName(),
         'description' => $webadminMod->printableName(),
         'protocol' => 'tcp',
         'destinationPort' => $webAdminPort,
         'internal' => 1,
        },
        {
         'name' => 'ssh',
         'printableName' => 'SSH',
         'description' => __('Secure Shell'),
         'protocol' => 'tcp',
         'destinationPort' => '22',
         'internal' => 0,
        },
        {
         'name' => 'HTTP',
         'printableName' => 'HTTP',
         'description' => __('HyperText Transport Protocol'),
         'protocol' => 'tcp',
         'destinationPort' => '80',
         'internal' => 0,
        },
        {
         'name' => 'HTTPS',
         'printableName' => 'HTTPS',
         'description' => __('HyperText Transport Protocol over SSL'),
         'protocol' => 'tcp',
         'destinationPort' => '443',
         'internal' => 0,
        },
    ];
}

# Method: serviceNames
#
#       Fetch all the service identifiers and names
#
# Returns:
#
#       Array ref of  hash refs which contain:
#
#       'id' - service identifier
#       'name' service name
#
#       Example:
#         [
#          {
#            'name' => 'ssh',
#            'id' => 'serv7999'
#          },
#          {
#            'name' => 'ftp',
#            'id' => 'serv7867'
#          }
#        ];
sub serviceNames
{
    my ($self) = @_;

    my $servicesModel = $self->model('ServiceTable');
    my @services;

    foreach my $id (@{$servicesModel->ids()}) {
        my $name = $servicesModel->row($id)->valueByName('name');
        push @services, {
            'id' => $id,
            'name' => $name
           };
    }

    return \@services;
}

# Method: serviceConfiguration
#
#       For a given service identifier it returns its service configuration,
#       that is, the set of protocols and ports.
#
# Returns:
#
#       Array ref of  hash refs which contain:
#
#       protocol - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#       source   - it can take:
#                       "any"
#                       An integer from 1 to 65536 -> 22
#                       Two integers separated by colons -> 22:25
#       destination - same as source
#
#       Example:
#         [
#             {
#              'protocol' => 'tcp',
#               'source' => 'any',
#               'destination' => '21:22',
#             }
#         ]
sub serviceConfiguration
{
    my ($self, $id) = @_;

    throw EBox::Exceptions::ArgumentMissing("id") unless defined($id);

    my $row = $self->model('ServiceTable')->row($id);

    unless (defined($row)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service by id',
                'value' => $id);
    }

    my $model = $row->subModel('configuration');

    my @conf;
    foreach my $id (@{$model->ids()}) {
        my $subRow = $model->row($id);
        push (@conf, {
                        'protocol' => $subRow->valueByName('protocol'),
                        'source' => $subRow->valueByName('source'),
                        'destination' => $subRow->valueByName('destination')
                      });
    }

    return \@conf;
}

# Method: serviceIptablesArgs
#
#  get a list with the iptables arguments required to match each of the
#  configurations of the service (see serviceConfiguration)
#
#  Warning:
#    for any/any/any configuration a empty string is the correct iptables argument
sub serviceIptablesArgs
{
    my ($self, $id) = @_;
    my @args;
    my @conf =  @{ $self->serviceConfiguration($id) };
    foreach my $conf (@conf) {
        my $args = '';
        my $tcpUdp = 0;
        if ($conf->{protocol} eq 'tcp/udp') {
            $tcpUdp = 1;
        } elsif ($conf->{protocol} ne 'any') {
            $args .= '--protocol ' . $conf->{protocol};
        }
        if ($conf->{source} ne 'any') {
            $args .= ' --sport ' . $conf->{source};
        }
        if ($conf->{destination} ne 'any') {
            $args .= ' --dport ' . $conf->{destination};
        }

        if ($tcpUdp) {
            my $tcpArgs = '--protocol tcp' . $args;
            my $udpArgs = '--protocol udp' . $args;
            push @args, ($tcpArgs, $udpArgs);
        } else {
            push @args, $args;
        }
    }

    return \@args;
}

# Method: addService
#
#   Add a service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#   sourcePort  - it can take:
#                   "any"
#                   An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25
#   destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#           'protocol' => 'tcp',
#           'sourcePort' => 'any',
#       'destinationPort' => '21:22',
#
#   Returns:
#
#   string - id of the new created row
sub addService
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->addService(%params);
}

# Method: addMultipleService
#
#   Add a multi protocol service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#   services - array ref of hash ref containing:
#
#           protocol    - it can take one of these: any, tcp, udp,
#                                                   tcp/udp, grep, icmp
#           sourcePort  - it can take:  "any"
#                                   An integer from 1 to 65536 -> 22
#                                   Two integers separated by colons -> 22:25
#           destinationPort - same as source
#
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#       'services' => [
#                       {
#                               'protocol' => 'tcp',
#                               'sourcePort' => 'any',
#                           'destinationPort' => '21:22'
#                        },
#                        {
#                               'protocol' => 'tcp',
#                               'sourcePort' => 'any',
#                           'destinationPort' => '21:22'
#                        }
#                     ];
#
#   Returns:
#
#   string - id of the new created row
sub addMultipleService
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->addMultipleService(%params);
}

# Method: setService
#
#   Set a existing service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#       protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#       sourcePort  - it can take:
#                   "any"
#                    An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25
#       destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#           'protocol' => 'tcp',
#           'sourcePort' => 'any',
#       'destinationPort' => '21:22',
sub setService
{
    my ($self, %params) = @_;

    $self->model('ServiceTable')->setService(%params);
}

# Method: setMultipleService
#
#   Set a multi protocol service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#   services - array ref of hash ref containing:
#
#	    protocol    - it can take one of these: any, tcp, udp,
#	                                            tcp/udp, grep, icmp
#	    sourcePort  - it can take:  "any"
#                                   An integer from 1 to 65536 -> 22
#                                   Two integers separated by colons -> 22:25
#	    destinationPort - same as source
#
#
#	Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#       'services' => [
#                       {
#	                        'protocol' => 'tcp',
#	                        'sourcePort' => 'any',
#                               'destinationPort' => '21:22'
#                        },
#                        {
#	                        'protocol' => 'tcp',
#	                        'sourcePort' => 'any',
#                               'destinationPort' => '21:22'
#                        }
#                     ];
#
#   Returns:
#
#   string - id of the updated row
#
sub setMultipleService
{
    my ($self, %params) = @_;

    $self->model('ServiceTable')->setMultipleService(%params);
}

# Method: availablePort
#
#       Check if a given port for a given protocol is available. That is,
#       no internal service uses it.
#
# Parameters:
#
#   (POSITIONAL)
#   protocol   - it can take one of these: tcp, udp
#   port           - An integer from 1 to 65536 -> 22
#
# Returns:
#   boolean - true if it's available, otherwise false
#
# Note:
#    portUsedByService returns the information of what is using the port
sub availablePort
{
    my ($self, @params) = @_;
    return not $self->portUsedByService(@params);
}

# Method: portUsedByService
#
#       Checks if a port is configured to be used by a service
#
# Parameters:
#
#       proto - protocol
#       port - port number
#       interface - interface
#
# Returns:
#
#       false - if it is not used not empty string - if it is in use, the string
#               contains the name of what is using it
sub portUsedByService
{
    my ($self, @params) = @_;
    return $self->model('ServiceTable')->portUsedByService(@params);
}

# Method: serviceFromPort
#
#       Get the service name that it's using a port.
#
# Parameters:
#
#   (POSITIONAL)
#   protocol   - it can take one of these: tcp, udp
#   port       - An integer from 1 to 65536 -> 22
#
# Returns:
#   string - the service name, undef otherwise
#
sub serviceFromPort
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->serviceFromPort(%params);
}

# Method: removeService
#
#  Remove a service from the  services table
#
# Parameters:
#
#   (NAMED)
#
#   You can select the service using one of the following parameters:
#
#       name - service's name
#       id - service's id
sub removeService
{
    my ($self, %params) = @_;

    unless (exists $params{'id'} or exists $params{'name'}) {
        throw EBox::Exceptions::MissingArgument('service');
    }

    my $model =  $self->model('ServiceTable');
    my $id = $params{'id'};

    if (not defined($id)) {
        my $name = $params{'name'};
        my $row = $model->findValue('name' => $name);
        unless (defined($row)) {
            throw EBox::Exceptions::External("service $name not found");
        }
        $id = $row->id();
    }

    $model->removeRow($id, 1);
}

# Method: serviceExists
#
#   Check if a given service already exits
#
# Paremeters:
#
#   (NAMED)
#   You can select the service using one of the following parameters:
#
#       name - service's name
#       id - service's id
sub serviceExists
{
    my ($self, %params) = @_;

    unless (exists $params{'id'} or exists $params{'name'}) {
        throw EBox::Exceptions::MissingArgument('service id or name');
    }

    my $model =  $self->model('ServiceTable');
    my $id = $params{'id'};

    my $row;
    if (not defined($id)) {
        my $name = $params{'name'};
        $row = $model->findValue('name' => $name);
    } else {
        $row = $model->row($id);
    }

    return defined($row);
}

# Method: serviceId
#
#   Given a service's name it returns its id
#
# Paremeters:
#
#   (POSITIONAL)
#
#   name - service's name
#
# Returns:
#
#   service's id if it exists, otherwise undef
sub serviceId
{
    my ($self, $name) = @_;

    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $model = $self->model('ServiceTable');
    my $row = $model->findValue('name' => $name);
    if (not defined $row) {
        return undef;
    }

    return $row->id();
}

# Method: setAdministrationPort
#
#       Set administration port on services module
#
# Parameters:
#
#       port - Int the new port
#
sub setAdministrationPort
{
    my ($self, $port) = @_;

    my $webadminMod = $self->global()->modInstance('webadmin');

    $self->setService(
            'name' => 'zentyal_' . $webadminMod->name(),
            'printableName' => $webadminMod->printableName(),
            'description' => $webadminMod->printableName(),
            'protocol' => 'tcp',
            'sourcePort' => 'any',
            'destinationPort' => $port,
            'internal' => 1,
            'readOnly' => 1
    );
}

### OBJECTS ###

# Method: objects
#
#       Return all object names
#
# Returns:
#
#       Array ref. Each element is a hash ref containing:
#
#       id - object's id
#       name - object's name
sub objects
{
    my ($self) = @_;

    my @objects;
    my $model = $self->model('ObjectTable');
    for my $id (@{$model->ids()}) {
    my $object = $model->row($id);
        push (@objects, {
                            id => $id,
                            name => $object->valueByName('name')
                         });
    }

    return \@objects;
}

# Method: objectIds
#
#       Return all object ids
#
# Returns:
#
#       Array ref - containing ids
sub objectIds # (object)
{
    my ($self) = @_;

    my @ids = map { $_->{'id'} }  @{$self->objects()};
    return  \@ids;
}

# objectMembers
#
#       Return the members belonging to an object
#
# Parameters:
#
#       (POSITIONAL)
#
#       id - object's id
#
# Returns:
#
#       <EBox::Objects::Members>
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument>
sub objectMembers # (object)
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $object = $self->model('ObjectTable')->row($id);
    if (not $object) {
        throw EBox::Exceptions::DataNotFound(
                        data   => __('network object'),
                        value  => $id
           );
    }

    return $object->subModel('members')->members();
}

# objectAddresses
#
#       Return the network addresses of a object
#
# Parameters:
#
#       id - object's id
#       mask - return also addresses' mask (named optional, default false)
#       ranges - return ranges instead of full list of addresses (named optional, default false)
#
# Returns:
#
#       array ref - containing an ip, empty array if
#       there are no addresses in the object
#       In case mask is wanted the elements of the array would be  [ip, mask]
#
sub objectAddresses
{
    my ($self, $id, @params) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $members = $self->objectMembers($id);
    return $members->addresses(@params);
}

# Method: objectDescription
#
#       Return the description of an Object
#
# Parameters:
#
#       id - object's id
#
# Returns:
#
#       string - description of the Object
#
# Exceptions:
#
#       DataNotFound - if the Object does not exist
sub objectDescription  # (object)
{
    my ( $self, $id ) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $object = $self->model('ObjectTable')->row($id);
    unless (defined($object)) {
        throw EBox::Exceptions::DataNotFound('data' => __('Object'),
                'value' => $object);
    }

    return $object->valueByName('name');
}

# get ( $id, ['name'])

# Method: objectInUse
#
#       Asks all installed modules if they are currently using an Object.
#
# Parameters:
#
#       object - the name of an Object
#
# Returns:
#
#       boolean - true if there is a module which uses the Object, otherwise
#       false
sub objectInUse # (object)
{
    my ($self, $object ) = @_;

    unless (defined($object)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::Objects::Observer')};
    foreach my $mod (@mods) {
        if ($mod->usesObject($object)) {
            return 1;
        }
    }

    return undef;
}

# Method: objectExists
#
#       Checks if a given object exists
#
# Parameters:
#
#       id - object's id
#
# Returns:
#
#       boolean - true if the Object exists, otherwise false
sub objectExists
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument("id");
    }

    return defined($self->model('ObjectTable')->row($id));
}

# Method: removeObjectForce
#
#       Forces an object to be deleted
#
# Parameters:
#
#       object - object description
#
sub removeObjectForce # (object)
{
    #action: removeObjectForce

    my ($self, $object)  = @_;
    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::Objects::Observer')};
    foreach my $mod (@mods) {
        $mod->freeObject($object);
    }
}

# Method: addObject
#
#   Add object to the objects table.
#
# Parameters:
#
#   (NAMED)
#   id         - object's id *(optional*). It will be generated automatically
#                if none is passed
#   name       - object's name
#   members    - array ref containing the following hash ref in each value:
#
#                name        - member's name
#                address_selected - type of address, can be:
#                                'ipaddr', 'iprange' (default: ipdaddr)
#
#                ipaddr  parameters:
#                   ipaddr_ip   - member's ipaddr
#                   ipaddr_mask - member's mask
#                   macaddr     - member's mac address *(optional)*
#
#               iprange parameters:
#                   iprange_begin - begin of the range
#                   iprange_end   - end of range
#
#   readOnly   - the service can't be deleted or modified *(optional)*
#
#   Example:
#
#       name => 'administration',
#       members => [
#                   { 'name'         => 'accounting',
#                     'address_selected' => 'ipaddr',
#                     'ipaddr_ip'    => '192.168.1.3',
#                     'ipaddr_mask'  => '32',
#                     'macaddr'      => '00:00:00:FA:BA:DA'
#                   }
#                  ]

sub addObject
{
    my ($self, %params) = @_;

    return $self->model('ObjectTable')->addObject(%params);
}

# Method: addMemberToObject
#
#   Add a member to the given network object
#
# Parameters:
#
#   id         - object's id
#   member     - array ref containing the following hash ref in each value:
#
#                name        - member's name
#                address_selected - type of address, can be:
#                                'ipaddr', 'iprange'
#
#                ipaddr  parameters:
#                   ipaddr_ip   - member's ipaddr
#                   ipaddr_mask - member's mask
#                   macaddr     - member's mac address *(optional)*
#
#               iprange parameters:
#                   iprange_begin - begin of the range
#                   iprange_end   - end of range
#
#   Member example:
#
#       {
#           'name'         => 'accounting',
#           'address_selected' => 'ipaddr',
#           'ipaddr_ip'    => '192.168.1.3',
#           'ipaddr_mask'  => '32',
#           'macaddr'      => '00:00:00:FA:BA:DA'
#       }
#
sub addMemberToObject # (objectId, member)
{
    my ($self, $id, $member) = @_;

    if (not $self->objectExists($id)) {
        return 0;
    }

    my $object = $self->model('ObjectTable')->row($id);
    $object->subModel('members')->addRow(%{$member});
}

# Method: removeObjectMembers
#
#   Removes all the members from the given network object
#
# Parameters:
#
#   id         - object's id
#
sub removeObjectMembers # (objectId)
{
    my ($self, $objectId) = @_;

    if (not $self->objectExists($objectId)) {
        return 0;
    }

    my $membersModel = $self->model('ObjectTable')->row($objectId)->subModel('members');
    for my $id (@{$membersModel->ids()}) {
        $membersModel->removeRow($id);
    }
}

# Method: removeObjectMember
#
#   Removes all the members from the given network object
#
# Parameters:
#
#   objectId    - object's id
#   memberId    - member's id
#
sub removeObjectMember # (objectId, memberId)
{
    my ($self, $objectId, $memberId) = @_;

    if (not $self->objectExists($objectId)) {
        return 0;
    }

    my $membersModel = $self->model('ObjectTable')->row($objectId)->subModel('members');
    if (defined ($membersModel->row($memberId))) {
        $membersModel->removeRow($memberId);
    }
}

1;