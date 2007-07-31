# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

use base 'EBox::GConfModule';

use constant DHCLIENT_CONF_FILE => '/etc/dhcp3/dhclient.conf';
# Interfaces list which will be ignored
use constant ALLIFACES => qw(sit tun tap lo irda eth wlan vlan);
use constant IGNOREIFACES => qw(sit tun tap lo irda);
use constant IFNAMSIZ => 16; #Max length name for interfaces

use Net::IP;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);
use EBox::Config;
use EBox::Order;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use Error qw(:try);
use EBox::Summary::Module;
use EBox::Summary::Value;
use EBox::Summary::Section;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo qw( :all );
use EBox::Gettext;
#use EBox::LogAdmin qw( :all );
use File::Basename;
use EBox::Network::Model::GatewayDataTable;
use EBox::Network::Model::MultiGwRulesDataTable;

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'network',
					title => __('Network'),
					domain => 'ebox-network',
					@_);
	$self->{'actions'} = {};
	$self->{'gatewayModel'} = new EBox::Network::Model::GatewayDataTable(
					'gconfmodule' => $self,
					'directory' => 'gatewaytable',
					);
	
	$self->{'multigwrulesModel'} = 
				new EBox::Network::Model::MultiGwRulesDataTable(
					'gconfmodule' => $self,
					'directory' => 'multigwrulestable',
					);
	bless($self, $class);
	
	return $self;
}

# Method: IPAddressExists
#
# 	Returns true if the given IP address belongs to a statically configured
#	network interface 
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
# 	Returns  a list of all external interfaces 
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
# 	Returns  a list of all internal interfaces 
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
# 	Checks if a given interface exists
#
# Parameters:
#
# 	interface - the name of a network interface
# 
# Returns:
#
# 	boolean - true, if the interface exists, otherwise false
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
# 	Checks if a given iface exists and is external
#
# Parameters:
#
# 	interface - the name of a network interface
#
# Returns:
#
# 	boolean - true, if the interface is external, otherwise false
sub ifaceIsExternal # (interface)
{
	my ($self, $iface) = @_;
	defined($iface) or return undef;

	if ($self->vifaceExists($iface)) {
		my @aux = $self->_viface2array($iface);
		$iface = $aux[0];
	}
	return  $self->get_bool("interfaces/$iface/external");
}

# Method: ifaceOnConfig
#
# 	Checks if a given iface is configured 
#
# Parameters:
#
# 	interface - the name of a network interface
# 
# Returns:
#
# 	boolean - true, if the interface is configured, otherwise false
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
	foreach my $ignore (IGNOREIFACES) {
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
#  	Returns the name of all real interfaces, including vlan interfaces
#
# Returns:
#
#  	array ref - holding the names
sub ifaces
{
	my $self = shift;
	return $self->_vlanIfaceFilter($self->_ifaces());
}

# Method: ifacesWithRemoved
#
#  	Returns the name of all real interfaces, including 
#	vlan interfaces (both existing ones and those that are going to be
#	removed when the configuration is saved)
# Returns:
#
#  	array ref - holding the names
sub ifacesWithRemoved
{
	my $self = shift;
	return $self->_vlanIfaceFilterWithRemoved($self->_ifaces());
}

# Method: ifaceAddresses
#
# 	Returns an array of hashes with "address" and "netmask" fields, the
# 	array may be empty (i.e. for a dhcp interface that did not get an
# 	address)
#	
# Parameters:
#
# 	iface - the name of a interface
#
# Returns:
#
#	an array ref - holding hashees with keys 'address' and 'netmask'
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
	} elsif ($self->ifaceMethod($iface) eq 'dhcp') {
		my $addr = $self->DHCPAddress($iface);
		my $mask = $self->DHCPNetmask($iface);
		if ($addr && ($addr ne '')) {
			push(@array, {address=>$addr, netmask=>$mask});
		}
	}
	return \@array;
}

# Method: vifacesConf 
#
# 	Gathers virtual interfaces from a real interface with their conf
# 	arguments
#	
# Parameters:
#
# 	iface - the name of a interface
#
# Returns:
#	
#	an array ref - holding hashes with keys 'address' and 'netmask'
#	'name'
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

# Method: vifacesNames
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
#      	Returns all the names for all the interfaces, both real and virtual.
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

# Method: allIfacesWithRemoved 
# 
# 	Return  the names of all (real and virtual) interfaces. This
# 	method is similar to the ifacesWithRemoved method, it includes in the
# 	results vlan interfaces which are going to be removed when the
# 	configuration is saved.
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
# 	- the name of the real network interface
# 	- the name of the virtual interface
# returns
# 	- true if exists
# 	- false if not
# throws
# 	- Internal
# 		- If real interface is not configured as static
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
# 	- the composed virtual iface name
# returns 
# 	- an array with the split name
sub _viface2array # (interface)
{
	my ($self, $name) = @_;
	my @array = $name =~ /(.*):(.*)/;
	return @array;
}

