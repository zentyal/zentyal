# Copyright (C) 2005  Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::DHCP;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::NetworkObserver EBox::LogObserver EBox::Model::ModelProvider EBox::Model::CompositeProvider);

use EBox::Objects;
use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Validate qw(:all);
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Summary::Status;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo qw(:all);
use EBox::NetWrappers qw(:all);
use EBox::Service;
use EBox::DHCPLogHelper;

# Models & Composites
use EBox::Common::Model::EnableForm;
use EBox::DHCP::Composite::InterfaceConfiguration;
use EBox::DHCP::Composite::General;
use EBox::DHCP::Composite::Interfaces;
use EBox::DHCP::Model::FixedAddressTable;
use EBox::DHCP::Model::Options;
use EBox::DHCP::Model::RangeInfo;
use EBox::DHCP::Model::RangeTable;
use Net::IP;
use HTML::Mason;
use Error qw(:try);

#Module local conf stuff
use constant DHCPCONFFILE => "/etc/dhcp3/dhcpd.conf";
use constant PIDFILE => "/var/run/dhcpd.pid";
use constant SERVICE => "dhcpd3";

sub _create
{
	my $class = shift;
	my $self  = $class->SUPER::_create(name => 'dhcp', 
                                           domain => 'ebox-dhcp',
                                           printableName => __('dhcp'),
                                           @_);
	bless ($self, $class);
	return $self;
}

sub domain
{
	return 'ebox-dhcp';
}

sub _doDaemon
{
	my $self = shift;
	if ($self->service and EBox::Service::running(SERVICE)) {
		EBox::Service::manage(SERVICE,'restart');
	} elsif ($self->service) {
		EBox::Service::manage(SERVICE,'start');
	} elsif (not $self->service and EBox::Service::running(SERVICE)) {
		EBox::Service::manage(SERVICE,'stop');
	}
}

sub _stopService
{
	EBox::Service::manage(SERVICE,'stop');
}

#   Function: _regenConfig
#
#       Overrides base method. It regenertates the dhcp service configuration
#
sub _regenConfig
{
	my $self = shift;
	$self->setDHCPConf;
	$self->_doDaemon();
}

# Method: models
#
# Overrides:
#
#     <EBox::Model::ModelProvider::models>
#
sub models
{

    my ($self) = @_;

    my @models;
    my $net = EBox::Global->modInstance('network');
    foreach my $iface (@{$net->allIfaces()}) {
        if ( $net->ifaceMethod($iface) eq 'static' ) {
            # Create models
            push ( @models, new EBox::DHCP::Model::RangeTable(
                                                              gconfmodule => $self,
                                                              directory   => "RangeTable/$iface",
                                                              interface   => $iface));
            push ( @models, new EBox::DHCP::Model::FixedAddressTable(
                                                              gconfmodule => $self,
                                                              directory   => "FixedAddressTable/$iface",
                                                              interface   => $iface));
            push ( @models, new EBox::DHCP::Model::Options(
                                                           gconfmodule => $self,
                                                           directory   => "Options/$iface",
                                                           interface   => $iface));
            push ( @models, new EBox::DHCP::Model::RangeInfo(
                                                             gconfmodule => $self,
                                                             directory   => "RangeInfo/$iface",
                                                             interface   => $iface));
        }
    }
    push ( @models,
           new EBox::Common::Model::EnableForm(
                                               gconfmodule => $self,
                                               directory   => 'EnableForm',
                                               domain      => 'ebox-dhcp',
                                               enableTitle => __('DHCP service status'),
                                               modelDomain => 'DHCP',
                                              ));

    return \@models;

}

# Method: composites
#
# Overrides:
#
#     <EBox::Model::ModelProvider::composites>
#
sub composites
{

    my ($self) = @_;

    my @composites;
    my $net = EBox::Global->modInstance('network');
    foreach my $iface (@{$net->allIfaces()}) {
        if ( $net->ifaceMethod($iface) eq 'static' ) {
            # Create models
            push ( @composites,
                   new EBox::DHCP::Composite::InterfaceConfiguration(interface => $iface));
        }
    }
    push ( @composites,
           new EBox::DHCP::Composite::Interfaces());
    push ( @composites,
           new EBox::DHCP::Composite::General());

    return \@composites;

}


#   Function: setService 
#
#	Sets the dhcp service as enabled
#
#   Parameters:
#
#	enabled - boolean. True enable, undef disable
#
sub setService # (enabled)
{
	my ($self, $active) = @_;

	($active and $self->service) and return;
	(!$active and !$self->service) and return;

	if ($active) {
	  if ($self->nStaticIfaces() == 0) {
	    throw EBox::Exceptions::External(__("DHCP server can not activated because there are not any network interface with a static address. <a href='Network/Ifaces'>Configure one</a> first"));
	  }
	}

	$self->set_bool("active", $active);
	$self->_configureFirewall();
}

