# Copyright (C) 2008-2011 eBox Technologies S.L.
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

package EBox::Network;

use strict;
use warnings;

use base qw(
            EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
           );

# Interfaces list which will be ignored
use constant ALLIFACES => qw(sit tun tap lo irda eth wlan vlan);
use constant IGNOREIFACES => qw(sit tun tap lo irda ppp);
use constant IFNAMSIZ => 16; #Max length name for interfaces
use constant INTERFACES_FILE => '/etc/network/interfaces';
use constant DDCLIENT_FILE => '/etc/ddclient.conf';
use constant DEFAULT_DDCLIENT_FILE => '/etc/default/ddclient';
use constant RESOLV_FILE => '/etc/resolv.conf';
use constant DHCLIENTCONF_FILE => '/etc/dhcp3/dhclient.conf';
use constant PPP_PROVIDER_FILE => '/etc/ppp/peers/ebox-ppp-';
use constant CHAP_SECRETS_FILE => '/etc/ppp/chap-secrets';
use constant PAP_SECRETS_FILE => '/etc/ppp/pap-secrets';
use constant IFUP_LOCK_FILE => '/var/lib/ebox/tmp/ifup.lock';
use constant APT_PROXY_FILE => '/etc/apt/apt.conf.d/99proxy.conf';
use constant ENV_PROXY_FILE => '/etc/profile.d/zentyal-proxy.sh';
use constant CRON_FILE      => '/etc/cron.d/ebox-network';

use Net::IP;
use IO::Interface::Simple;
use Perl6::Junction qw(any);
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);
use EBox::Config;
use EBox::Order;
use EBox::ServiceManager;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Lock;
use Error qw(:try);
use EBox::Dashboard::Widget;
use EBox::Dashboard::Section;
use EBox::Dashboard::CounterGraph;
use EBox::Dashboard::GraphRow;
use EBox::Dashboard::Value;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo qw( :all );
use EBox::Gettext;
#use EBox::LogAdmin qw( :all );
use File::Basename;
use EBox::Common::Model::EnableForm;
use EBox::Util::Lock;
use EBox::DBEngineFactory;

# XXX uncomment when DynLoader bug with locales is fixed
# use EBox::Network::Report::ByteRate;


sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'network',
                    printableName => __n('Network'),
                    domain => 'ebox-network',
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
    }
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
        'file' => RESOLV_FILE,
        'reason' => __('Zentyal will set your DNS configuration'),
        'module' => 'network'
    },
    {
        'file' => DHCLIENTCONF_FILE,
        'reason' => __('Zentyal will set your DHCP client configuration'),
        'module' => 'network'
    },
    {
        'file' => DEFAULT_DDCLIENT_FILE,
        'reason' => __('Zentyal will set your ddclient configuration'),
        'module' => 'network'
    },
    {
        'file' => DDCLIENT_FILE,
        'reason' => __('Zentyal will set your ddclient configuration'),
        'module' => 'network'
    },
    {
        'file' => CHAP_SECRETS_FILE,
        'reason' => __('Zentyal will store your PPPoE passwords'),
        'module' => 'network'
    },
    {
        'file' => PAP_SECRETS_FILE,
        'reason' => __('Zentyal will store your PPPoE passwords'),
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
        push (@files, { 'file' => ENV_PROXY_FILE,
                        'reason' => __('Zentyal will set HTTP proxy for all users'),
                        'module' => 'network' });
        push (@files, { 'file' => APT_PROXY_FILE,
                        'reason' => __('Zentyal will set HTTP proxy for APT'),
                        'module' => 'network' });
    }

    return \@files;
}



sub modelClasses
{
  return [
      {
       class      => 'EBox::Network::Model::GatewayTable',
       parameters => [
                          directory => 'gatewaytable',
                         ],
      },
      {
           class     => 'EBox::Network::Model::MultiGwRulesDataTable',
           parameters => [
                          directory => 'multigwrulestable',
                         ],
          },
          'EBox::Network::Model::MultiGwRulesOptions',

# XXX uncomment when DynLoader bug with locales is fixed
#          {
#            class      => 'EBox::Network::Model::ByteRateEnableForm',
#            parameters => [
#                           enableTitle  => __('Activate traffic rate monitor'),
#                           domain       => 'ebox-network',
#                           modelDomain  => 'Network',
#                          ],
#           },
#     'EBox::Network::Model::ByteRateSettings',
#     'EBox::Network::Model::ByteRateGraph',
#     'EBox::Network::Model::ByteRateGraphControl',
          'EBox::Network::Model::StaticRoute',
          'EBox::Network::Model::DeletedStaticRoute',
          'EBox::Network::Model::DNSResolver',
          'EBox::Network::Model::SearchDomain',
          'EBox::Network::Model::DynDNS',
          'EBox::Network::Model::WANFailoverOptions',
          'EBox::Network::Model::WANFailoverRules',
          'EBox::Network::Model::Proxy',

     ];
}


sub compositeClasses
{
    return [
        'EBox::Network::Composite::MultiGw',
        'EBox::Network::Composite::DNS',
        'EBox::Network::Composite::WANFailover',
        'EBox::Network::Composite::Gateway',

# XXX uncomment when DynLoader bug with locales is fixed
#          'EBox::Network::Composite::ByteRate',
        ];

}

# Method: _exposedMethods
#
#
# Overrides:
#
#      <EBox::Model::ModelProvider::_exposedMethods>
#
# Returns:
#
#      hash ref - the list of the exposes method in a hash ref every
#      component
#
sub _exposedMethods
{
    my %exposedMethods =
      (
       'addRoute' => { action => 'add',
                       path   => [ 'StaticRoute' ],
                     },
       'delRoute' => { action  => 'del',
                       path    => [ 'StaticRoute' ],
                       indexes => [ 'network' ],
                       separator => ':',
                   },
       'changeGateway' => { action   => 'set',
                            path     => [ 'StaticRoute' ],
                            indexes  => [ 'network' ],
                            selector => [ 'gateway' ],
                            separator => ':'
                          },
       'addNS'    => { action => 'add',
                       path   => [ 'DNSResolver' ],
                     },
       'setNS'    => { action   => 'set',
                       path     => [ 'DNSResolver' ],
                       indexes  => [ 'position' ],
                       selector => [ 'nameserver' ],
                     },
       'removeNS' => { action  => 'del',
                       path    => [ 'DNSResolver' ],
                       indexes => [ 'position' ],
                     },
      );
    return \%exposedMethods;
}