# Method: vifaceExists 
#
# 	Checks if a given virtual interface exists
#
# Parameters:
#
# 	interface - the name of  virtual interface composed by 
#	realinterface:virtualinterface
# 
# Returns:
#
# 	boolean - true, if the interface exists, otherwise false

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
# 	Configure a virtual  interface with ip and netmask
# 	arguments
#
# Parameters:
#
# 	iface - the name of a real network interface
#	viface - the name of the virtual interface
#	address - the IP address for the virtual interface
#	netmask - the netmask
#
# Exceptions:
#
#  	DataExists - If interface already exists
#	Internal - If the real interface is not configured as static
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
		}
	}
	settextdomain('ebox');

	$self->set_string("interfaces/$iface/virtual/$viface/address",$address);
	$self->set_string("interfaces/$iface/virtual/$viface/netmask",$netmask);
	$self->set_bool("interfaces/$iface/changed", 'true');
}

# Method: removeViface 
#
# 	Removes a virtual interface	
#
# Parameters:
#
# 	iface - the name of a real network interface
#	viface - the name of the virtual interface
#
# Returns:
# 
# 	boolean - true if exists, otherwise false
#
# Exceptions:
#
#	Internal - If the real interface is not configured as static
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
#	Returns the configured address for a virutal interface
#
# Parameters:
# 
# 	interface - the composed name of a virtual interface
#
#  Returns:
#
#	If interface exists it returns its IP, otherwise it returns undef
#
#	string - IP if it exists
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
#	Returns the configured netmask for a virutal interface
#
# Parameters:
# 
# 	interface - the composed name of a virtual interface
#
#  Returns:
#
#	If interface exists it returns its netmask, otherwise it returns undef
#
#	string - IP if it exists
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
#	Sets the alias for a given interface
#
# Parameters:
#
# 	iface - the name of a network interface
# 	alias - the alias for the interface
#
sub setIfaceAlias # (iface, alias)
{
	my ($self, $iface, $alias) = @_;
	$self->set_string("interfaces/$iface/alias", $alias);
}

# Method: ifaceAlias
#
#	Returns the alias for a given interface
#
# Parameters:
#
# 	iface - the name of a network interface
#
# Returns:
#
# 	string - alias for the interface
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
#	Returns the configured method for a given interface
#
# Parameters:
#
# 	interface - the name of a network interface
#
# Returns:
#
# 	string - dhcp|static|notset|trunk
#			dhcp -> the interface is configured via dhcp
#			static -> the interface is configured with a static ip
#			notset -> the interface exists but has not been
#				  configured yet
#			trunk -> vlan aware interface
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
#	Configure an interface via DHCP
#
# Parameters: 
#
# 	interface - the name of a network interface
#	external - boolean to indicate if it's  a external interface
#	force - boolean to indicate if an exception should be raised when
#	method is changed or it should be forced 
#
sub setIfaceDHCP # (interface, external, force) 
{
	my ($self, $name, $ext, $force) = @_;
	$self->ifaceExists($name) or
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
						     value => $name);

	$self->_routersReachableIfChange($name);

	my $oldm = $self->ifaceMethod($name);

	if ($oldm eq 'trunk') {
		$self->_trunkIfaceIsUsed($name);
	}

	if ($oldm eq 'static') {
		$self->_checkStatic($name, $force);
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
	  	# Tell observers the method interface has changed
		foreach my $obs (@observers) {
			if ($obs->ifaceMethodChanged($name, $oldm, 'dhcp')) {
				if ($force) {
					$obs->freeIface($name);
				} else {
					throw EBox::Exceptions::DataInUse();
				}
			}
		}
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
}

# Method: setIfaceStatic
#
#	Configure with a static ip address 
#
# Parameters:
#
# 	interface - the name of a network interface
#	address - IPv4 address
#	netmask - network mask
#	external - boolean to indicate if it's an external interface
#	force - boolean to indicate if an exception should be raised when
#	method is changed or it should be forced
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

	$self->_routersReachableIfChange($name, $address, $netmask);

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
		foreach my $obs (@observers) {
			if ($obs->ifaceMethodChanged($name, $oldm, 'static')) {
				if ($force) {
					$obs->freeIface($name);
				} else {
					throw EBox::Exceptions::DataInUse();
				}
			}
		}
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

	#logAdminDeferred('network',"set_iface_static","iface=$name,external=$ext,address=$address,netmask=$netmask");
}