#   Function: service 
#
#	Returns if the dhcp service is enabled	
#
#   Returns:
#
#	boolean - true if enabled, otherwise undef	
#
sub service
{
	my $self = shift;
	return $self->get_bool("active");
}


#   Function: setDHCPConf 
#
#	Updates the dhcpd.conf file
#
sub setDHCPConf
{
	my $self = shift;

	my $net = EBox::Global->modInstance('network');
	my $staticRoutes_r =  $self->staticRoutes();

	my @params = ();
	push @params, ('dnsone' => $net->nameserverOne);
	push @params, ('dnstwo' => $net->nameserverTwo);
 	push @params, ('ifaces' => $self->ifacesInfo($staticRoutes_r));
 	push @params, ('real_ifaces' => $self->realIfaces());

	$self->writeConfFile(DHCPCONFFILE, "dhcp/dhcpd.conf.mas", \@params);
}

sub realIfaces
{
  my ($self) = @_;
  my $net = EBox::Global->modInstance('network');
 
  my $real_ifaces = $net->ifaces();
  my %realifs;
  foreach (@{$real_ifaces}) {
    if ($net->ifaceMethod($_) eq 'static') {
      $realifs{$_} = $net->vifaceNames($_);
    }
 
  }
 
  return \%realifs;
}
 
 
sub ifacesInfo
{
  my ($self, $staticRoutes_r) = @_;
 
  my $net = EBox::Global->modInstance('network');
  my $ifaces = $net->allIfaces();
 
  my %iflist;
  foreach (@{$ifaces}) {
    if ($net->ifaceMethod($_) eq 'static') {
      my $address = $net->ifaceAddress($_);
      my $netmask = $net->ifaceNetmask($_);
      my $network = ip_network($address, $netmask);
 
      $iflist{$_}->{'net'} = $network;
      $iflist{$_}->{'address'} = $address;
      $iflist{$_}->{'netmask'} = $netmask;
      $iflist{$_}->{'ranges'} = $self->ranges($_);
      $iflist{$_}->{'fixed'} = $self->fixedAddresses($_);

      # look if we have static routes for this network
      my $netWithMask = EBox::NetWrappers::to_network_with_mask($network, $netmask);
       $iflist{$_}->{'staticRoutes'} =  $staticRoutes_r->{$netWithMask} if exists $staticRoutes_r->{$netWithMask};
 
      my $gateway = $self->defaultGateway($_);
      if (defined($gateway) and $gateway ne "") {
	$iflist{$_}->{'gateway'} = $gateway;
      } else {
	$iflist{$_}->{'gateway'} = $address;
      }
      my $search = $self->searchDomain($_);
      $iflist{$_}->{'search'} = $search;
      my $nameserver1 = $self->nameserver($_,1);
      if (defined($nameserver1) and $nameserver1 ne "") {
	$iflist{$_}->{'nameserver1'} = $nameserver1;
      }
      my $nameserver2 = $self->nameserver($_,2);
      if (defined($nameserver2) and $nameserver2 ne "") {
	$iflist{$_}->{'nameserver2'} = $nameserver2;
      }
    }
  }
 
  return \%iflist;
}
 
 
sub isNetworkManaged
{
  my ($self, $network, $netmask ) = @_;
 
  return 0 if !($self->service());
 
  my $net = EBox::Global->modInstance('network');
  my $ifaces = $net->allIfaces();
  foreach my $if (@{ $ifaces }) {
    next if $net->ifaceMethod($if) ne 'static';
 
    my $address = $net->ifaceAddress($_);
    my $ifNetmask = $net->ifaceNetmask($_);
    my $ifNetwork = ip_network($address, $netmask);
 
    if (($network eq $ifNetwork) and ($netmask eq $ifNetmask)) {
      return 1;
    }
  }
 
  return 0;
}


#   Function: initRange
#
#	Returns the initial host address  range for a given interface
#   
#   Parameters:
#	
#	iface - interface name
#
#   Returns:
#
#	string - containing the initial range
#
sub initRange # (interface)
{
	my ($self, $iface) = @_;

	my $net = EBox::Global->modInstance('network');
	my $address = $net->ifaceAddress($iface);
	my $netmask = $net->ifaceNetmask($iface);
	
	my $network = ip_network($address, $netmask);
	my ($first, $last) = $network =~ /(.*)\.(\d+)$/;
	my $init_range = $first . "." . ($last+1);
	return $init_range;
}