# Method: wizardPages
#
#   Override EBox::Module::Base::wizardPages
#
sub wizardPages
{
    my ($self) = @_;

    return [ '/Network/Wizard/Ifaces',
             '/Network/Wizard/Network' ];
}


# Method: IPAddressExists
#
#   Returns true if the given IP address belongs to a statically configured
#   network interface
#
# Parameters:
#
#       ip - ip adddress to check
#
# Returns:
#
#       EBox::Module instance
#
sub IPAddressExists
{
    my ($self, $ip) = @_;
    my @ifaces = @{$self->allIfaces()};

    foreach my $iface (@ifaces) {
        unless ($self->ifaceMethod($iface) eq 'static') {
            next;
        }
        if ($self->ifaceAddress($iface) eq $ip) {
            return 1;
        }
    }
    return undef;
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
        if ($self->ifaceIsExternal($_)) {
            push(@array, $_);
        }
    }
    return \@array;
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
        unless ($self->ifaceIsExternal($_)) {
            push(@array, $_);
        }
    }
    return \@array;
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
        return 1; # bridges are always processed as external
    }
    return $self->get_bool("interfaces/$iface/external");
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

    if ( $self->ifaceExists($iface) and $iface =~ /^br/ ) {
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
sub ifaceOnConfig # (interface)
{
    my ($self, $name) = @_;
    defined($name) or return undef;
    if ($self->vifaceExists($name)) {
        return 1;
    }
    return defined($self->get_string("interfaces/$name/method"));
}

sub _ignoreIface($$)
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
    foreach my $iface (@iflist) {
        if ($iface =~ /^vlan/) {
            $iface =~ s/^vlan//;
            unless ($self->dir_exists("vlans/$iface")) {
                root("/sbin/vconfig rem vlan$iface");
            }
        }
    }
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
sub ifaceAddresses # (interface)
{
    my ($self, $iface) = @_;
    my @array = ();

    if ($self->vifaceExists($iface)) {
        return \@array;
    }

    if ($self->ifaceMethod($iface) eq 'static') {
        my $addr = $self->get_string("interfaces/$iface/address");
        my $mask = $self->get_string("interfaces/$iface/netmask");
        push(@array, {address=>$addr, netmask=>$mask});
        my @virtual = $self->all_dirs("interfaces/$iface/virtual");
        foreach (@virtual) {
            my $name = basename($_);
            $addr = $self->get_string("$_/address");
            $mask = $self->get_string("$_/netmask");
            push(@array,   {address=>$addr,
                    netmask=>$mask,
                    name=>$name});
        }
    } elsif ($self->ifaceMethod($iface) eq any('dhcp', 'ppp')) {
        my $addr = $self->DHCPAddress($iface);
        my $mask = $self->DHCPNetmask($iface);
        if ($addr) {
            push(@array, {address=>$addr, netmask=>$mask});
        }
    } elsif ($self->ifaceMethod($iface) eq 'bridged') {
        my $bridge = $self->ifaceBridge($iface);
        return $self->ifaceAddresses("br$bridge");
    }
    return \@array;
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
#   'name'
sub vifacesConf # (interface)
{
    my $self = shift;
    my $iface = shift;
    defined($iface) or return;

    my @vifaces = $self->all_dirs("interfaces/$iface/virtual");
    my @array = ();
    foreach (@vifaces) {
        my $hash = $self->hash_from_dir("$_");
        if (defined $hash->{'address'}) {
            $hash->{'name'} = basename($_);
            push(@array, $hash);
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
# XXX TODO: This method should be calle vifacesNames instead!
sub vifaceNames # (interface)
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
sub _vifaceExists # (real, virtual)
{
    my ($self, $iface, $viface) = @_;

    unless ($self->ifaceMethod($iface) eq 'static') {
        throw EBox::Exceptions::Internal("Could not exist a virtual " .
                      "interface in non-static interface");
    }

    foreach (@{$self->vifacesConf($iface)}) {
        if ($_->{'name'} eq $viface) {
            return 1;
        }
    }
    return undef;
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
#   boolean - true, if the interface exists, otherwise false

sub vifaceExists # (interface)
{
    my ($self, $name) = @_;

    my ($iface, $viface) = $self->_viface2array($name);
    unless ($iface and $viface) {
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
sub setViface # (real, virtual, address, netmask)
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

    if ($self->IPAddressExists($address)) {
        throw EBox::Exceptions::DataExists(
                    'data' => __('IP address'),
                    'value' => $address);
    }
    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
    foreach my $mod (@mods) {
        try {
            settextdomain($mod->{domain});
            $mod->vifaceAdded($iface, $viface, $address, $netmask);
        } otherwise {
            my $ex = shift;
            settextdomain('ebox');
            throw $ex;
        };
    }
    settextdomain('ebox');

    $self->set_string("interfaces/$iface/virtual/$viface/address",$address);
    $self->set_string("interfaces/$iface/virtual/$viface/netmask",$netmask);
    $self->set_bool("interfaces/$iface/changed", 'true');
}

# Method: removeViface
#
#   Removes a virtual interface
#
# Parameters:
#
#   iface - the name of a real network interface
#   viface - the name of the virtual interface
#
# Returns:
#
#   boolean - true if exists, otherwise false
#
# Exceptions:
#
#   Internal - If the real interface is not configured as static
sub removeViface # (real, virtual, force)
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

    $self->delete_dir("interfaces/$iface/virtual/$viface");
    $self->set_bool("interfaces/$iface/changed", 'true');
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
sub setIfaceAlias # (iface, alias)
{
    my ($self, $iface, $alias) = @_;
    $self->set_string("interfaces/$iface/alias", $alias);
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
    my $alias = $self->get_string("interfaces/$iface/alias");
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
#   string - dhcp|static|notset|trunk|ppp|bridged
#           dhcp -> the interface is configured via dhcp
#           static -> the interface is configured with a static ip
#           ppp -> the interface is configured via PPP
#           notset -> the interface exists but has not been
#                 configured yet
#           trunk -> vlan aware interface
#           bridged -> bridged to other interfaces
sub ifaceMethod # (interface)
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
    return $self->get_string("interfaces/$name/method");
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
sub setIfaceDHCP # (interface, external, force)
{
    my ($self, $name, $ext, $force) = @_;
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

    $self->set_bool("interfaces/$name/external", $ext);
    $self->unset("interfaces/$name/address");
    $self->unset("interfaces/$name/netmask");
    $self->set_string("interfaces/$name/method", 'dhcp');
    $self->set_bool("interfaces/$name/changed", 'true');

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
sub setIfaceStatic # (interface, address, netmask, external, force)
{
    #action: set_iface_static

    my ($self, $name, $address, $netmask, $ext, $force) = @_;
    $self->ifaceExists($name) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $name);


    checkIPNetmask($address, $netmask, __('IP address'), __('Netmask'));

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

    if ((!defined($oldaddr) or ($oldaddr ne $address)) and
        $self->IPAddressExists($address)) {
        throw EBox::Exceptions::DataExists(
                    'data' => __('IP address'),
                    'value' => $address);
    }

    if ($oldm eq any('dhcp', 'ppp')) {
        $self->DHCPCleanUp($name);
    } elsif ($oldm eq 'static') {
        $self->_routersReachableIfChange($name, $address, $netmask);
    } elsif ($oldm eq 'bridged') {
        $self->BridgedCleanUp($name);
    }


    # Calling observers
    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ( defined ( $ext ) ){
      # External attribute is not set by ebox-netcfg-import script
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

    $self->set_bool("interfaces/$name/external", $ext);
    $self->set_string("interfaces/$name/method", 'static');
    $self->set_string("interfaces/$name/address", $address);
    $self->set_string("interfaces/$name/netmask", $netmask);
    $self->set_bool("interfaces/$name/changed", 'true');

    if ($oldm ne 'static') {
        $self->_notifyChangedIface(
            name => $name,
            oldMethod => $oldm,
            newMethod => 'static',
            action => 'postchange'
        );
    }
    #logAdminDeferred('network',"set_iface_static","iface=$name,external=$ext,address=$address,netmask=$netmask");
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
#   method is changed or it should be forced
#
sub setIfacePPP # (interface, ppp_user, ppp_pass, external, force)
{
    my ($self, $name, $ppp_user, $ppp_pass, $ext, $force) = @_;

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
    }


    # Calling observers
    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::NetworkObserver')};

    if ( defined ( $ext ) ){
      # External attribute is not set by ebox-netcfg-import script
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

    $self->set_bool("interfaces/$name/external", $ext);
    $self->set_string("interfaces/$name/method", 'ppp');
    $self->set_string("interfaces/$name/ppp_user", $ppp_user);
    $self->set_string("interfaces/$name/ppp_pass", $ppp_pass);
    $self->set_bool("interfaces/$name/changed", 'true');

    if ($oldm ne 'ppp') {
            $self->_notifyChangedIface(
                name => $name,
                oldMethod => $oldm,
                newMethod => 'ppp',
                action => 'postchange'
            );
    }

    #logAdminDeferred('network',"set_iface_ppp","iface=$name,external=$ext,address=$address,netmask=$netmask");
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

    $self->unset("interfaces/$name/address");
    $self->unset("interfaces/$name/netmask");
    $self->set_string("interfaces/$name/method", 'trunk');
    $self->set_bool("interfaces/$name/changed", 'true');

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

    # new bridge
    if ( $bridge < 0 ) {
        my @bridges = @{$self->bridges()};
        my $last = int(pop(@bridges));
        $bridge = $last+1;
        $self->_createBridge($bridge);
    }

    $self->set_bool("interfaces/$name/external", $ext);
    $self->unset("interfaces/$name/address");
    $self->unset("interfaces/$name/netmask");
    $self->set_string("interfaces/$name/method", 'bridged');
    $self->set_bool("interfaces/$name/changed", 'true');
    $self->set_string("interfaces/$name/bridge_id", $bridge);

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

    if ($self->dir_exists("vlans/$id")) {
        throw EBox::Exceptions::DataExists('data' => 'vlan',
                          'value' => "$id");
    }

    if ($self->ifaceMethod($iface) ne 'trunk') {
        throw EBox::Exceptions::External(__('Network interfaces need '.
            'to be in trunk mode before adding vlans to them.'));
    }

    $self->set_int("vlans/$id/id", $id);
    $self->set_string("vlans/$id/name", $name);
    $self->set_string("vlans/$id/interface", $iface);
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
    $self->dir_exists("vlans/$id") or return;
    $self->unsetIface("vlan$id", $force);
    $self->delete_dir("vlans/$id");
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
    my $self = shift;
    return $self->all_dirs_base('vlans');
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
    return $self->dir_exists("vlans/$vlan");
}


#
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
sub ifaceVlans # (iface)
{
    my ($self, $name) = @_;
    my @array = ();
    my $vlans = $self->vlans;
    defined($vlans) or return \@array;
    foreach my $vlan (@{$vlans}) {
        defined($vlan) or next;
        if ($self->get_string("vlans/$vlan/interface") eq $name) {
            push(@array, $self->hash_from_dir("vlans/$vlan"));
        }
    }
    return \@array;
}

sub vlan # (vlan)
{
    my ($self, $vlan) = @_;
    defined($vlan) or return undef;
    if ($vlan =~ /^vlan/) {
        $vlan =~ s/^vlan//;
    }
    if ($vlan =~ /:/) {
        $vlan =~ s/:.*$//;
    }
    $self->dir_exists("vlans/$vlan") or return undef;
    return $self->hash_from_dir("vlans/$vlan");
}

# Method: createBridge
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

    if ($self->dir_exists("interfaces/br$id")) {
        throw EBox::Exceptions::DataExists('data' => 'bridge',
                          'value' => "$id");
    }

    $self->setIfaceAlias("br$id", "br$id");
}

# Method: removeBridge
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
    for my $iface ( @{$self->all_dirs_base('interfaces')} ) {
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
    for my $iface ( @{$self->ifaces} ) {
        if ( $self->ifaceMethod($iface) eq 'bridged' ) {
            if ( $self->ifaceBridge($iface) eq $bridge ) {
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
#   interace is changed or it should be forced
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

    $self->unset("interfaces/$name/address");
    $self->unset("interfaces/$name/netmask");
    $self->set_string("interfaces/$name/method",'notset');
    $self->set_bool("interfaces/$name/changed", 'true');

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
        return $self->get_string("interfaces/$name/address");
    } elsif ($self->ifaceMethod($name) eq any('dhcp', 'ppp')) {
        return $self->DHCPAddress($name);
    } elsif ($self->ifaceMethod($name) eq 'bridged') {
        my $bridge = $self->ifaceBridge($name);
        return $self->ifaceAddress("br$bridge");
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
        return $self->get_string("interfaces/$name/ppp_user");
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
        return $self->get_string("interfaces/$name/ppp_pass");
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
        return $self->get_string("interfaces/$name/bridge_id");
    } else {
        return undef;
    }
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
        my $ppp_iface = $self->st_get_string("interfaces/$name/ppp_iface");
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
#
# Parameters:
#
#   name - interface name
#
#  Returns:
#
#   - For ppp interfaces: the associated Ethernet interface, if it is up
#   - For the rest: the unaltered name
#
sub etherIface # (name)
{
    my ($self, $name) = @_;

    for my $iface (@{$self->allIfaces()}) {
        if ($self->ifaceMethod($iface) eq 'ppp') {
            my $ppp_iface = $self->st_get_string("interfaces/$iface/ppp_iface");
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
sub ifaceNetmask # (interface)
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
        return $self->get_string("interfaces/$name/netmask");
    } elsif ($self->ifaceMethod($name) eq any('dhcp', 'ppp')) {
        return $self->DHCPNetmask($name);
    } elsif ($self->ifaceMethod($name) eq 'bridged') {
        my $bridge = $self->ifaceBridge($name);
        return $self->ifaceNetmask("br$bridge");
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

    my $resolverModel = $self->model('DNSResolver');
    my $ids = $resolverModel->ids();
    my @array = map { $resolverModel->row($_)->valueByName('nameserver') } @{$ids};
    return \@array;
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

# Method: setNameservers
#
#   Set a set of name server resolvers
#
# Parameters:
#
#       array - a list of IP addresses which are the name server
#       resolvers
#
sub setNameservers # (one, two)
{
    my ($self, @dns) = @_;

    my $nss = $self->nameservers();
    my $resolverModel = $self->model('DNSResolver');
    my $nNSS = scalar(@{$nss});
    for(my $idx = 0; $idx < @dns; $idx++) {
        my $newNS = $dns[$idx];
        if ( $idx <= $nNSS - 1) {
            # There is a nameserver
            $self->setNS($idx, $newNS);
        } else {
            # Add a new one
            $resolverModel->add(nameserver => $newNS);
        }
    }
}

# Method: setSearchDomain
#
#   Set the search domain
#
# Parameters:
#
#       domain - string with the domain name
#
sub setSearchDomain
{
    my ($self, $domain) = @_;

    my $model = $self->model('SearchDomain');
    my $row = $model->row();
    $row->elementByName('domain')->setValue($domain);
    $row->storeElementByName('domain');
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
sub _hasChanged # (interface)
{
    my ($self, $iface) = @_;
    my $real = $iface;
    if ($self->vifaceExists($iface)) {
        ($real) = $self->_viface2array($iface);
    }
    if ( defined($self->dir_exists("interfaces/$real")) ){
        return $self->get_bool("interfaces/$real/changed");
    } else {
        return 1; # deleted => has changed
    }
}

#returns true if the interface is empty (ready to be removed)
sub _isEmpty # (interface)
{
    my ($self, $ifc) = @_;
    if ($self->vifaceExists($ifc)) {
        my ($real, $vir) = $self->_viface2array($ifc);
        return (! defined($self->get_string(
                "interfaces/$real/virtual/$vir/address")));
    } else {
        return (! defined($self->get_string("interfaces/$ifc/method")));
    }
}

sub _removeIface # (interface)
{
    my ($self, $iface) = @_;
    if ($self->vifaceExists($iface)) {
        my ($real, $virtual) = $self->_viface2array($iface);
        return $self->delete_dir("interfaces/$real/virtual/$virtual");
    } else {
        return $self->delete_dir("interfaces/$iface");
    }
}

sub _unsetChanged # (interface)
{
    my ($self, $iface) = @_;
    if ($self->vifaceExists($iface)) {
        return;
    } else {
        return $self->unset("interfaces/$iface/changed");
    }
}

sub _setChanged # (interface)
{
    my ($self, $iface) = @_;
    if ($self->vifaceExists($iface)) {
        my ($real, $vir) = $self->_viface2array($iface);
        $self->set_bool("interfaces/$real/changed",'true');
    } else {
        $self->set_bool("interfaces/$iface/changed", 'true');
    }
}

# Generate the '/etc/resolv.conf' configuration file and modify
# the '/etc/dhcp3/dhclient.conf' to request nameservers only
# if there are no manually configured ones.
sub _generateDNSConfig
{
    my ($self) = @_;

    my $nameservers = $self->nameservers();
    my $request_nameservers = scalar (@{$nameservers}) == 0;

    $self->writeConfFile(RESOLV_FILE,
                         'network/resolv.conf.mas',
                         [ searchDomain => $self->searchdomain(),
                           nameservers  => $nameservers ]);

    $self->writeConfFile(DHCLIENTCONF_FILE,
                         'network/dhclient.conf.mas',
                         [ request_nameservers => $request_nameservers ]);
}

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

    $self->writeConfFile(ENV_PROXY_FILE,
                        'network/zentyal-proxy.sh.mas',
                        [ proxyConf => $proxyConf ],
                        { 'uid' => 0, 'gid' => 0, mode => '755' });
    $self->writeConfFile(APT_PROXY_FILE,
                        'network/99proxy.conf.mas',
                        [ proxyConf => $proxyConf ]);
}

#
sub isDDNSEnabled
{
  my $self = shift;
  my $ddnsModel = $self->model('DynDNS');
  my $row = $ddnsModel->row();
  return $row->valueByName('enableDDNS');
}

# Generate the '/etc/ddclient.conf' configuration file for DynDNS
sub _generateDDClient
{
    my ($self) = @_;

    my $enabled = $self->isDDNSEnabled();

    $self->writeConfFile(DEFAULT_DDCLIENT_FILE,
                         'network/ddclient.mas',
                         [ enabled => $enabled ]);

    if ($enabled) {
        my $ddnsModel = $self->model('DynDNS');
        my $row = $ddnsModel->row();
        $self->writeConfFile(DDCLIENT_FILE,
                             'network/ddclient.conf.mas',
                             [ service  => $row->valueByName('service'),
                               login => $row->valueByName('username'),
                               password => $row->valueByName('password'),
                               hostname => $row->valueByName('hostname') ]);
    }
}

sub _generatePPPConfig
{
    my ($self) = @_;

    my $pppSecrets = {};

    my $usepeerdns = scalar (@{$self->nameservers()}) == 0;

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

    $self->writeConfFile(CHAP_SECRETS_FILE,
                         'network/chap-secrets.mas',
                         [ passwords  => $pppSecrets ],
                         { mode => '0600' }
                        );

    $self->writeConfFile(PAP_SECRETS_FILE,
                         'network/pap-secrets.mas',
                         [ passwords  => $pppSecrets ],
                         { mode => '0600' }
                        );
}

sub generateInterfaces
{
    my ($self) = @_;

    my $file = INTERFACES_FILE;
    my $tmpfile = EBox::Config::tmp . '/interfaces';
    my $iflist = $self->allIfacesWithRemoved();

    my $manager = new EBox::ServiceManager();
    if ($manager->skipModification('network', $file)) {
        EBox::info("Skipping modification of $file");
        return;
    }

    #writing /etc/network/interfaces
    open(IFACES, ">", $tmpfile) or
        throw EBox::Exceptions::Internal("Could not write on $file");
    print IFACES "auto lo";
    foreach (@{$iflist}) {
        if (($self->ifaceMethod($_) eq 'static') or
            ($self->ifaceMethod($_) eq 'dhcp')) {
            print IFACES " " . $_;
        }
    }
    my ($gwIface, $gwIP) = $self->_defaultGwAndIface();
    print IFACES "\n\niface lo inet loopback\n";
    foreach my $ifname (@{$iflist}) {
        my $method = $self->ifaceMethod($ifname);
        my $bridgedVlan = $method eq 'bridged' and $ifname =~ /^vlan/;

        if (($method ne 'static') and
            ($method ne 'ppp') and
            ($method ne 'dhcp') and
            (not $bridgedVlan)) {
            next;
        }

        my $name = $ifname;
        if ($method eq 'ppp') {
            $name = "ebox-ppp-$ifname";
            print IFACES "auto $name\n";
        }

        if ($bridgedVlan) {
            $method = 'manual';
        }

        print IFACES "iface $name inet $method\n";

        if ($ifname =~ /^vlan/) {
            my $vlan = $self->vlan($ifname);
            print IFACES "vlan-raw-device $vlan->{interface}\n";
        }

        if ($method eq 'static') {
            print IFACES "\taddress ". $self->ifaceAddress($ifname).
                "\n";
            print IFACES "\tnetmask ". $self->ifaceNetmask($ifname).
                "\n";
            print IFACES "\tbroadcast " .
                $self->ifaceBroadcast($ifname) . "\n";
            if (defined($gwIface) and defined($gwIP) and ($gwIface eq $ifname))
            {
                print IFACES "\tgateway $gwIP\n";
            }
        } elsif ($method eq 'ppp') {
            print IFACES "\tpre-up /sbin/ifconfig $ifname up\n";
            print IFACES "\tpost-down /sbin/ifconfig $ifname down\n";
            print IFACES "\tprovider $name\n";
        }

        if ( $self->ifaceIsBridge($ifname) ) {
            print IFACES "\tbridge_ports";
            my $ifaces = $self->bridgeIfaces($ifname);
            foreach my $bridged ( @{$ifaces} ) {
                print IFACES " $bridged";
            }
            print IFACES "\n";

            print IFACES "\tbridge_stp off\n";
            print IFACES "\tbridge_waitport 5\n";
        }

        print IFACES "\n";
    }
    close(IFACES);

    root("cp $tmpfile $file");
    $manager->updateFileDigest('network', $file);
}

# Generate the static routes from routes() with "ip" command
sub _generateRoutes
{
    my ($self) = @_;
    # Delete those routes which are not useful anymore
    my @routes = @{$self->routes()};
    $self->_removeRoutes(\@routes);
    (@routes) or return;
    foreach (@routes) {
        my $net = $_->{network};
        my $router = $_->{gateway};
#         if (route_is_up($net, $router)) {
#             root("/sbin/ip route del $net via $router");
#         }
        root("/sbin/ip route add $net via $router table main || true");
    }

}

# Write cron file
sub _writeCronFile
{
    my ($self) = @_;

    unless ( $self->entry_exists('rand_mins') ) {
        # Set the random times when scripts must be run
        my @randMins = map { int(rand(60)) } 0 .. 10;
        $self->set_list('rand_mins', 'int', \@randMins);
    }

    my $mins = $self->get_list('rand_mins');

    my @tmplParams = ( (mins => $mins) );

    EBox::Module::Base::writeConfFileNoCheck(
        CRON_FILE,
        'network/ebox-network.cron.mas',
        \@tmplParams);

}

# Remove those static routes which user has marked as deleted
sub _removeRoutes
{
    my ($self, $storedRoutes) = @_;

    # Delete those routes which are not defined by Zentyal
    my @currentRoutes = list_routes('viaGateway');
    foreach my $currentRoute (@currentRoutes) {
        my $found = 0;
        foreach my $storedRoute (@{$storedRoutes}) {
            if ($currentRoute->{network} eq $storedRoute->{network}
                and $currentRoute->{router} eq $storedRoute->{gateway}) {
                $found = 1;
                last;
            }
        }
        # If not found, delete it
        unless ( $found ) {
            if ( route_is_up($currentRoute->{network}, $currentRoute->{router}) ) {
                root('/sbin/ip route del ' . $currentRoute->{network}
                     . ' via ' . $currentRoute->{router});
            }
        }
    }

    # Return here since we are not able to modify our data
    return if ($self->isReadOnly());
    my $deletedModel = $self->model('DeletedStaticRoute');
    foreach my $id (@{$deletedModel->ids()}) {
        my $row = $deletedModel->row($id);
        my $network = $row->elementByName('network')->printableValue();
        my $gateway = $row->elementByName('gateway')->printableValue();
        if ( route_is_up($network, $gateway)) {
            root("/sbin/ip route del $network via $gateway");
        }
        # Perform deletion in two phases to let Zentyal perform sync correctly
        if ( $row->elementByName('deleted')->value() ) {
            $deletedModel->removeRow($row->id(), 1);
        } else {
            $row->elementByName('deleted')->setValue(1);
            $row->storeElementByName('deleted');
        }
    }

}

# disable reverse path for gateway interfaces
sub _disableReversePath
{
    my ($self) = @_;

    my $routers = $self->gatewaysWithMac();

    my @cmds;
    push (@cmds, '/sbin/sysctl -q -w net.ipv4.conf.all.rp_filter=0');
    for my $router ( reverse @{$routers} ) {
        my $iface = $router->{'interface'};
        $iface = $self->realIface($iface);
        push (@cmds, "/sbin/sysctl -q -w net.ipv4.conf.$iface.rp_filter=0");
    }

    EBox::Sudo::root(@cmds);
}



sub _multigwRoutes
{
    my ($self) = @_;

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

    push(@cmds, EBox::Config::share() . "ebox-network/ebox-flush-fwmarks");
    my %interfaces;

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

        my $if = new IO::Interface::Simple($iface);
        next unless $if->address;

        my $net = $self->ifaceNetwork($iface);
        my $address = $self->ifaceAddress($iface);
        my $route = "via $ip dev $iface src $address";
        if ($method eq 'ppp') {
            $route = "dev $iface";
        }

        push(@cmds, "/sbin/ip route flush table $table");
        push(@cmds, "/sbin/ip rule add fwmark $mark/0xFF table $table");
        push(@cmds, "/sbin/ip rule add from $ip table $table");
        push(@cmds, "/sbin/ip route add default $route table $table");
    }

    push(@cmds,'/sbin/ip rule add table main');

    # Not in @cmds array because of possible CONNMARK exception
    try {
        my @fcmds;
        push(@fcmds, '/sbin/iptables -t mangle -F');
        push(@fcmds, '/sbin/iptables -t mangle -X');
        push(@fcmds, '/sbin/iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark');
        push(@fcmds, '/sbin/iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark');
        EBox::Sudo::root(@fcmds);
    } otherwise {};

    my $defaultRouterMark;
    foreach my $router (@{$routers}) {

        # Skip gateways with unassigned address
        next unless $router->{'ip'};

        if ($router->{'default'}) {
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


        # mark in postrouting (only if more than one output iface)
        if ( scalar keys %interfaces > 1 ) {
            push(@cmds, '/sbin/iptables -t mangle -A POSTROUTING '
                        . "-o $iface -j MARK --set-mark $mark");
        }
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
        push(@fcmds, '/sbin/iptables -t mangle -A POSTROUTING -j CONNMARK --save-mark' .
                     ' --nfmask 0xff'); # routers mark only
        EBox::Sudo::root(@fcmds);
    } otherwise {};
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
sub _preSetConf
{
    my $self = shift;

    my %opts = @_;
    my $file = INTERFACES_FILE;
    my $restart = delete $opts{restart};

    try {
        root("/sbin/modprobe 8021q");
    } catch EBox::Exceptions::Internal with {};
    try {
        root("/sbin/vconfig set_name_type VLAN_PLUS_VID_NO_PAD");
    } catch EBox::Exceptions::Internal with {};

    # Bring down changed interfaces
    my $iflist = $self->allIfacesWithRemoved();
    foreach my $if (@{$iflist}) {
        if ($self->_hasChanged($if)) {
            try {
                if ($self->ifaceExists($if)) {
                    my $ifname = $if;
                    if ($self->ifaceMethod($if) eq 'ppp') {
                        $ifname = "ebox-ppp-$if";
                    } else {
                        root("/sbin/ip address flush label $if");
                        root("/sbin/ip address flush label $if:*");
                    }
                    root("/sbin/ifdown --force -i $file $ifname");
                }
            } catch EBox::Exceptions::Internal with {};
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
}

sub _daemons
{
    return [
        {
            'name' => 'ddclient',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/ddclient.pid'],
            'precondition' => \&isDDNSEnabled
        }
    ];
}

sub _setConf
{
    my ($self) = @_;

    $self->generateInterfaces();
    $self->_generatePPPConfig();
    $self->_generateDDClient();
    $self->_generateDNSConfig();
    $self->_generateProxyConfig();
    $self->_writeCronFile();
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

    my @ifups = ();
    my $iflist = $self->allIfacesWithRemoved();
    foreach my $iface (@{$iflist}) {
        if ($self->_hasChanged($iface) or $restart) {
            if ($self->ifaceMethod($iface) eq 'ppp') {
                $iface = "ebox-ppp-$iface";
            }
            push(@ifups, $iface);
        }
    }

    open(my $fd, '>', IFUP_LOCK_FILE); close($fd);
    foreach my $iface (@ifups) {
        root(EBox::Config::pkgdata() . "ebox-unblock-exec /sbin/ifup --force -i $file $iface");
        unless ($self->isReadOnly()) {
            $self->_unsetChanged($iface);
        }
    }
    unlink (IFUP_LOCK_FILE);

    EBox::Sudo::silentRoot("/sbin/ip route del default table default");
    EBox::Sudo::silentRoot("/sbin/ip route del default");

    my $cmd = $self->_multipathCommand();
    if ($cmd) {
        try {
            root($cmd);
        } catch EBox::Exceptions::Internal with {
            throw EBox::Exceptions::External("An error happened ".
                    "trying to set the default gateway. Make sure the ".
                    "gateway you specified is reachable.");
        };
    }

    $self->_generateRoutes();
    $self->_disableReversePath();
    $self->_multigwRoutes();
    $self->_cleanupVlanIfaces();

    EBox::Sudo::root('/sbin/ip route flush cache');

    $self->SUPER::_enforceServiceState();

    # XXX uncomment when DynLoader bug with locales is fixed
#   # regenerate config for the bit rate report
#   EBox::Network::Report::ByteRate->_regenConfig();
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
    my $self = shift;

    # XXX uncomment when DynLoader bug with locales is fixed
    # EBox::Network::Report::ByteRate->stopService();

    return unless ($self->configured());

    my $file = INTERFACES_FILE;
    my $iflist = $self->allIfaces();
    foreach my $if (@{$iflist}) {
        try {
            my $ifname = $if;
            if ($self->ifaceMethod($if) eq 'ppp') {
                $ifname = "ebox-ppp-$if";
            } else {
                root("/sbin/ip address flush label $if");
                root("/sbin/ip address flush label $if:*");
            }
            root("/sbin/ifdown --force -i $file $ifname");
        } catch EBox::Exceptions::Internal with {};
    }

# XXX uncomment when DynLoader bug with locales is fixed
#   EBox::Network::Report::ByteRate->stopService();

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
               'configured gateways to become unreachable. ' .
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
#       Boolean - if name is not present, indicate whether the given
#       gateway is reachable or not
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

            return 1;
        }
    }

    if ($name) {
        if (not $reachableByNoStaticIface) {
        throw EBox::Exceptions::External(
                __x("Gateway {gw} not reachable", gw => $gw));
        } else {
        throw EBox::Exceptions::External(
                __x("Gateway {gw} must be reachable by a static interface. "
                    . "Currently it is reachable by {iface} which is not static",
                    gw => $gw, iface => $reachableByNoStaticIface) );
        }

    } else {
        return undef;
    }
}

sub _alreadyInRoute # (ip, mask)
{
    my ( $self, $ip, $mask) = @_;
    my @routes = $self->all_dirs("routes");
    foreach (@routes) {
        my $rip = $self->get_string("$_/ip");
        my $rmask = $self->get_int("$_/mask");
        my $oip = new Net::IP("$ip/$mask");
        my $orip = new Net::IP("$rip/$rmask");
        if($oip->overlaps($orip)==$IP_IDENTICAL){
            return 1;
        }
    }
    return undef;
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
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    checkIPNetmask($ip, $mask,  __("IP address"), __('Netmask'));
    $self->st_set_string("dhcp/$iface/address", $ip);
    $self->st_set_string("dhcp/$iface/mask", $mask);
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

    $self->st_set_string("dhcp/$iface/gateway", $gw);
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
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    $self->st_set_string("interfaces/$iface/ppp_iface", $ppp_iface);

    checkIP($ppp_addr, __("IP address"));
    $self->st_set_string("interfaces/$iface/ppp_addr", $ppp_addr);
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
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);

    $self->st_delete_dir("dhcp/$iface");
    $self->st_unset("interfaces/$iface/ppp_iface");
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

    $self->unset("interfaces/$iface/bridge_id");
    $self->_removeEmptyBridges();
}

# Method: selectedDefaultGateway
#
#   Returns the selected default gateway
#
sub selectedDefaultGateway
{
    my ($self) = @_;

    return $self->st_get_string('default/gateway');
}

# Method: storeSelectedDefaultGateway
#
#   Store the selected default gateway
#
# Parameters:
#
#   gateway - gateway id
#
sub storeSelectedDefaultGateway # (gateway
{
    my ($self, $gateway) = @_;

    return $self->st_set_string('default/gateway', $gateway);
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
sub DHCPGateway
{
    my ($self, $iface) = @_;

    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);

    return $self->st_get_string("dhcp/$iface/gateway");
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
sub DHCPAddress # (interface)
{
    my ($self, $iface) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    return $self->st_get_string("dhcp/$iface/address");
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
sub DHCPNetmask # (interface)
{
    my ($self, $iface) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    return $self->st_get_string("dhcp/$iface/mask");
}

# Method: DHCPNetmask
#
#   Sets the nameserver obtained from a DHCP configured interface
#
# Parameters:
#
#   interface - interface name
#   nameservers - array ref holding the nameservers
#
# Returns:
#
#   string - network mask
sub setDHCPNameservers # (interface, \@nameservers)
{
    my ($self, $iface, $servers) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    foreach (@{$servers}) {
        checkIP($_, __("IP address"));
    }
    $self->st_set_list("dhcp/$iface/nameservers", "string", $servers);
}

# Method: DHCPNameservers
#
#   Sets the nameservers obtained from a DHCP configured interface
#
# Parameters:
#
#   interface - interface name
#
# Returns:
#
#   array ref - holding the nameservers
sub DHCPNameservers # (interface)
{
    my ($self, $iface) = @_;
    $self->ifaceExists($iface) or
        throw EBox::Exceptions::DataNotFound(data => __('Interface'),
                             value => $iface);
    return $self->st_get_list("dhcp/$iface/nameservers");
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

sub interfacesWidget
{
    my ($self, $widget) = @_;
    my $ifaces = $self->ifacesWithRemoved;
    my $linkstatus = {};
    root("/sbin/mii-tool > " . EBox::Config::tmp . "linkstatus || true");
    if (open(LINKF, EBox::Config::tmp . "linkstatus")) {
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
    foreach my $iface (@{$ifaces}) {
        iface_exists($iface) or next;
        my $upStr = __("down");
        my $section = new EBox::Dashboard::Section($self->ifaceAlias($iface),
            $self->ifaceAlias($iface));
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

# XXX uncomment when DynLoader bug with locales is fixed
#         my $monSummary = EBox::Network::Report::ByteRate->summary();
#         if ( defined($monSummary) ) {
#             $composite->add($monSummary);
#         }
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
                                        'text' => __('Network'),
                                        'separator' => 'Core',
                                        'order' => 40);

    $folder->add(new EBox::Menu::Item('url' => 'Network/Ifaces',
                      'text' => __('Interfaces')));
    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/DNS',
                      'text' => 'DNS'));
    $folder->add(new EBox::Menu::Item('url' => 'Network/View/DynDNS',
                      'text' => 'DynDNS'));
    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/Gateway',
                      'text' => __('Gateways')));
    $folder->add(new EBox::Menu::Item('url' => 'Network/View/StaticRoute',
                      'text' => __('Static Routes')));
    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/MultiGw',
                      'text' => __('Balance Traffic')));
    $folder->add(new EBox::Menu::Item('url' => 'Network/Composite/WANFailover',
                      'text' => __('WAN Failover')));
    $folder->add(new EBox::Menu::Item('url' => 'Network/Diag',
                      'text' => __('Diagnostic Tools')));

# XXX uncomment when DynLoader bug with locales is fixed
#   $folder->add(new EBox::Menu::Item('url' =>
#                       'Network/Composite/ByteRate',
#                     'text' => __('Traffic rate monitor')));



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

# Method: setBalanceTraffic
#
#   Set the traffic balancing
#
# Parameters:
#
#   balance - bool to enable/disable
#
sub setBalanceTraffic
{
    my ($self, $balance) = @_;

    unless ($balance ne $self->balanceTraffic) {
        return;
    }

    $self->set_bool('balanceTraffic', $balance);

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

    my $timeout = 60;
    my $locked = 0;

    while ((not $locked) and ($timeout > 0)) {
        try {
            EBox::Util::Lock::lock('network');
            $locked = 1;
        } catch EBox::Exceptions::Lock with {
            sleep 5;
            $timeout -= 5;
        };
    }

    unless ($locked) {
        EBox::error('Network module has been locked for 60 seconds');
        return;
    }

    $self->saveConfig();
    my @commands;
    push (@commands, '/sbin/ip route del table default');
    my $cmd = $self->_multipathCommand();
    if ($cmd) {
        push (@commands, $cmd);
    }

    # Silently delete duplicated MTU rules for PPPoE interfaces and
    # add them to the commands array
    push(@commands, @{$self->_pppoeRules(1)});

    try {
        EBox::Sudo::root(@commands);
    } otherwise {
        EBox::error('Something bad happened reseting default gateways');
    };
    $self->_multigwRoutes();

    EBox::Sudo::root('/sbin/ip route flush cache');

    $global->modRestarted('network');

    EBox::Util::Lock::unlock('network');
}

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
        my $ev = EBox::Global->getInstance()->modInstance('events');
        if ($ev->isEnabledWatcher('EBox::Event::Watcher::Gateways')->value()) {
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

        my $iface = $gw->{'interface'};
        my $method = $self->ifaceMethod($iface);

        $iface = $self->realIface($iface);
        my $if = new IO::Interface::Simple($iface);
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

# Group: report-related files

# Method: gatherReportInfo
#
#     Gather the report information
#
# Parameters:
#
#     downloadRate - Int the download rate for a test in bits per second
#
sub gatherReportInfo
{
    my ($self, $downloadRate) = @_;

    my $dbh = EBox::DBEngineFactory::DBEngine();

    my @time = gmtime();
    my ($year, $month, $day) = ($time[5] + 1900, $time[4] + 1, $time[3]);
    my ($hour, $min, $sec) = ($time[2], $time[1], $time[0]);
    my $timestamp = "$year-$month-$day $hour:$min:$sec";

    $dbh->unbufferedInsert('network_bw_test',
                           { timestamp => $timestamp,
                             bps_down  => $downloadRate });

}

# Method: consolidateReportInfo
#
#    Overrides this to consolidate test done daily in a single value
#
# Overrides:
#
#    <EBox::Module::Base::consolidateReportInfo>
#
sub consolidateReportInfo
{
    my ($self) = @_;

    # Firstly call the SUPER to follow standard framework
    $self->SUPER::consolidateReportInfo();

    my $dbh = EBox::DBEngineFactory::DBEngine();

    my $date = $self->_consolidateReportStartDate($dbh,
                                                  'network_bw_test_report',
                                                  { 'from' => 'network_bw_test' });

    return unless (defined($date));

    my @time = localtime($date);
    my ($year, $month, $day, $hour) =
      ($time[5]+1900, $time[4]+1, $time[3], $time[2] . ':' . $time[1] . ':' . $time[0]);

    my $beginTime  = "$year-$month-$day $hour";
    my $beginMonth = "$year-$month-01 00:00:00";

    my $query = qq{INSERT INTO network_bw_test_report
                   SELECT DATE(timestamp) AS date,
                          MAX(bps_down) AS maximum_down,
                          MIN(bps_down) AS minimum_down,
                          AVG(bps_down) AS mean_down
                   FROM network_bw_test
                   WHERE timestamp >= '$beginTime'
                         AND timestamp < DATE '$beginMonth' + INTERVAL '1 MONTH'
                   GROUP BY date};
    $dbh->query($query);

    # Store the consolidation time
    my $gmConsolidationStartTime = gmtime(time());
    $dbh->update('report_consolidation',
                 { 'last_date' => "'$gmConsolidationStartTime'" },
                 [ "report_table = 'network_bw_test_report'" ]);

}

# Method: report
#
# Overrides:
#
#    <EBox::Module::Base::report>
#
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    $report->{'bandwidth_speed'} = $self->runMonthlyQuery($beg, $end, {
        'select' => 'MAX(maximum_down) AS maximum_down, '
                    . 'MIN(minimum_down) AS minimum_down, '
                    . 'CAST(AVG(mean_down) AS bigint) AS mean_down',
        'from'   => 'network_bw_test_report',
        'group'  => 'date',
        });

    return $report;

}

# Method: averageBWDay
#
#    Get the average download time for a day
#
# Parameters:
#
#    day - String the day in "year-month-day" format
#
# Returns:
#
#    Int - the average download bps for that day
#
#    undef - if there is no data
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if the day is not correctly
#    formatted
#
sub averageBWDay
{
    my ($self, $day) = @_;

    unless ( $day =~ m:[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}:g ) {
        throw EBox::Exceptions::Internal("$day must follow this format: yyyy-mm-dd");
    }

    my $dbh = EBox::DBEngineFactory::DBEngine();

    my $res = $dbh->query_hash({
        'select' => 'DISTINCT mean_down',
        'from'   => 'network_bw_test_report',
        'where'  => "date = '$day'"});

    if ( @{$res} ) {
        return $res->[0]->{'mean_down'};
    } else {
        return undef;
    }

}

1;