sub _checkStatic # (iface, force)
{
	my ($self, $iface, $force) = @_;

	my $global = EBox::Global->getInstance();
	my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};

	foreach my $vif (@{$self->vifaceNames($iface)}) {
		foreach my $mod (@mods) {
			my ($tmp, $viface) = $self->_viface2array($iface);
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

# Method: setIfaceTrunk
#
#	configures an interface in trunk mode, making it possible to create vlan
# 	interfaces on it.
#
# Parameters:
#
# 	interface - the name of a network interface
#	force - boolean to indicate if an exception should be raised when
#	method is changed or it should be forced
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

	if ($oldm eq 'static') {
		$self->_routersReachableIfChange($name);
		$self->_checkStatic($name, $force);
	}

	if ($oldm ne 'notset') {
		my $global = EBox::Global->getInstance();
		my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
		foreach my $mod (@mods) {
			if ($mod->ifaceMethodChanged($name, $oldm, 'notset')) {
				if ($force) {
					$mod->freeIface($name);
				} else {
					throw EBox::Exceptions::DataInUse();
				}
			}
		}
	}

	$self->unset("interfaces/$name/address");
	$self->unset("interfaces/$name/netmask");
	$self->set_string("interfaces/$name/method", 'trunk');
	$self->set_bool("interfaces/$name/changed", 'true');
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


# Method: createVlan
#
# 	creates an vlan on a trunk interface.
#
# Parameters: 
#
#	id - vlan identifier
#	name - name
# 	interface - the name of a network interface
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
# 	Removes a vlan	
#
# Parameters: 
#
#	id - vlan identifier
#
sub removeVlan # (id)
{
	my ($self, $id) = @_;
	checkVlanID($id, __('VLAN Id'));
	$self->dir_exists("vlans/$id") or return;
	$self->unsetIface("vlan$id");
	$self->delete_dir("vlans/$id");
}

# Method: vlans
#
#	Returns a reference to an array with all existing vlan ID's
#
# Returns:
#	
#	an array ref - holding the vlan ID's
sub vlans
{
	my $self = shift;
	return $self->all_dirs_base('vlans');
}

#
# Method: vlanExists
#
# 	Checks if a given vlan id exists
#
# Parameters: 
#
#	id - vlan identifier
#
#  Returns:
#
#	boolean - true if it exits, otherwise false
sub vlanExists # (vlanID)
{
	my ($self, $vlan) = @_;
	return $self->dir_exists("vlans/$vlan");
}


#
# Method: ifaceVlans 
#
# 	Returns information about every vlan that exists on the given trunk
#	interface.	
#
# Parameters: 
#
#	iface - interface name
#
#  Returns:
#
#	array ref - The elements of the array are hashesh. The hashes contain
#	these keys: 'id' (vlan ID), 'name' (user given description for the vlan)
#	and 'interface' (the name of the trunk interface)
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
	$self->dir_exists("vlans/$vlan") or return undef;
	return $self->hash_from_dir("vlans/$vlan");
}

# Method: unsetIface
#
# 	Unset an interface
#
# Parameters: 
#
# 	interface - the name of a network interface
#	force - boolean to indicate if an exception should be raised when
#	interace is changed or it should be forced 
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

	$self->_routersReachableIfChange($name);

	if ($oldm eq 'trunk') {
		$self->_trunkIfaceIsUsed($name);
	}

	if ($oldm eq 'static') {
		$self->_checkStatic($name, $force);
	}

	if ($oldm ne 'notset') {
		my $global = EBox::Global->getInstance();
		my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
		foreach my $mod (@mods) {
			if ($mod->ifaceMethodChanged($name, $oldm, 'notset')) {
				if ($force) {
					$mod->freeIface($name);
				} else {
					throw EBox::Exceptions::DataInUse();
				}
			}
		}
	}

	$self->unset("interfaces/$name/address");
	$self->unset("interfaces/$name/netmask");
	$self->set_string("interfaces/$name/method",'notset');
	$self->set_bool("interfaces/$name/changed", 'true');
}

# Method: ifaceAddress
#	
#	Returns the configured address for a real interface
#
# Parameters:
# 
# 	interface - interface name
#
#  Returns:
#
# 	- For static interfaces: the configured IP Address of the interface.
#	- For dhcp interfaces:
#		- the current address if the interface is up
#		- undef if the interface is down
# 	- For not-yet-configured interfaces
# 		- undef
sub ifaceAddress # (interface) 
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
	} elsif ($self->ifaceMethod($name) eq 'dhcp') {
		return $self->DHCPAddress($name);
	}
	return undef;
}


# Method: ifaceNetmask
#	
#	Returns the configured network mask for a real interface
#
# Parameters:
# 
# 	interface - interface name
#
#  Returns:
#
# 	- For static interfaces: the configured network mask  of the interface.
#	- For dhcp interfaces:
#		- the current network mask the interface is up
#		- undef if the interface is down
# 	- For not-yet-configured interfaces
# 		- undef
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
	} elsif ($self->ifaceMethod($name) eq 'dhcp') {
		if (iface_is_up($name)) {
			return iface_netmask($name);
		}
	}
	return undef;
}