#   Function: endRange
#
#	Returns the final host address  range for a given interface
#   
#   Parameters:
#	
#	iface - interface name
#
#   Returns:
#
#	string - containing the final range
#
sub endRange # (interface)
{
	my ($self, $iface) = @_;

	my $net = EBox::Global->modInstance('network');
	my $address = $net->ifaceAddress($iface);
	my $netmask = $net->ifaceNetmask($iface);
	
	my $broadcast = ip_broadcast($address, $netmask);
	my ($first, $last) = $broadcast =~ /(.*)\.(\d+)$/;
	my $end_range = $first . "." . ($last-1);
	return $end_range;
}

#   Function: setDefaultGateway
#
#	Sets the default gateway that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#	gateway - gateway IP, it can be empty
#
sub setDefaultGateway # (iface, gateway)
{
	my ($self, $iface, $gateway) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	if(defined($gateway) && $gateway ne ""){
		checkIP($gateway, __("Gateway IP address"));
		if(not isIPInNetwork($network->ifaceNetwork($iface),
				$network->ifaceNetmask($iface), $gateway)) {
			throw EBox::Exceptions::External(__x("{gateway} is not in the current network", gateway => $gateway));
		}
	}
	$self->set_string("$iface/gateway", $gateway);
}

#   Function: defaultGateway
#
#	Gets the default gateway that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#
#   Returns:
#   	string - the default gateway
#
sub defaultGateway # (iface)
{
	my ($self, $iface) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	$self->get_string("$iface/gateway");
}

#   Function: setSearchDomain
#
#	Sets the search domain that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#	search - search domain
#
sub setSearchDomain # (iface, search)
{
	my ($self, $iface, $search) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	if(defined($search) && $search ne ""){
		checkDomainName($search, __("Search domain"));
	}
	$self->set_string("$iface/search", $search);
}

#   Function: searchDomain
#
#	Gets the search domain that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#
#   Returns:
#   	string - the search domain
#
sub searchDomain # (iface)
{
	my ($self, $iface) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	$self->get_string("$iface/search");
}

#   Function: setNameserver
#
#	Sets the nameserver that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#   	number - nameserver number (1 or 2)
#	nameserver - nameserver IP
sub setNameserver # (iface, number, nameserver)
{
	my ($self, $iface, $number, $nameserver) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	if($nameserver) {
		checkIP($nameserver, __("Nameserver IP address"));
	}
	$self->set_string("$iface/nameserver$number", $nameserver);
}

#   Function: nameserver
#
#	Gets the nameserver that will be sent to DHCP clients for a
#	given interface
#
#   Parameters:
#
#   	iface - interface name
#   	number - nameserver number (1 or 2)
#
#   Returns:
#   	string - the nameserver
#
sub nameserver # (iface,number)
{
	my ($self, $iface, $number) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	$self->get_string("$iface/nameserver$number");
}

#   Function: staticRoutes
#
#	Gets the static routes. It polls the ebox modules wich implements EBox::DHCP::StaticRouteProvider
#   Returns:
#
#	hash ref - contating the static toutes in hash refereces. The key are the subnets in CIDR notations that denotes where is appliable the new route. 
#	The valkues are  hash rference with the keys 'destination', 'netmask' and 'gw'
#	
sub staticRoutes
{
  my ($self) = @_;
  my %staticRoutes = ();

  my @modules = @{ EBox::Global->modInstancesOfType('EBox::DHCP::StaticRouteProvider') };
  foreach  my $mod (@modules) {
    my @modStaticRoutes = @{ $mod->staticRoutes() };
    while (@modStaticRoutes) {
      my $net   = shift @modStaticRoutes;
      my $route = shift @modStaticRoutes;
      if (exists $staticRoutes{$net}) {
	push  @{$staticRoutes{$net}}, $route;
      }
      else {
	$staticRoutes{$net} = [$route];
      }
    }
  }

  return \%staticRoutes;
}




sub notifyStaticRoutesChange
{
  my ($self) = @_;
  $self->setAsChanged();
}