# Method: ifaceNetwork
#	
#	Returns the configured network address  for a real interface
#
# Parameters:
# 
# 	interface - interface name
#
#  Returns:
#
# 	- For static interfaces: the configured network address of the interface.
#	- For dhcp interfaces:
#		- the current network address the interface is up
#		- undef if the interface is down
# 	- For not-yet-configured interfaces
# 		- undef
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
#	Returns the configured broadcast address  for a real interface
#
# Parameters:
# 
# 	interface - interface name
#
#  Returns:
#
# 	- For static interfaces: the configured broadcast address of the 
#	interface.
#	- For dhcp interfaces:
#		- the current broadcast address if the interface is up
#		- undef if the interface is down
# 	- For not-yet-configured interfaces
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
#	Returns a list of the configured name servers
#
#  Returns:
#
#	an array ref - each element contains a string holding the nameserver
sub nameservers
{
	my $self = shift;
	my @array = ();
	foreach (1..2) {
		my $server = $self->get_string("nameserver" . $_);
		(defined($server) and ($server ne '')) or next;
		push(@array, $server);
	}
	return \@array;
}

# Method: nameserverOne
#	
#	Returns the primary nameserver's IP address 
#
#  Returns:
#
#	string - nameserver's IP address	
sub nameserverOne
{
	my $self = shift;
	return $self->get_string("nameserver1");
}

# Method: nameserverTwo
#	
#	Returns the secondary nameserver's IP address 
#
#  Returns:
#
#	string - nameserver's IP address	
sub nameserverTwo
{
	my $self = shift;
	return $self->get_string("nameserver2");
}

# Method: setNameservers
#	
#	Sets the nameservers
#
#   Paramaters:
#
#	one - primary nameserver
#	two - secondary nameserver
sub setNameservers # (one, two) 
{
	my ($self, @dns) = @_;
	my @nameservers = ();
	my $i = 0;
	foreach (@dns) {
		$i++;
		($i < 3) or last;
		(length($_) == 0) or checkIP($_, __("IP address"));
		$self->set_string("nameserver$i", $_);
	}
}

# Method: gateway
#   	
#   	Returns the default gateway's ip address
#   	
# Returns:
#   
#   	If the gateway has not been set it will return undef
#
# 	string - the default gateway's ip address (undef if not set)
sub gateway
{
	my $self = shift;

	return  $self->gatewayModel()->defaultGateway();
}

# Method: routes
#
#   	Returns the configured routes
# 
# Returns:
#   
# 	array ref - each element contains a hash with keys 'network' and 
# 	'gateway', where network is an IP block in CIDR format and gateway 
# 	is an ip address.
sub routes
{
	my $self = shift;
	#my @routes = @{$order->list};
	#my @array = ();
	#foreach (@routes) {
	#	push(@array, $self->hash_from_dir($_));
	#}
	return $self->array_from_dir('routes');
	#return \@array;
}

# Method: addRoute
#
#   	Add a route
#
# Parameters:
#
#   	ip - the destination network (CIDR format)
#   	mask - network mask
#   	gateway - router for the given network
#	 
sub addRoute # (ip, mask, gateway) 
{
	my ($self, $ip, $mask, $gw) = @_;

	checkCIDR("$ip/$mask", __("network address"));
	checkIP($gw, __("ip address"));
	$self->_gwReachable($gw, __("Gateway"));

	$ip = ip_network($ip, mask_from_bits($mask));
	if ($self->_alreadyInRoute($ip, $mask)) {
		throw EBox::Exceptions::DataExists('data' => 'network route',
						  'value' => "$ip/$mask");
	}

	my $id = $self->get_unique_id("r","routes");

	$self->set_string("routes/$id/ip", $ip);
	$self->set_int("routes/$id/mask", $mask);
	$self->set_string("routes/$id/gateway", $gw);
}

sub _markIfaceForRoute # (gateway)
{
	my ($self, $gw) = @_;

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

# Method: delRoute
#
#   	Removes a route	
#
# Parameters:
#
#   	ip - the destination network 
#   	mask - network mask
#
sub delRoute # (ip, mask) 
{
	my ($self, $ip, $mask) = @_;

	my @routes = $self->all_dirs("routes");
	foreach (@routes) {
		($self->get_string("$_/ip") eq $ip) or next;
		($self->get_int("$_/mask") eq $mask) or next;
		$self->_markIfaceForRoute($self->get_string("$_/gateway"));
		$self->delete_dir("$_");
		return;
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
	return $self->get_bool("interfaces/$real/changed");
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

sub _generateResolver
{
	my $self = shift;
	my $dnsfile = EBox::Config::tmp . "resolv.conf";
	open(RESOLVER, ">", $dnsfile) or
	throw EBox::Exceptions::Internal("Could not write on $dnsfile");
	my $dns = $self->nameservers();
	foreach (@{$dns}) {
		print RESOLVER "nameserver " . $_ . "\n";
	}
	close(RESOLVER);
	root("/bin/mv " . EBox::Config::tmp . "resolv.conf /etc/resolv.conf");
}

sub generateInterfaces
{
	my $self = shift;
	my $file = EBox::Config::tmp . "/interfaces";
	my $iflist = $self->allIfacesWithRemoved();

	#writing /etc/network/interfaces
	open(IFACES, ">", $file) or
		throw EBox::Exceptions::Internal("Could not write on $file");
	print IFACES "auto lo";
	foreach (@{$iflist}) {
		if (($self->ifaceMethod($_) eq "static") or 
		    ($self->ifaceMethod($_) eq "dhcp")) {
			print IFACES " " . $_;
		}
	}
	print IFACES "\niface lo inet loopback\n";
	foreach my $ifname (@{$iflist}) {
		my $method = $self->ifaceMethod($ifname);
		if (($method ne 'static') and ($method ne 'dhcp')) {
			next;
		}

		print IFACES "iface $ifname inet $method\n";

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
		}
	}
	close(IFACES);
}

sub _generateRoutes
{
	my $self = shift;
        my @routes = @{$self->routes};
        (@routes) or return;
	foreach (@routes) {
		my $net = $_->{ip} . "/" . $_->{mask};
		my $router = $_->{gateway};
		if (route_is_up($net, $router)) {
			root("/sbin/ip route del $net via $router");
		}
		root("/sbin/ip route add $net via $router table default || true");
	}
}

sub _generateDHCPClientConf
{
	my $self = shift;
	
	my @params = ('script' => 
		EBox::Config::libexec . "../ebox-network/dhclient-script");
	
	$self->writeConfFile(DHCLIENT_CONF_FILE,
				'network/dhclient.conf.mas',
				\@params);
}

sub _multigwRoutes
{
	my $self = shift;
	

	
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
	#
	# We modify the dhclient script behaviour to add the
	# default route where we need it.

	$self->_generateDHCPClientConf();
	
	root(EBox::Config::libexec . "../ebox-network/ebox-flush-fwmarks");
	my $marks = $self->marksForRouters();
	my $routers = $self->gatewaysWithMac();
	for my $router (@{$routers}) {
		my $mark = $marks->{$router->{'id'}};
		my $ip = $router->{'ip'};
		root("/sbin/ip rule add fwmark $mark table $mark");
		root("/sbin/ip route flush table $mark");
		root("/sbin/ip route add default via $ip table $mark");
	}
	root("/sbin/ip rule add table main");
	
	root("/sbin/iptables -t mangle -F");
	try {
		root("/sbin/iptables -t mangle -A PREROUTING "
		     . "-j CONNMARK --restore-mark");
	} catch EBox::Exceptions::Internal with {};

	my $defaultRouterMark;
	foreach my $router (@{$routers}) {
	
		if ($router->{'default'}) {
			$defaultRouterMark = $marks->{$router->{'id'}};
		}
		
		my $mac = $router->{'mac'};
		next if ( $mac eq 'unknown');
		root("/sbin/iptables -t mangle -A PREROUTING  "
		 . "-m mark --mark 0/0xff -m mac --mac-source $mac "
		 . "-j MARK --set-mark $marks->{$router->{'id'}}");		
	}

	
	for my $rule (@{$self->multigwrulesModel()->iptablesRules()}) {
		root("/sbin/iptables $rule");
	}

	
	# If traffic balancing is disabled, send unmarked packets 
	# through default router
	if ((not $self->balanceTraffic()) and ($defaultRouterMark)) {
		root("/sbin/iptables -t mangle -A PREROUTING -m mark " 
		     . "--mark 0/0xff -j  MARK --set-mark $defaultRouterMark");
		root("/sbin/iptables -t mangle -A OUTPUT -m mark " 
		     . "--mark 0/0xff -j  MARK --set-mark $defaultRouterMark");
	}
	 
	try {
		root("/sbin/iptables -t mangle -A PREROUTING "
			."-j CONNMARK --save-mark");
	} catch EBox::Exceptions::Internal with {};

        try {
                root("/sbin/iptables -t mangle -I OUTPUT "
                        ."-j CONNMARK --restore-mark");
        } catch EBox::Exceptions::Internal with {};

}

# Method: _regenConfig
#       
#       Overrides base method. It regenertates the network  configuration.
#	It will set up the network interfaces, routes, dns...

sub _regenConfig
{
	my $self = shift;
	my %opts = @_;
	my $restart = delete $opts{restart};

	my $gateway = $self->gateway;
	my $skipdns = undef;
	my $file = EBox::Config::tmp . "/interfaces";

	try {
		root("/sbin/modprobe 8021q");
	} catch EBox::Exceptions::Internal with {};
	try {
		root("/sbin/vconfig set_name_type VLAN_PLUS_VID_NO_PAD");
	} catch EBox::Exceptions::Internal with {};

	$self->DHCPGatewayCleanUpFix();
	my $dhcpgw = $self->DHCPGateway();
	unless ($dhcpgw and ($dhcpgw ne '')) {
		try {
			root("/sbin/ip route del default table default");
		} catch EBox::Exceptions::Internal with {};
	}

	#bring down changed interfaces
	my $iflist = $self->allIfacesWithRemoved();
	foreach my $if (@{$iflist}) {
		if ($self->_hasChanged($if) or $restart) {
			try {
				root("/sbin/ip address flush label $if");
				root("/sbin/ip address flush label $if:*");
				root("/sbin/ifdown --force -i $file $if");
			} catch EBox::Exceptions::Internal with {};
			#remove if empty
			if ($self->_isEmpty($if)) {
				unless ($self->isReadOnly()) {
					$self->_removeIface($if);
				}
			}
		}
		if ($self->ifaceMethod($if) eq 'dhcp') {
			my @servers = @{$self->DHCPNameservers($if)};
			if (scalar(@servers) > 0) {
				$skipdns = 1;
			}
		} else {
			#clean up dhcp state if interface is not DHCP
			#it should be done by the dhcp hook, but sometimes
			#cruft is left
			$self->DHCPCleanUp($if);
		}
	}

	$self->generateInterfaces();

	unless ($skipdns) {
		# FIXME: there is a corner case when this won't be enough:
		# if the dhcp server serves some dns serves, those will be used,
		# but if it stops serving them at some point, the statically
		# configured ones will not be restored from the dhcp hook.
		#
		# If the server never gives dns servers, everything should work
		# Ok.
		$self->_generateResolver;
	}

	my @ifups = ();
	$iflist = $self->allIfacesWithRemoved();
	foreach (@{$iflist}) {
		if ($self->_hasChanged($_) or $restart) {
			push(@ifups, $_);
		}
	}
	foreach (@ifups) {
		root("/sbin/ifup --force -i $file $_");
		unless ($self->isReadOnly()) {
			$self->_unsetChanged($_);
		}
	}


	my $multipathCmd = $self->_multipathCommand();
	if ($gateway) {
		try {
			my $cmd = $self->_multipathCommand();
			root($cmd);	
		} catch EBox::Exceptions::Internal with {
			throw EBox::Exceptions::External("An error happened ".
			"trying to set the default gateway. Make sure the ".
			"gateway you specified is reachable.");
		};
	}

	$self->_generateRoutes();
	$self->_multigwRoutes();
	$self->_cleanupVlanIfaces();
}

sub stopService
{
	my $self = shift;

	my $file = EBox::Config::tmp . "/interfaces";
	my $iflist = $self->allIfaces();
	foreach my $if (@{$iflist}) {
		try {
			root("/sbin/ip address flush label $if");
			root("/sbin/ip address flush label $if:*");
			root("/sbin/ifdown --force -i $file $if");
		} catch EBox::Exceptions::Internal with {};
	}
}

#internal use functions
# XXX UNUSED FUNCTION
#sub _getInterfaces 
#{
	#my $iflist = Ifconfig('list');
	#return $iflist;
#}

# XXX UNUSED FUNCTION
#sub _getInterfacesArray 
#{
	#my $self = shift;
	#my $iflist = Ifconfig('list');
	#delete $iflist->{lo};
	#my @array;
	#my $i = 0;
	#while (my($key,$value) = each(%{$iflist})) {
		#my $entry;
		#$entry->{name} = $key;
		#($entry->{address}) = keys(%{$value->{inet}});
		#$entry->{netmask} = $value->{inet}->{$entry->{address}};
		#$entry->{status} = $value->{status};
		#$array[$i] = $entry;
		#$i++;
	#}
	#return \@array;
#}

sub _routersReachableIfChange # (interface, newaddress?, newmask?)
{
	my ($self, $iface, $newaddr, $newmask) = @_;

	my @routes = @{$self->routes()};
	my @ifaces = @{$self->allIfaces()};
	my @gws = ();
	foreach my $route (@routes) {
		push(@gws, $route->{gateway});
	}

	foreach my $gw (@{$self->gatewayModel()->gateways()}) {
		push (@gws, $gw->{'ip'});
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
			   'configured routers to become unreachable. ' .
			   'Please remove it first if you really want to '.
			   'make this change.'));
	}
	return 1;
}