#   Function: addRange
#
#	Adds a range for a given interface
#   
#   Parameters:
#	
#	iface - interface name
#	name - range name
#	from - start of  range
#	to - end of range
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#	External - interface is not static 
#	External - invalid range
#	External - range overlap
sub addRange # (iface, name, from, to)
{
	my ($self, $iface, $name, $from, $to) = @_;
	
	my $network = EBox::Global->modInstance('network');

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}
	
	checkIP($from, __("\"From\" IP address"));
	checkIP($to, __("\"To\" IP address"));

	my $range = new Net::IP($from . " - " . $to);
	unless(defined($range)){
		throw EBox::Exceptions::External(
			__x("{from}-{to} is an invalid range",
			from => $from, to => $to));
	}
	my $netstr = $network->ifaceNetwork($iface) . "/" . 
		bits_from_mask($network->ifaceNetmask($iface));
	my $net = new Net::IP($netstr);

	unless($range->overlaps($net)==$IP_A_IN_B_OVERLAP){
		throw EBox::Exceptions::External(
			__x("Range {from}-{to} is not in network {net}",
				from => $from, to => $to, net => $netstr));
	}

	my $iface_address = $network->ifaceAddress($iface);
	my $iface_ip = new Net::IP($iface_address);
	if($iface_ip->overlaps($range)!=$IP_NO_OVERLAP){
		throw EBox::Exceptions::External(
			__x("Range {new_from}-{new_to} includes interface ".
			    "IP address: {iface_ip}",
				new_from => $from, new_to => $to,
				iface_ip => $iface_address));
	}

	my $ranges = $self->ranges($iface);
	foreach my $r (@{$ranges}){
		my $r_ip = new Net::IP($r->{'from'} . " - " . $r->{'to'});
		if($r_ip->overlaps($range)!=$IP_NO_OVERLAP){
			throw EBox::Exceptions::External(
				__x("Range {new_from}-{new_to} overlaps with ".
				    "range '{range}': {old_from}-{old_to}",
					new_from => $from, new_to => $to, 
					range => $r->{'name'},
					old_from => $r->{'from'},
					old_to => $r->{'to'}));
		}
	}

	my $fixedAddresses = $self->fixedAddresses($iface);
	foreach my $f (@{$fixedAddresses}){
		my $f_ip = new Net::IP($f->{'ip'});
		if($f_ip->overlaps($range)!=$IP_NO_OVERLAP){
			throw EBox::Exceptions::External(
			__x("Range {new_from}-{new_to} includes fixed ".
			    "address '{name}': {fixed_ip}",
				new_from => $from, new_to => $to, 
				name => $f->{'name'},
				fixed_ip => $f->{'ip'}));
		}
	}

	my $id = $self->get_unique_id("r", "$iface/ranges");

	$self->set_string("$iface/ranges/$id/name", $name);
	$self->set_string("$iface/ranges/$id/from", $from);
	$self->set_string("$iface/ranges/$id/to", $to);
}

#   Function: removeRange
#
#	Removes a given range from an interface
#   
#   Parameters:
#	
#	iface - interface name
#	id - range id
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#
sub removeRange # (iface, id)
{
	my ($self, $iface, $id) = @_;
	
	$self->dir_exists($iface) or
		throw EBox::Exceptions::DataNotFound('data' => __('Interface'),
						     'value' => $iface);

	$self->delete_dir("$iface/ranges/$id");
}

#   Function: ranges 
#
#	Returns all the set  ranges for a given interface
#   
#   Parameters:
#	
#	iface - interface name
#
#   Returns:
#
#	array ref - contating the ranges in hash references. Each hash holds
#	the keys 'name', 'from' and 'to'
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#
sub ranges # (iface)
{
	my ($self, $iface) = @_;

	my $global = EBox::Global->getInstance();
	my $network = EBox::Global->modInstance('network');

	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound('data' => __('Interface'),
						'value' => $iface);
	}	

	return $self->array_from_dir("$iface/ranges");
}