sub _gwReachable # (address, name?)
{
	my $self = shift;
	my $gw   = shift;
	my $name = shift;

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
	  }
	  else {
	    throw EBox::Exceptions::External(
					     __x("Gateway {gw} must be reacheable by a static interface. Currently is reacheable by {iface} which is not static", gw => $gw, iface => $reachableByNoStaticIface) );
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
#	Sets the parameters for a DHCP configured interface. For instance,
#	this function is primaraly used from a DHCP hook.
#
# Parameters:
#
# 	iface - interface name 
# 	address - IPv4 address 
# 	mask - networking mask
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
#	Sets the obtained gateway via DHCP
#
# Parameters:
#
# 	gateway - gateway's IPv4 address 
sub setDHCPGateway # (gateway) 
{
	my ($self, $gw) = @_;
	checkIP($gw, __("IP address"));
	$self->st_set_string("dhcp/gateway", $gw);
}

# Method: DHCPCleanUp
#
#	Removes the dhcp configuration 	for a given interface
#
# Parameters:
#
# 	interface - interface name
sub DHCPCleanUp # (interface) 
{
	my ($self, $iface) = @_;
	$self->ifaceExists($iface) or
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
						     value => $iface);
	
	my $gw = $self->DHCPGateway();
	if ($gw and $gw ne '') {
		my $host = $self->DHCPAddress($iface);
		my $mask = $self->DHCPNetmask($iface);
		if (($host and $host ne '') and ($mask and $mask ne '')) {
			if (isIPInNetwork($host, $mask, "$gw/$mask")) {
				$self->DHCPGatewayCleanUp();
			}
		}
	}

	$self->st_delete_dir("dhcp/$iface");
}