#   Function: addFixedAddress
#
#	Sets a ip/mac pair as fixed address in a given interface.
#   
#   Parameters:
#	
#	iface - interface name
#	mac - mac address
#	ip - IPv4 address
#	name - name 
#
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#	External - Interface is not configured as static
#	External - ip is not in the network for the given interface
#	External - ip overlap 
#	External - ip already configured as fixed
#
sub addFixedAddress # (interface, mac, ip, name)
{
	my ($self, $iface, $mac, $ipstr, $name) = @_;

	my $network = EBox::Global->modInstance('network');
	
	unless (checkDomainName($name)) {
		throw EBox::Exceptions::InvalidData(
					'data' => __('Name'), 
					'value' => $name);
	}

	#if iface doesn't exists throw exception
	if (not $iface or not $network->ifaceExists($iface)) {
		throw EBox::Exceptions::DataNotFound(data => __('Interface'),
				value => $iface);
	}

	#if iface is not static, throw exception
	if ($network->ifaceMethod($iface) ne 'static') {
		throw EBox::Exceptions::External(__x("{iface} is not static",
			iface => $iface));
	}

	checkMAC($mac, __('MAC address'));
	checkIP($ipstr, __('IP address'));

	my $netstr = $network->ifaceNetwork($iface) . "/" . 
		bits_from_mask($network->ifaceNetmask($iface));
	my $net = new Net::IP($netstr);

	my $ip = new Net::IP($ipstr);

	unless($ip->overlaps($net)==$IP_A_IN_B_OVERLAP){
		throw EBox::Exceptions::External(
			__x("IP address {ip} is not in network {net}",
				ip => $ipstr, net => $netstr));
	}

	my $iface_address = $network->ifaceAddress($iface);
	my $iface_ip = new Net::IP($iface_address);
	if($iface_ip->overlaps($ip)!=$IP_NO_OVERLAP){
		throw EBox::Exceptions::External(
			__x("The selected IP is the interface IP address: ".
			    "{iface_ip}",
				iface_ip => $iface_address));
}

	my $ranges = $self->ranges($iface);
	foreach my $r (@{$ranges}){
		my $r_ip = new Net::IP($r->{'from'} . " - " . $r->{'to'});
		if($r_ip->overlaps($ip)!=$IP_NO_OVERLAP){
			throw EBox::Exceptions::External(
			__x("IP address {ip} is in range '{range}': ".
			    "{old_from}-{old_to}",
				ip => $ipstr,
				range => $r->{'name'},
				old_from => $r->{'from'},
				old_to => $r->{'to'}));
		}
	}

	my $ifaces = $network->allIfaces();
	foreach my $if (@{$ifaces}) {
		my $fixedAddresses = $self->fixedAddresses($if);
		foreach my $f (@{$fixedAddresses}){
			#check IP addresses for the iface it's being added
			if($if eq $iface){
				my $f_ip = new Net::IP($f->{'ip'});
				if($f_ip->overlaps($ip)!=$IP_NO_OVERLAP){
					throw EBox::Exceptions::External(
					__x("IP address {ip} is already ".
					    "added as fixed address '{name}'",
						ip => $ipstr ,
						name => $f->{'name'}));
				}
			}
			#check MAC addresses for every iface
			if($f->{'mac'} eq $mac){
				throw EBox::Exceptions::External(
				__x("MAC address {mac} is already added as ".
				    "fixed address '{name}' for interface ".
				    "'{iface}'",
					mac => $mac,
					name => $f->{'name'},
					iface => $if));
			}
		}
	}
	
	my $id = $self->get_unique_id("f","$iface/fixed");

	$self->set_string("$iface/fixed/$id/mac", $mac);
	$self->set_string("$iface/fixed/$id/ip", $ipstr);
	$self->set_string("$iface/fixed/$id/name", $name);
}

#   Function: removeFixed
#
#	Removes a given fixed address from an interface
#   
#   Parameters:
#	
#	iface - interface name
#	id -  fixed address id
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#
sub removeFixed # (iface, id)
{
	my ($self, $iface, $id) = @_;
	
	$self->dir_exists($iface) or
		throw EBox::Exceptions::DataNotFound('data' => __('Interface'),
						     'value' => $iface);

	$self->delete_dir("$iface/fixed/$id");
}


#   Function: ranges 
#
#	Return the list of fixed addreses
#   
#   Parameters:
#	
#	iface - interface name
#
#   Returns:
#
#	array ref - contating the fixed addresses in hash refereces. 
#	Each hash holds the keys 'mac', 'ip' and 'name'
#
#   Exceptions:
#
#	DataNotFound - Interface does not exist
#
sub fixedAddresses # (interface)
{
	my ($self,$iface) = @_;
	return $self->array_from_dir("$iface/fixed");
}

sub _configureFirewall {
	my $self = shift;
	my $fw = EBox::Global->modInstance('firewall');
	try {
		$fw->removeOutputRule('udp', 67);
		$fw->removeOutputRule('udp', 68);
		$fw->removeOutputRule('tcp', 67);
		$fw->removeOutputRule('tcp', 68);
	} catch EBox::Exceptions::Internal with { };

	if ($self->service) {
		$fw->addOutputRule('tcp', 67);
		$fw->addOutputRule('tcp', 68);
		$fw->addOutputRule('udp', 67);
		$fw->addOutputRule('udp', 68);
		
	}
}