# Method: DHCPGateway
#
#	Returns the gateway from a dhcp configured interface	
#
# Returns:
#
#	string - gatewaya
sub DHCPGateway
{
	my ($self) = @_;
	return $self->st_get_string("dhcp/gateway");
}

# Method: DHCPGatewayCleanUp
#
#	Removes the gateway obtained via dhcp
#
sub DHCPGatewayCleanUp
{
	my ($self) = @_;
	$self->st_unset("dhcp/gateway");
}

# Method: DHCPGatewayCleanUpFix
#
#	Remove gateway if there's a dhcp gateway and no ifaces 
#	configured via dhcp
#
# XXX: rant: This module has turned into a pile of evil hacks and methods
#	     We should schedule it for surgery -total rework- ASAP
sub DHCPGatewayCleanUpFix
{
	my ($self) = @_;
	
	return unless ($self->DHCPGateway());

	unless ($self->st_all_dirs("dhcp")) {
		$self->DHCPGatewayCleanUp();
	}
}

# Method: DHCPAddress
#
#	Returns the ip address from a dhcp configured interface
#
# Parameters:
#
# 	interface - interface name
#
# Returns:
#
#	string - IPv4 address
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
#	Returns the network mask from a dhcp configured interface
#
# Parameters:
#
# 	interface - interface name
#
# Returns:
#
#	string - network mask
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
#	Sets the nameserver obtained from a DHCP configured interface
#
# Parameters:
#
# 	interface - interface name
#	nameservers - array ref holding the nameservers
#
# Returns:
#
#	string - network mask
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
#	Sets the nameservers obtained from a DHCP configured interface
#
# Parameters:
#
# 	interface - interface name
#
# Returns:
#
#	array ref - holding the nameservers
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
#	Performs a ping test and returns the output
#
# Parameters:
#
# 	host - host to ping (either ip or hostname)
#
# Returns:
#
#	string - output of the ping command
#
sub ping # (host)
{
	my ($self, $host) = @_;
	(checkIP($host) or checkDomainName($host)) or
		throw EBox::Exceptions::InvalidData
			('data' => __('Host name'), 'value' => $host);
	return `ping -c 3 $host 2>&1`;
}

# Method: resolv
#
#	Performs a name resolution (using dig) and returns the output
#
# Parameters:
#
# 	host - host name to resolve
#
# Returns:
#
#	string - output of the dig command
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