# Function: ifaceMethodChanged
#
# Implements:
#
#    <EBox::NetworkObserver::ifaceMethodChanged>
#
# Returns:
#
#     true - if the old method is 'static' and there are configured
#     ranges or fixed addresses attached to this interface
#     false - otherwise
#
sub ifaceMethodChanged # (iface, old_method, new_method)
{
	my ($self, $iface, $old_method, $new_method) = @_;
#	return 0 if !$self->service();
#	return 0 if $old_method ne 'static';
#	return 0 if $new_method eq 'static';
#
#	return 1;
        if ($old_method eq 'static') {
            my $manager = EBox::Model::ModelManager->instance();
            my $rangeModel = $manager->model("/dhcp/RangeTable/$iface");
            return 1 if ( $rangeModel->size() > 0);
            my $fixedAddrModel = $manager->model("/dhcp/FixedAddressTable/$iface");
            return 1 if ( $fixedAddrModel->size() > 0);
        }
        return 0;
}

# Function: vifaceAdded
#
#
# Implements:
#
#   <EBox::NetworkObserver::vifaceAdded>
#
# Exceptions:
#
#  <EBox::Exceptions::External> - thrown *if*:
#
#   - New Virtual interface IP overlaps any configured range
#   - New Virtual interface IP is a fixed IP address
#
sub vifaceAdded # (iface, viface, address, netmask)
{
	my ( $self, $iface, $viface, $address, $netmask) = @_;

	my $net = EBox::Global->modInstance('network');
	my $ip = new Net::IP($address);

        my $manager = EBox::Model::ModelManager->instance();

        my @rangeModels = @{$manager->model('/dhcp/RangeTable/*')};
        # Check that the new IP for the virtual interface isn't in any range
        foreach my $rangeModel (@rangeModels) {
            foreach my $rangeRow (@{$rangeModel->rows()}) {
                my $from = $rangeRow->{plainValueHash}->{from};
                my $to   = $rangeRow->{plainValueHash}->{to};
                my $range = new Net::IP($from . ' - ' . $to);
                unless ( $ip->overlaps($range) == $IP_NO_OVERLAP ) {
                    throw EBox::Exceptions::External(
			__x('The IP address of the virtual interface '
                            . 'you are trying to add is already used by the '
                            . "DHCP range '{range}' in the interface "
                            . "'{iface}'. Please, remove it before trying "
                            . 'to add a virtual interface using it.',
                            range => $rangeRow->{plainValueHash}->{name},
                            iface => $rangeModel->index()));
                }
            }
        }

        my @fixedAddrModels = @{$manager->model('/dhcp/FixedAddressTable/*')};
        # Check the new IP for the virtual interface is not a fixed address
        foreach my $fixedAddrModel (@fixedAddrModels) {
            foreach my $mappingRow (@{$fixedAddrModel->rows()}) {
                my $fixedIP = new Net::IP($mappingRow->{plainValueHash}->{ip});
                unless ( $ip->overlaps($fixedIP) == $IP_NO_OVERLAP ) {
                    throw EBox::Exceptions::External(
                           __x('The IP address of the virtual interface '
                               . 'you are trying to add is already used by the '
                               . "DHCP fixed address '{fixed}' in the "
                               . "interface '{iface}'. Please, remove it "
                               . 'before trying to add a virtual interface '
                               . 'using it.',
                               fixed => $mappingRow->{plainValueHash}->{name},
                               iface => $fixedAddrModel->index()));

                }
            }
        }
#
#	my $ifaces = $net->allIfaces();
#	foreach my $if (@{$ifaces}) {
#		my $ranges = $self->ranges($if);
#		foreach my $r (@{$ranges}){
#			my $r_ip = new Net::IP($r->{'from'} ." - ". $r->{'to'});
#			#check that the new IP isn't in any range
#			unless($ip->overlaps($r_ip)==$IP_NO_OVERLAP){
#				throw EBox::Exceptions::External(
#				__x("The IP address of the virtual interface " .
#				"you're trying to add is already used by the " .
#				"DHCP range '{range}' in the interface " .
#				"'{iface}'. Please, remove it before trying " .
#				"to add a virtual interface using it.",
#				range => $r->{name}, iface => $if));
#			}
#		}
#		my $fixedAddresses = $self->fixedAddresses($if);
#		foreach my $f (@{$fixedAddresses}){
#			my $f_ip = new Net::IP($f->{'ip'});
#			#check that the new IP isn't in any fixed address
#			unless($ip->overlaps($f_ip)==$IP_NO_OVERLAP){
#				throw EBox::Exceptions::External(
#				__x("The IP address of the virtual interface " .
#				"you're trying to add is already used by the " .
#				"DHCP fixed address '{fixed}' in the " .
#				"interface '{iface}'. Please, remove it " .
#				"before trying to add a virtual interface " .
#				"using it.",
#				fixed => $f->{name}, iface => $if));
#			}
#		}
#	}

}