sub summary
{
	my $self = shift;
	my $item = new EBox::Summary::Module(__("Network interfaces"));
	my $ifaces = $self->ifacesWithRemoved;
	my $linkstatus = {};
	root("/sbin/mii-tool > " . EBox::Config::tmp . "linkstatus || true");
	if(open(LINKF, EBox::Config::tmp . "linkstatus")){
		while (<LINKF>){
			if(/link ok/){
				my $i = (split(" ",$_))[0];
				chop($i);
				$linkstatus->{$i} = 1;
			}elsif(/no link/){
				my $i = (split(" ",$_))[0];
				chop($i);
				$linkstatus->{$i} = 0;
			}
		}
	}
	foreach my $iface (@{$ifaces}) {
		iface_exists($iface) or next;
		my $status = __("down");
		my $section = new
			EBox::Summary::Section($self->ifaceAlias($iface));
		$item->add($section);

		if (iface_is_up($iface)) {
			$status = __("up");
		}
		if(defined($linkstatus->{$iface})){
			if($linkstatus->{$iface}){
				$status .= ", " . __("link ok");
			}else{
				$status .= ", " . __("no link");
			}
		}
		$section->add(new EBox::Summary::Value (__("Status"), $status));

		my $ether = iface_mac_address($iface);
		if ($ether) {
			$section->add(new EBox::Summary::Value
				(__("MAC address"), $ether));
		}

		my @ips = iface_addresses($iface);
		foreach my $ip (@ips) {
			$section->add(new EBox::Summary::Value
				(__("IP address"), $ip));
		}
	}
	return $item;
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
					    'order' => 3);

	$folder->add(new EBox::Menu::Item('url' => 'Network/Ifaces',
					  'text' => __('Interfaces')));
	$folder->add(new EBox::Menu::Item('url' => 'Network/DNS',
					  'text' => 'DNS'));
	$folder->add(new EBox::Menu::Item('url' => 'Network/Routes',
					  'text' => __('Routes')));
	$folder->add(new EBox::Menu::Item('url' => 'Network/Diag',
					  'text' => __('Diagnosis')));
	$folder->add(new EBox::Menu::Item('url' => 
						'Network/View/GatewayDataTable',
					  'text' => __('Gateways')));
	$folder->add(new EBox::Menu::Item('url' => 
						'Network/View/MultiGwRulesDataTable',
					  'text' => __('Balance traffic')));

	$root->add($folder);
}

# Method: gatewayModel
#
# 	Return the model associated to the gateway table
#
# Returns:
#
# 	GatewayTableModel
#
sub gatewayModel {
	
	my $self = shift;

	return $self->{'gatewayModel'};
}

# Method: multigwrulesModel
#
# 	Return the model associated to the multi gateway rules table 
#
# Returns:
#
# 	MultiGwRuleTableModel
#
sub multigwrulesModel {
	
	my $self = shift;

	return $self->{'multigwrulesModel'};
}


# Method: gateways
#
# 	Return the gateways available
#
# Returns:
#
# 	array ref of hash refs containing name, ip, upload/download link,
# 	if it is the default gateway or not and the id  for the gateway.
#
#	Example:
#	
#	[ 
#	  { 
#	    name => 'gw1', ip => '192.168.1.1' , interface => 'eth0',
#	    upload => '128',  download => '1024', default => '1',
#	    id => 'foo1234'
#	  } 
#	]
# 	
sub gateways
{
	my $self = shift;

	my $gatewayModel = $self->gatewayModel();

	return $gatewayModel->gateways();

}



# Method: gatewaysWithMac
#
# 	Return the gateways available and its mac address
#
# Returns:
#
# 	array ref of hash refs containing name, ip, upload/download link,
# 	if it is the default gateway or not and the id  for the gateway.
#
#	Example:
#	
#	[ 
#	  { 
#	    name => 'gw1', ip => '192.168.1.1' , 
#	    upload => '128',  download => '1024', defalut => '1',
#	    id => 'foo1234', mac => '00:00:fa:ba:da'
#	  } 
#	]
# 	
sub gatewaysWithMac
{
	my $self = shift;

	my $gatewayModel = $self->gatewayModel();

	return $gatewayModel->gatewaysWithMac();

}

sub marksForRouters
{
	my $self = shift;
	my $marks = $self->gatewayModel()->marksForRouters();
}

# Method: balanceTraffic
#
#	Return if the traffic balancing is enabled or not
#
# Returns:
# 
#	bool - true if enabled, otherwise false
#
sub balanceTraffic
{
	my $self = shift;
	
	return ($self->get_bool('balanceTraffic') and (@{$self->gateways} > 1));
}

# Method: setBalanceTraffic
#
#	Set the traffic balancing
#
# Parameters:
#
#	balance - bool to enable/disable
#
sub setBalanceTraffic
{	
	my ($self, $balance) = @_;
	
	unless ($balance ne $self->balanceTraffic) {
		return;
	}

	$self->set_bool('balanceTraffic', $balance);

}

sub _multipathCommand
{
	my $self = shift;

	my @gateways = @{$self->gateways()};

	unless (scalar(@gateways) > 0) {
		return undef;
	}

	my $cmd = 'ip route add table default default';
	for my $gw (@gateways) {
		$cmd .= " nexthop via $gw->{'ip'} weight $gw->{'weight'}";
	}

	return $cmd;
}

1;