# Function:  vifaceDelete
#
# Implements:
#
#    <EBox::NetworkObserver::vifaceDelete>
#
# Returns:
#
#    true - if there are any configured range or fixed address for
#    this interface
#    false - otherwise
#
sub vifaceDelete # (iface, viface)
{
	my ( $self, $iface, $viface) = @_;
#	my $nr = @{$self->ranges("$iface:$viface")};
#	my $nf = @{$self->fixedAddresses("$iface:$viface")};
#	return (($nr != 0) or ($nf != 0));
        my $manager = EBox::Model::ModelManager->instance();
        my $rangeModel = $manager->model("/dhcp/RangeTable/$iface:$viface");
        my $nr = $rangeModel->size();
        if ( $nr != 0 ) {
            return 1;
        }
        my $fixedAddrModel = $manager->model("/dhcp/FixedAddressTable/$iface:$viface");
        my $nf = $fixedAddrModel->size();
        if ( $nf != 0) {
            return 1;
        }
        # FIXME: delete data from Options if any stored in GConf
        return 0;
}

# Function: staticIfaceAddressChanged
#
#       Return true *unless*:
#
#       - all ranges are still in the network
#       - new IP is not in any range
#       - all fixed addresses are still in the network
#       - new IP is not any fixed IP address
#
# Implements:
#
#       <EBox::NetworkObserver::staticIfaceAddressChanged>
#
sub staticIfaceAddressChanged # (iface, old_addr, old_mask, new_addr, new_mask)
{
	my ( $self, $iface, $old_addr, $old_mask, $new_addr, $new_mask) = @_;
#	my $nr = @{$self->ranges($iface)};
#	my $nf = @{$self->fixedAddresses($iface)};
#	if(($nr == 0) and ($nf == 0)){
#		return 0;
#	}

	my $ip = new Net::IP($new_addr);

	my $network = ip_network($new_addr, $new_mask);
	my $bits = bits_from_mask($new_mask);
	my $netIP = new Net::IP("$network/$bits");

        # Check ranges
        my $manager = EBox::Model::ModelManager->instance();
        my $rangeModel = $manager->model("/dhcp/RangeTable/$iface");
        foreach my $rangeRow (@{$rangeModel->rows()}) {
            my $range = new Net::IP($rangeRow->{plainValueHash}->{from}
                                    . ' - ' .
                                    $rangeRow->{plainValueHash}->{to});
            # Check the range is still in the network
            unless ($range->overlaps($netIP) == $IP_A_IN_B_OVERLAP){
                return 1;
            }
            # Check the new IP isn't in any range
            unless($ip->overlaps($range) == $IP_NO_OVERLAP ){
                return 1;
            }
        }
        my $fixedAddrModel = $manager->model("/dhcp/FixedAddressTable/$iface");
        foreach my $mappingRow (@{$fixedAddrModel->rows()}) {
            my $fixedIP = new Net::IP( $mappingRow->{plainValueHash}->{ip} );
            # Check the fixed address is still in the network
            unless($fixedIP->overlaps($netIP) == $IP_A_IN_B_OVERLAP){
                return 1;
            }
            # Check the new IP isn't in any fixed address
            unless( $ip->overlaps($fixedIP) == $IP_NO_OVERLAP){
                return 1;
            }
        }

#	my $ranges = $self->ranges($iface);
#	foreach my $r (@{$ranges}){
#		my $r_ip = new Net::IP($r->{'from'} . " - " . $r->{'to'});
#		#check that the range is still in the network
#		unless($r_ip->overlaps($net_ip)==$IP_A_IN_B_OVERLAP){
#			return 1;
#		}
#		#check that the new IP isn't in any range
#		unless($ip->overlaps($r_ip)==$IP_NO_OVERLAP){
#			return 1;
#		}
#	}
#	my $fixedAddresses = $self->fixedAddresses($iface);
#	foreach my $f (@{$fixedAddresses}){
#		my $f_ip = new Net::IP($f->{'ip'});
#		#check that the fixed address is still in the network
#		unless($f_ip->overlaps($net_ip)==$IP_A_IN_B_OVERLAP){
#			return 1;
#		}
#		#check that the new IP isn't in any fixed address
#		unless($ip->overlaps($f_ip)==$IP_NO_OVERLAP){
#			return 1;
#		}
#	}

	return 0;
}

# Function: freeIface
#
#    Delete every single row from the models attached to this
#    interface
#
# Implements:
#
#    <EBox::NetworkObserver::freeIface>
#
#
sub freeIface #( self, iface )
{
	my ( $self, $iface ) = @_;
#	$self->delete_dir("$iface");
        $self->_removeDataModelsAttached($iface);

	my $net = EBox::Global->modInstance('network');
	if ($net->ifaceMethod($iface) eq 'static') {
	  $self->_checkStaticIfaces(-1);
	}
}

# Function: freeViface
#
#    Delete every single row from the models attached to this virtual
#    interface
#
# Implements:
#
#    <EBox::NetworkObserver::freeViface>
#
#
sub freeViface #( self, iface, viface )
{
	my ( $self, $iface, $viface ) = @_;
#	$self->delete_dir("$iface:$viface");
        $self->_removeDataModelsAttached("$iface:$viface");

#	my $net = EBox::Global->modInstance('network');
#	if ($net->ifaceMethod($viface) eq 'static') {
	  $self->_checkStaticIfaces(-1);
#	}

}




sub _checkStaticIfaces
{
  my ($self, $adjustNumber) = @_;
  defined $adjustNumber or $adjustNumber = 0;

  my $nStaticIfaces = $self->nStaticIfaces() + $adjustNumber;
  if ($nStaticIfaces == 0) {
    if ($self->service()) {
      $self->setService(0);
      EBox::info('DHCP service was deactivated because there was not any static interface left');
    }
  }  
}


sub nStaticIfaces
{
  my ($self) = @_;

  my $net = EBox::Global->modInstance('network');
  my $ifaces = $net->allIfaces();
  my $staticIfaces = grep  { $net->ifaceMethod($_) eq 'static' } @{$ifaces};

  return $staticIfaces;
}

#   Function: statusSummary 
#
#	Overrides EBox::Module method. It returns summary components. 
#   
#
sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('dhcp', 'DHCP',
		EBox::Service::running(SERVICE), $self->service);	
}

# Method: onInstall
#
# 	Method to execute the first time the module is installed.
#
sub onInstall
{
	EBox::init();

	_addDHCPService();

	my $fw = EBox::Global->modInstance('firewall');
    $fw->setInternalService('dhcp', 'accept');
    $fw->save();
}

# Method: onRemove
#
# 	Method to execute before the module is uninstalled
#
sub onRemove
{
	EBox::init();

	my $serviceMod = EBox::Global->modInstance('services');
	my $fwMod = EBox::Global->modInstance('firewall');

	if ($serviceMod->serviceExists('name' => 'dhcp')) {
		 $serviceMod->removeService('name' => 'dhcp');
	} else {
		EBox::info("Not removing dhcp services as it already exists");
	}

	$serviceMod->save();
    $fwMod->save();
}

#   Function: menu 
#
#	Overrides EBox::Module method.
#   
#
sub menu
{
        my ($self, $root) = @_;
        $root->add(new EBox::Menu::Item('url' => 'DHCP/Index',
                                        'text' => 'DHCP'));
}


# Impelment LogHelper interface
sub tableInfo {
	my $self = shift;

	my $titles = { 'timestamp' => __('Date'),
		'interface' => __('Interface'),
		'mac' => __('MAC address'),
		'ip' => __('IP'),
		'event' => __('Event')
	};
	my @order = ('timestamp', 'ip', 'mac', 'interface', 'event');
	my $events = {'leased' => __('Leased'), 'released' => __('Released') };
	
	return {
		'name' => __('DHCP'),
		'index' => 'dhcp',
		'titles' => $titles,
		'order' => \@order,
		'tablename' => 'leases',
		'timecol' => 'timestamp',
		'filter' => ['interface', 'mac', 'ip'],
		'events' => $events,
		'eventcol' => 'event'
	};
}

sub logHelper
{
	my $self = shift;

	return (new EBox::DHCPLogHelper);
}

sub _addDHCPService
{
	my $serviceMod = EBox::Global->modInstance('services');

	if (not $serviceMod->serviceExists('name' => 'dhcp')) {
		 $serviceMod->addService('name' => 'dhcp',
			'protocol' => 'udp',
			'sourcePort' => 'any',
			'destinationPort' => 67,
			'internal' => 1,
			'readOnly' => 1);
		
	} else {
		 $serviceMod->setService('name' => 'dhcp',
			'protocol' => 'udp',
			'sourcePort' => 'any',
			'destinationPort' => 67,
			'internal' => 1,
			'readOnly' => 1);

		EBox::info("Not adding dhcp services as it already exists");
	}

    $serviceMod->save();

}

# Returns those model instances attached to the given interface
sub _removeDataModelsAttached
{
    my ($self, $iface) = @_;

    my $manager = EBox::Model::ModelManager->instance();

    # RangeTable/Options/FixedAddressTable
    foreach my $modelName (qw(Options RangeTable FixedAddressTable)) {
        my $model = $manager->model("/dhcp/$modelName/$iface");
        $model->removeAll(1);
    }
}

1;
