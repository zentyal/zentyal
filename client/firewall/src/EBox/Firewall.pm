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

package EBox::Firewall;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::ObjectsObserver EBox::NetworkObserver);

use EBox::Objects;
use EBox::Global;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Order;
use EBox::Gettext;

sub _create
{
	my $class = shift;
	my $self =$class->SUPER::_create(name => 'firewall',
					domain => 'ebox-firewall',
					@_);
	bless($self, $class);
	return $self;
}

## internal utility functions

sub _checkPolicy # (policy, name?)
{
	my $i = shift;
	my $name = shift;
	if ($i eq "deny" || $i eq "allow" || $i eq "global") {
		return 1;
	}
	if (defined($name)) {
		throw EBox::Exceptions::InvalidData('data' => $name,
						    'value' => $i);
	} else {
		return 0;
	}
}

sub _checkAction # (action, name?)
{
	my $i = shift;
	my $name = shift;
	if ($i eq "allow" || $i eq "deny") {
		return 1;
	}
	if (defined($name)) {
		throw EBox::Exceptions::InvalidData('data' => $name,
						    'value' => $i);
	} else {
		return 0;
	}
}

sub _purgeEmptyObject # (object) 
{
	my ($self, $object) = @_;

	if ($object eq '_global') {
		return;
	}
	
	my @array;
	@array = $self->all_dirs("objects/$object/rules");
	(scalar(@array) eq 0) or return;
	@array = $self->all_dirs("objects/$object/services");
	(scalar(@array) eq 0) or return;
	
	if ($self->ObjectPolicy($object) eq 'global') {
		$self->delete_dir("objects/$object");
	}
}


sub _purgeServiceObjects # (service) 
{
	my ($self, $service) = @_;
	foreach my $object(@{$self->ObjectNames}){
		foreach (@{$self->ObjectServices($object)}){
			if ( $_->{name} eq $service ){
				$self->removeObjectService($object, $service);
			}
		}
	}
}

# END internal utility functions

## api functions

sub _regenConfig
{
	my $self = shift;
	use EBox::Iptables;
	my $ipt = new EBox::Iptables;
	$ipt->start();
}

sub _stopService
{
	my $self = shift;
	use EBox::Iptables;
	my $ipt = new EBox::Iptables;
	$ipt->stop();
}

#
# Method: usesObject
#   	
#   	Implements EBox::ObjectsObserver interface
#
sub usesObject # (object) 
{
	my ($self, $object) = @_;
	defined($object) or return undef;
	($object ne "") or return undef;
	return $self->dir_exists("objects/$object");
}

#
# Method: freeObject
#   	
#   	Implements EBox::ObjectsObserver interface
#
sub freeObject # (object) 
{
	my ($self, $object) = @_;
	defined($object) or return;
	($object ne "") or return;
	$self->delete_dir("objects/$object");
}

#
# Method: denyAction 
#
#	Returns the deny action
#
# Returns:
#
#       string - holding the deny action, DROP or REJECT
#
sub denyAction
{
	my $self = shift;
	return $self->get_string("deny");
}

#
# Method: setDenyAction 
#
#	Sets the deny action
#
# Parameters:
#
#	action - 'DROP' or 'REJECT'
#   
# Exceptions:
#
#	InvalidData - action not valid
#
sub setDenyAction # (action) 
{
	my ($self, $action) = @_;
	if ($action ne "DROP" && $action ne "REJECT") {
		throw EBox::Exceptions::InvalidData('data' => __('action'),
						    'value' => $action);
	} elsif ($action eq $self->denyAction()) {
		return;
	}
	$self->set_string("deny", $action);
}

# Method: portRedirections 
#                                               
#       Return the list of port redirections       
#                               
#                               
# Returns:                    
#                                   
#       array ref - contating the port redirections in hash refereces. 
#       Each hash holds the keys 'protocol', 'eport' (extenal port), 
#	'iface' (network intercae), 'ip' (destination address), 'dport'
#	(destination port)
#                                       
#       
sub portRedirections
{
	my $self = shift;
	return $self->array_from_dir("redirections");
}


# Method: addPortRedirection
#
#       Adds a port redirection. Packets entering an interface matching a
#	given port will be redirected to an IP and port.
#   
# Parameters:
#       
#	protocol - tcp|udp
#	ext_port - 1-65535
#       iface - network intercace
#       address - destination address
#       dest_port - destination port
#
# Exceptions:
#       
#       External - External port  already  used
#   
sub addPortRedirection # (protocol, ext_port, interface, address, dest_port) 
{
	my ($self, $proto, $eport, $iface, $address, $dport) = @_;

	checkProtocol($proto, __("protocol"));
	checkIP($address, __("destination address"));
	checkPort($eport, __("external port"));
	checkPort($dport, __("destination port"));

	$self->availablePort($proto, $eport, $iface) or
		throw EBox::Exceptions::External(__x(
		"Port {port} is being used by a service or port redirection.", 
		port => $eport));

	my $id = $self->get_unique_id("r","redirections");

	$self->set_string("redirections/$id/protocol", $proto);
	$self->set_int("redirections/$id/eport", $eport);
	$self->set_string("redirections/$id/iface", $iface);
	$self->set_string("redirections/$id/ip", $address);
	$self->set_int("redirections/$id/dport", $dport);
}


# Method: removePortRedirection
#
#       Removes a port redirection. 
#   
# Parameters:
#       
#	protocol - tcp|udp
#	ext_port - 1-65535
#       iface - network intercace
#
sub removePortRedirection # (protocol, ext_port, interface) 
{
	my ($self, $proto, $eport, $iface) = @_;
	checkProtocol($proto, __("protocol"));
	checkPort($eport, __("external port"));

	my @reds = $self->all_dirs("redirections");
	foreach (@reds) {
		($self->get_string("$_/protocol") eq $proto) or next;
		($self->get_int("$_/eport") eq $eport) or next;
		($self->get_string("$_/iface") eq $iface) or next;
		$self->delete_dir($_);
		return 1;
	}
	return;
}

# Method: removePortRedirectionOnIface
#
#       Removes all the port redirections on a given interface
#   
# Parameters:
#       
#       iface - network intercace
#
sub removePortRedirectionOnIface # (interface) 
{
	my ($self, $iface) = @_;
	my @reds = $self->all_dirs("redirections");
	foreach (@reds) {
		($self->get_string("$_/iface") eq $iface) or next;
		$self->delete_dir($_);
		return 1;
	}
	return;
}

# Method: services
#
#       Returns all the configured services
#   
# Parameters:
#       
#       array ref - FIXME
#
sub services
{
	my $self = shift;
	return $self->array_from_dir("services");
}

# Method: service
#
#	Given a service it returns its configuration
#   
# Parameters:
#
# 	service - string: the name of a service
#
# Returns:
#
#	undef if service does not exists. Otherwise it returns
#	a hash holding these keys: 'protocol', 'name', 'port',
#	'external'
sub service # (name) 
{
	my ($self, $name) = @_;
	checkName($name) or
		throw EBox::Exceptions::Internal(
			__x("Name '{name}' is invalid", name => $name));

	my $service =  $self->hash_from_dir("services/$name");
	if (keys(%{$service})){
		return $service;
	} 
	return undef;
}

# Method: serviceProtocol
#
#	Given a service it returns its protocol 
#   
# Parameters:
#
# 	service - string: the name of a service
#
# Returns:
#
#	undef if service does not exists. Otherwise it returns
#	its protocol: tcp or udp
#
sub serviceProtocol # (service) 
{
	my ($self, $name) = @_;
	defined($name) or return undef;
	($name ne "") or return undef;
	return $self->get_string("services/$name/protocol");
}

# Method: servicePort
#
#	Given a service it returns its port 
#   
# Parameters:
#
# 	service - string: the name of a service
#
# Returns:
#
#	undef if service does not exists. Otherwise it returns
#	its port.
#
sub servicePort # (service) 
{
	my ($self, $name) = @_;
	defined($name) or return undef;
	($name ne "") or return undef;
	return $self->get_int("services/$name/port");
}

# Method: serviceIsInternal
#
#	Given a service it checks if it's internal
#   
# Parameters:
#
# 	service - string: the name of a service
#
# Returns:
#
#	boolean
sub serviceIsInternal # (service) 
{
	my ($self, $name) = @_;
	defined($name) or return undef;
	($name ne "") or return undef;
	return $self->get_bool("services/$name/internal");
}

# Method: availablePort
#
#	Checks if a port is available, i.e: it's not used by any module.
#   
# Parameters:
#
# 	proto - protocol
# 	port - port number
#	interface - interface 
#
# Returns:
#
#	boolean - true if it's available, otherwise undef
#
sub availablePort # (proto, port, interface)
{
	my ($self, $proto, $port, $iface) = @_;
	defined($proto) or return undef;
	($proto ne "") or return undef;
	defined($port) or return undef;
	($port ne "") or return undef;
	my $global = EBox::Global->getInstance();
	my $network = $global->modInstance('network');

	# if it's an internal interface, check all services
	unless ($iface &&
	($network->ifaceIsExternal($iface) || $network->vifaceExists($iface))) {
		foreach (@{$self->services()}){
			if (($self->servicePort($_->{name}) == $port) and 
				($self->serviceProtocol($_->{name}) == $proto)){
				return undef;
			}
		}
	}

	# check for port redirections on the interface, on all internal ifaces
	# if its
	my @ifaces = ();
	if ($iface) {
		push(@ifaces, $iface);
	} else {
		my $tmp = $network->InternalIfaces();
		@ifaces = @{$tmp};
	}
	my $redirs = $self->portRedirections();
	foreach my $ifc (@ifaces) {
		foreach my $red (@{$redirs}) {
			($red->{protocol} eq $proto) or next;
			($red->{iface} eq $ifc) or next;
			($red->{eport} eq $port) and return undef;
		}
	}

	my @mods = @{$global->modInstancesOfType('EBox::FirewallObserver')};
        foreach my $mod (@mods) {
                if ($mod->usesPort($proto, $port, $iface)) {
                        return undef;
                }
        }
	return 1;
}

#
# Method: addService
#
#       Adds a service. This will result in the addition of rules to allow
#	connections to the given service.
#
# Parameters:
#       
#	name - string: name of a service, must nor already exist
#	protocol - protocol (tcp or udp)
#       port - port number
#       boolean - internal service or not
#
# Exceptions:
#       
#       DataExists - local port already used
#	Internal - invalid name
#
sub addService # (name, protocol, port, internal?) 
{
	my ($self, $name, $proto, $port, $internal) = @_;

	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));
	checkProtocol($proto, __("protocol"));
	checkPort($port, __("port"));

	$self->dir_exists("services/$name") and
		throw EBox::Exceptions::DataExists('data' =>__('service'),
						  'value' => $name);

	my @servs = @{$self->all_dirs_base("services")};
	foreach (@servs) {
		($self->get_string("services/$_/protocol") eq $proto) or next;
		($self->get_int("services/$_/port") eq $port) or next;
		throw EBox::Exceptions::DataExists('data' =>'local port',
						  'value' => $port);
	}
	$self->set_string("services/$name/protocol", $proto);
	$self->set_string("services/$name/name", $name);
	$self->set_int("services/$name/port", $port);
	$self->set_bool("services/$name/internal", $internal);
}

#
# Method: removeService
#
#	Removes a service.
#
# Parameters:
#       
#	name - string: name of a service, must nor already exist
#
# Returns:
#
#	boolean - true if deleted, otherwise undef
#
# Exceptions:
#       
#	Internal - invalid name
#
sub removeService # (service) 
{
	my ($self, $name) = @_;
	my $i = 0;
	
	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));
	if ($self->service($name)){
		$self->delete_dir("services/$name");
		$self->removeLocalRedirects($name);
		$self->_purgeServiceObjects($name);
		return 1;
	} else { 
		return undef;	
	}
} 

#
# Method: changeService 
#
#	Changes the configuration of a  service.
#
# Parameters:
#
#	name - string: name of a service, must nor already exist
#	protocol - protocol (tcp or udp)
#       port - port number
#       boolean - internal service or not
#
# Exceptions:
#       
#	Internal - invalid name
#
sub changeService # (service, protocol, port, internal?) 
{
	my ($self, $name, $proto, $port, $internal) = @_;

	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));
	checkProtocol($proto, __("protocol"));
	checkPort($port, __("port"));

	my @servs = @{$self->all_dirs_base("services")};
	foreach (@servs) {
		($_ ne $name) or next;
		($self->get_string("services/$_/protocol") eq $proto) or next;
		($self->get_int("services/$_/port") eq $port) or next;
		throw EBox::Exceptions::DataExists('data' =>'local port',
						  'value' => $port);
	}

	$self->set_string("services/$name/protocol", $proto);
	$self->set_string("services/$name/name", $name);
	$self->set_int("services/$name/port", $port);
	$self->set_bool("services/$name/internal", $internal);
}

#
# Method: localRedirects
#
#	Returns a list of local redirections
#
# Returns:
#       
#	array ref - holding the local redirections
#
sub localRedirects
{
	my $self = shift;
	return $self->array_from_dir("localredirects");
}

#
# Method: addLocalRedirect
#
#	Adds a local redirection. Packets directed at certain port to
#	the local machine are redirected to the given port
#
# Parameters:
#       
#	service - string: name of a service to redirect packets
#       port - port to redirect from 
#
#
sub addLocalRedirect # (service, port) 
{
	my ($self, $name, $port) = @_;
	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));
	checkPort($port, __("port"));

	my $protocol = $self->serviceProtocol($name);
	($protocol && $protocol ne "") or 
		throw EBox::Exceptions::Internal("Unknown service: $name");

	my @redirects = $self->all_dirs("localredirects");
	foreach (@redirects) {
		my $tmpsrv = $self->get_string("$_/service");
		if ($tmpsrv eq $name) {
			if ($self->get_int("$_/port") eq $port) {
				return;
			} else {
				next;
			}
		}
		my $tmpproto = $self->serviceProtocol($tmpsrv);
		($tmpproto eq $protocol) or next;
		if ($self->get_int("$_/port") eq $port) {
			throw EBox::Exceptions::Internal
			("Port $port already redirected to service $tmpsrv");
		}
	}

	my $id = $self->get_unique_id("r","localredirects");

	$self->set_string("localredirects/$id/service", $name);
	$self->set_int("localredirects/$id/port", $port);
}

#
# Method: removeLocalRedirects 
#
#	Removes all local redirections for a service
#
# Parameters:
#       
#	service - string: name of a service to remove local redirections 
#
#
sub removeLocalRedirects # (service) 
{
	my ($self, $name) = @_;
	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));

	my @redirects = $self->all_dirs("localredirects");
	foreach (@redirects) {
		if ($self->get_string("$_/service") eq $name) {
			$self->delete_dir("$_");
		}
	}
}

#
# Method: removeLocalRedirect 
#
#	Removes a local redirection for a service
#
# Parameters:
#       
#	service - string: name of a service to remove local redirections 
#
#
sub removeLocalRedirect # (service, port) 
{
	my ($self, $name, $port) = @_;
	checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));

	my @redirects = $self->all_dirs("localredirects");
	foreach (@redirects) {
		($self->get_string("$_/service") eq $name) or next;
		($self->get_int("$_/port") eq $port) or next;
		$self->delete_dir("$_");
	}
}

# Method: usesIface 
#
#       Implements EBox::NetworkObserver interface. 
#   
#
sub usesIface # (iface)
{
	my ($self, $iface) = @_;
	my @reds = $self->all_dirs("redirections");
	foreach (@reds) {
		if ($self->get_string("$_/iface") eq $iface) {
			return 1;
		}
	}
	return undef;
}

# Method: ifaceMethodChanged 
#
#       Implements EBox::NetworkObserver interface. 
#   
#
sub ifaceMethodChanged # (iface, oldmethod, newmethod)
{
	my ($self, $iface, $oldm, $newm) = @_;
	
	($newm eq 'static') and return undef;
	($newm eq 'dhcp') and return undef;

	return $self->usesIface($iface);
}

# Method: vifaceDelete
#
#       Implements EBox::NetworkObserver interface. 
#   
#
sub vifaceDelete # (iface, viface)
{
	my ($self, $iface, $viface) = @_;
	return $self->usesIface("$iface:$viface");
}

# Method: freeIface
#
#       Implements EBox::NetworkObserver interface. 
#   
#
sub freeIface # (iface)
{
	my ($self, $iface) = @_;
	$self->removePortRedirectionOnIface($iface);
}

# Method: freeViface
#
#       Implements EBox::NetworkObserver interface. 
#   
#
sub freeViface # (iface, viface)
{
	my ($self, $iface, $viface) = @_;
	$self->removePortRedirectionOnIface("$iface:$viface");
}

#    Method: ObjectPolicy
#	
#	Returns the default policy for a given object
#
#    Parameters:
#
#	object - string: name of the object
#
#    Returns:
#
#	string -  the default policy for the object (global|deny|allow)
#
sub ObjectPolicy # (object) 
{
	my ($self, $name) = @_;

	if ($name ne '_global') {
		checkName($name) or throw EBox::Exceptions::Internal(
				__x("Name '{name}' is invalid", name => $name));
	}

	$self->dir_exists("objects/$name") or return 'global';
	return $self->get_string("objects/$name/policy");
}

sub _createObject # (object) 
{
	my ($self, $object) = @_;
	my $objects = EBox::Global->modInstance('objects');

	if ($object ne '_global') {
		$objects->objectExists($object) or
			throw EBox::Exceptions::DataNotFound(
							'data' => __("object"),
							'value' => $object);
	}

	$self->dir_exists("objects/$object") and return;
	$self->set_string("objects/$object/policy", 'global');
}

# Method: setObjectPolicy
#	
#	Sets the default policy for a given object
#
# Parameters:
#
#	object - string: name of the object
#	policy - default policy for the object
#
# Returns:
#
#	string -  the default policy for the object (global|deny|allow)
#
# Exceptios:
#
#	DataNotFound - object does not exists
sub setObjectPolicy # (object, policy) 
{
	my ($self, $object, $policy) = @_;
	my $objects = EBox::Global->modInstance('objects');

	_checkPolicy($policy, __("policy"));
	if ($object ne '_global') {
		$objects->objectExists($object) or
			throw EBox::Exceptions::DataNotFound(
							'data' => __("object"),
							'value' => $object);
	}
	if ($policy eq $self->ObjectPolicy($object)) {
		return;
	}
	$self->set_string("objects/$object/policy", $policy);
	$self->_purgeEmptyObject($object);
}

# Method: removeObjectPolicy
#	
#	Removes a rule from an object
#
# Parameters:
#
#	object - string: name of the object
#	rule_id - string: identifier of the rule
#
sub removeObjectRule # (object, rule_id)
{
	my ($self, $object, $rule) = @_;

	$self->ObjectRuleExists($object, $rule) or return;
	$self->delete_dir("objects/$object/rules/$rule");
	$self->_purgeEmptyObject($object);
	return 1;
}

# Method: removeFwdPolicy
#	
#	Removes a rule form the forward chain
#
# Parameters:
#
#	rule_id - string: identifier of the rule
#
sub removeFwdRule # (rule_id)
{
	my ($self, $rule) = @_;

	$self->FwdRuleExists($rule) or return;
	$self->delete_dir("fwdrules/$rule");
	return 1;
}

# Method: ObjectRuleExists
#	
#	Checks if a given object contains a certain rule
#
# Parameters:
#
#	object - string: name of the object
#	rule_id - string: identifier of the rule
#
# Returns:
#
#	boolean - True if exists, otherwise undef
sub ObjectRuleExists # (object, rule_id) 
{
	my ($self, $object, $rule) = @_;
	(defined($object) && $object ne "") or return undef;
	(defined($rule) && $rule ne "") or return undef;
	return $self->dir_exists("objects/$object/rules/$rule");
}

# Method: FwdRuleExists
#	
#	Checks if a  forward rule exists
#
# Parameters:
#
#	rule_id - string: identifier of the rule
#
# Returns:
#
#	boolean - True if exists, otherwise undef

sub FwdRuleExists # (rule_id)
{
	my ($self, $rule) = @_;
	(defined($rule) && $rule ne "") or return undef;
	return $self->dir_exists("fwdrules/$rule");
}

# Method: changeObjectRule 
#	
#	Changes a certain rule for an object	
#
# Parameters:
#
# 	object - string: name of the object
# 	rule - string: name of the rule
# 	action - string: action (deny|allow)
# 	protocol - string: protocol (tcp|udp)
#	port - string: port (1-65535)
#	addr - string: address (cidr address or empty) [optional]
#	mask - string: mask (1-32 or empty) [optional]
#	active - string: active (yes|no)
#
sub changeObjectRule #(object, rule, action, protocol, port, addr, mask, active)
{
	my ($self, $object, $rule, $action, $protocol, $port, $addr, $mask,
		   $active) = @_;

	_checkAction($action, __("policy"));

	if (defined($protocol) && $protocol ne "") {
		checkProtocol($protocol, __("protocol"));
	} elsif (defined($port) && $port ne "") {
		throw EBox::Exceptions::External(__('Port cannot be set if no'.
						' protocol is selected.'));
	}

	if (defined($port) && $port ne "") {
		checkPort($port, __("port"));
	}
	if (defined($addr) && $addr ne "") {
		checkCIDR("$addr/$mask", __("address"));
	}

	$self->ObjectRuleExists($object, $rule) or return;

	$self->set_string("objects/$object/rules/$rule/name", $rule);
	$self->set_string("objects/$object/rules/$rule/action", $action);
	$self->set_bool("objects/$object/rules/$rule/active", $active);

	if (defined($protocol) && $protocol ne "") {
		$self->set_string("objects/$object/rules/$rule/protocol", 
					$protocol);
	} else {
		$self->unset("objects/$object/rules/$rule/protocol");
	}

	if (defined($port) && $port ne "") {
		$self->set_int("objects/$object/rules/$rule/port", $port);
	} else {
		$self->unset("objects/$object/rules/$rule/port");
	}

	if (defined($addr) && $addr ne "") {
		$self->set_string("objects/$object/rules/$rule/address", $addr);
	}
	if (defined($mask) && $mask ne "") {
		$self->set_int("objects/$object/rules/$rule/mask", $mask);
	}
}

# Method: changeFwdtRule 
#	
#	Changes a certain forward rule 
#
# Parameters:
#
# 	rule - string: name of the rule
# 	protocol - string: protocol (tcp|udp)
#	saddr - source address
#	smask - source network mask 
#	sportfrom - source port from
#	sportto - source port to
#	daddr - destination address
#	dmask - destination network mask 
#	dportfrom - destination port from
#	dportto - destination port to
#	nsaddr - FIXME  source address
#	nsport - FIXME source port
#	ndaddr - FIXME destiantion address
#	ndport - FIXME destination port
# 	action - string: action (deny|allow)
#	active - string: active (yes|no)
#
sub changeFwdRule # ()
{
	my ($self, $rule, $proto, $saddr, $smask, $sportfrom, $sportto, $daddr,
	    $dmask, $dportfrom, $dportto, $nsaddr, $nsport, $ndaddr, $ndport,
	    $action, $active) = @_;
	    
	_checkAction($action, __("action"));

	if (defined($proto) and $proto ne "") {
		checkProtocol($proto, __("protocol"));
	} elsif ((defined($sportfrom) and $sportfrom ne '') or
		 (defined($dportfrom) and $dportfrom ne '') or
		 (defined($sportto) and $sportto ne '') or
		 (defined($dportto) and $dportto ne '')) {
		throw EBox::Exceptions::External(__('Port cannot be set if no'.
						' protocol is selected.'));
	} 

	if (defined($sportfrom) && $sportfrom ne "") {
		checkPort($sportfrom, __("source port"));
	}
	if (defined($dportfrom) && $dportfrom ne "") {
		checkPort($dportfrom, __("destination port"));
	}
	if (defined($sportto) && $sportto ne "") {
		checkPort($sportto, __("source port"));
	}
	if (defined($dportto) && $dportto ne "") {
		checkPort($dportto, __("destination port"));
	}

	if (defined($saddr) && $saddr ne "") {
		checkCIDR("$saddr/$smask", __("source address"));
	}
	if (defined($daddr) && $daddr ne "") {
		checkCIDR("$daddr/$dmask", __("source address"));
	}

	$self->set_string("fwdrules/$rule/action", $action);
	$self->set_bool("fwdrules/$rule/active", $active);
	$self->set_bool("fwdrules/$rule/nsaddr", $nsaddr);
	$self->set_bool("fwdrules/$rule/ndaddr", $ndaddr);
	$self->set_bool("fwdrules/$rule/nsport", $nsport);
	$self->set_bool("fwdrules/$rule/ndport", $ndport);


	if (defined($proto) && $proto ne "") {
		$self->set_string("fwdrules/$rule/protocol", $proto);
	} else {
		$self->unset("fwdrules/$rule/protocol");
	}

	if (defined($sportfrom) && $sportfrom ne "") {
		$self->set_int("fwdrules/$rule/sportfrom", $sportfrom);
	} else {
		$self->unset("fwdrules/$rule/sportfrom");
	}

	if (defined($sportto) && $sportto ne "") {
		$self->set_int("fwdrules/$rule/sportto", $sportto);
	} else {
		$self->unset("fwdrules/$rule/sportto");
	}

	if (defined($dportfrom) && $dportfrom ne "") {
		$self->set_int("fwdrules/$rule/dportfrom", $dportfrom);
	} else {
		$self->unset("fwdrules/$rule/dportfrom");
	}

	if (defined($dportto) && $dportto ne "") {
		$self->set_int("fwdrules/$rule/dportto", $dportto);
	} else {
		$self->unset("fwdrules/$rule/dportto");
	}

	if (defined($saddr) && $saddr ne "") {
		$self->set_string("fwdrules/$rule/saddress", $saddr);
	} else {
		$self->unset("fwdrules/$rule/saddress");
	}

	if (defined($smask) && $smask ne "") {
		$self->set_int("fwdrules/$rule/smask", $smask);
	} else {
		$self->unset("fwdrules/$rule/smask");
	}

	if (defined($daddr) && $daddr ne "") {
		$self->set_string("fwdrules/$rule/daddress", $daddr);
	} else {
		$self->unset("fwdrules/$rule/daddress");
	}

	if (defined($dmask) && $dmask ne "") {
		$self->set_int("fwdrules/$rule/dmask", $dmask);
	} else {
		$self->unset("fwdrules/$rule/dmask");
	}
}

#
# Method: OutputRules
#
#	Returns the output rules
#
# Return:
#
#	array ref - each element contains FIXME
sub OutputRules
{
	my $self = shift;
	return $self->array_from_dir("rules/output");
}

# Method: removeOutputRule
#
#	Removes an output rule
#
# Parameters:
#
# 	protocol - string: protocol (tcp|udp)
# 	port - string: port number
#
# Returns:
#
#	boolean - true if it's deleted, otherwise undef
sub removeOutputRule # (protocol, port)
{
	my ($self, $protocol, $port) = @_;

	checkProtocol($protocol, __("protocol"));
	checkPort($port, __("port"));

	my @rules = $self->all_dirs("rules/output");
	foreach (@rules) {
		($self->get_string("$_/protocol") eq $protocol) or next;
		($self->get_int("$_/port") eq $port) or next;
		$self->delete_dir($_);
		return 1;
	}
	return;
}

# Method: addOutputRule 
#
#	Removes an output rule
#
# Parameters:
#
# 	protocol - string: protocol (tcp|udp)
# 	port - string: port number
sub addOutputRule # (protocol, port) 
{
	my ($self, $protocol, $port) = @_;

	checkProtocol($protocol, __("protocol"));
	checkPort($port, __("port"));

	$self->removeOutputRule($protocol, $port);

	my $id = $self->get_unique_id("r","rules/output");

	$self->set_string("rules/output/$id/protocol", $protocol);
	$self->set_int("rules/output/$id/port", $port);
}

# Method: addFwdRule 
#	
#	Add a forward rule
#
# Parameters:
#
# 	protocol - string: protocol (tcp|udp)
#	saddr - source address
#	smask - source network mask 
#	sportfrom - source port from
#	sportto - source port to
#	daddr - destination address
#	dmask - destination network mask 
#	dportfrom - destination port from
#	dportto - destination port to
#	nsaddr - FIXME source address
#	nsport - FIXME  source port
#	ndaddr - FIXME destiantion address
#	ndport - FIXME destination port
# 	action - string: action (deny|allow)
#	active - string: active (yes|no)
#
sub addFwdRule # 
{
	my ($self, $proto, $saddr, $smask, $sportfrom, $sportto, $daddr, $dmask,
	$dportfrom, $dportto, $nsaddr, $nsport, $ndaddr, $ndport, $action) = @_;

	_checkAction($action, __("action"));

	if (defined($proto) and $proto ne "") {
		checkProtocol($proto, __("protocol"));
	} elsif ((defined($sportfrom) and $sportfrom ne '') or
		 (defined($dportfrom) and $dportfrom ne '') or
		 (defined($sportto) and $sportto ne '') or
		 (defined($dportto) and $dportto ne '')) {
		throw EBox::Exceptions::External(__('Port cannot be set if no'.
						' protocol is selected.'));
	} 

	if (defined($sportfrom) && $sportfrom ne "") {
		checkPort($sportfrom, __("source port"));
	}
	if (defined($dportfrom) && $dportfrom ne "") {
		checkPort($dportfrom, __("destination port"));
	}
	if (defined($sportto) && $sportto ne "") {
		checkPort($sportto, __("source port"));
	}
	if (defined($dportto) && $dportto ne "") {
		checkPort($dportto, __("destination port"));
	}

	if (defined($saddr) && $saddr ne "") {
		checkCIDR("$saddr/$smask", __("source address"));
	}
	if (defined($daddr) && $daddr ne "") {
		checkCIDR("$daddr/$dmask", __("source address"));
	}

	my $id = $self->get_unique_id("x","fwdrules");

	my $order = $self->_lastFwdRule() + 1;

	$self->set_string("fwdrules/$id/name", $id);
	$self->set_string("fwdrules/$id/action", $action);
	$self->set_bool("fwdrules/$id/active", 1);
	$self->set_int("fwdrules/$id/order", $order);

	$self->set_bool("fwdrules/$id/nsaddr", $nsaddr);
	$self->set_bool("fwdrules/$id/ndaddr", $ndaddr);
	$self->set_bool("fwdrules/$id/nsport", $nsport);
	$self->set_bool("fwdrules/$id/ndport", $ndport);

	if (defined($proto) && $proto ne "") {
		$self->set_string("fwdrules/$id/protocol", $proto);
	}

	if (defined($sportfrom) && $sportfrom ne "") {
		$self->set_int("fwdrules/$id/sportfrom", $sportfrom);
	}
	if (defined($dportfrom) && $dportfrom ne "") {
		$self->set_int("fwdrules/$id/dportfrom", $dportfrom);
	}

	if (defined($sportto) && $sportto ne "") {
		$self->set_int("fwdrules/$id/sportto", $sportto);
	}
	if (defined($dportto) && $dportto ne "") {
		$self->set_int("fwdrules/$id/dportto", $dportto);
	}

	if (defined($saddr) && $saddr ne "") {
		$self->set_string("fwdrules/$id/saddress", $saddr);
	}
	if (defined($smask) && $smask ne "") {
		$self->set_int("fwdrules/$id/smask", $smask);
	}

	if (defined($daddr) && $daddr ne "") {
		$self->set_string("fwdrules/$id/daddress", $daddr);
	}
	if (defined($dmask) && $dmask ne "") {
		$self->set_int("fwdrules/$id/dmask", $dmask);
	}
}

# Method: changeObjectRule 
#	
#	Changes a certain rule for an object	
#
# Parameters:
#
# 	object - string: name of the object
# 	action - string: action (deny|allow)
# 	protocol - string: protocol (tcp|udp)
#	port - string: port (1-65535)
#	addr - string: address (cidr address or empty) [optional]
#	mask - string: mask (1-32 or empty) [optional]
#
sub addObjectRule # (object, action, protocol, port, address, mask) 
{
	my ($self, $object, $action, $protocol, $port, $addr, $mask) = @_;

	_checkAction($action, __("policy"));

	if (defined($protocol) && $protocol ne "") {
		checkProtocol($protocol, __("protocol"));
	} elsif (defined($port) && $port ne "") {
		throw EBox::Exceptions::External(__('Port cannot be set if no'.
						' protocol is selected.'));
	}

	if (defined($port) && $port ne "") {
		checkPort($port, __("port"));
	}

	if (defined($addr) && $addr ne "") {
		checkCIDR("$addr/$mask", __("address"));
	}

	my $objects = EBox::Global->modInstance('objects');
	if ($object ne '_global') {
		$objects->objectExists($object) or
			throw EBox::Exceptions::DataNotFound(
							'data' => __("object"),
							'value' => $object);
	}

	$self->dir_exists("objects/$object") or $self->_createObject($object);

	my $id = $self->get_unique_id("x","objects/$object/rules");

	my $order = $self->_lastObjectRule($object) + 1;
	$self->set_string("objects/$object/rules/$id/name", $id);
	$self->set_string("objects/$object/rules/$id/action", $action);
	$self->set_bool("objects/$object/rules/$id/active", 1);
	$self->set_int("objects/$object/rules/$id/order", $order);
	if (defined($protocol) && $protocol ne "") {
		$self->set_string("objects/$object/rules/$id/protocol", 
				$protocol);
	}
	if (defined($port) && $port ne "") {
		$self->set_int("objects/$object/rules/$id/port", $port);
	}
	if (defined($addr) && $addr ne "") {
		$self->set_string("objects/$object/rules/$id/address", $addr);
	}
	if (defined($mask) && $mask ne "") {
		$self->set_int("objects/$object/rules/$id/mask", $mask);
	}
}

# Method: removeObjectService
#
#	Removes a service form an object
#
# Parameters:
#
#	object - name of the object
#	service - name of the service to remove
#
#
sub removeObjectService # (object, service) 
{
	my ($self, $object, $service) = @_;

	my $objects = EBox::Global->modInstance('objects');
	if ($object ne '_global') {
		$objects->objectExists($object) or
			throw EBox::Exceptions::DataNotFound(
							'data' => __("object"),
							'value' => $object);
	}
	checkName($service) or throw EBox::Exceptions::Internal(
			"Name $service is invalid");

	$self->delete_dir("objects/$object/services/$service");
	$self->_purgeEmptyObject($object);
	return 1;
}


# Method: setObjectService
#
#	Sets a service for an object
#
# Parameters:
#	object  - string: name of the object
# 	service - string: name of the service
# 	policy - string: policy (allow|deny)
sub setObjectService # (object, service, policy) 
{
	my ($self, $object, $srv, $policy) = @_;

	_checkAction($policy, __("policy"));
	my $objects = EBox::Global->modInstance('objects');
	if ($object ne '_global') {
		$objects->objectExists($object) or
			throw EBox::Exceptions::DataNotFound(
							'data' => __("object"),
							'value' => $object);
	}

	$self->dir_exists("services/$srv") or return;
	$self->dir_exists("objects/$object") or $self->_createObject($object);
	$self->set_string("objects/$object/services/$srv/policy", $policy);
	$self->set_string("objects/$object/services/$srv/name", $srv);
}


# Method: Object
#
#	Returns the configuration for a given object
#
# Parameters: 
#
#	object - name of the object
#
# Returns:
#
#	A hash reference containing:
#
#	policy - default policy
#	name - name of the object
#	rule - array ref holding  the object's rules
#	servicepol - array ref holding the configured services for the object
sub Object # (name) 
{
	my ($self, $name) = @_;
	my $hash = {};
	$hash->{policy} = $self->ObjectPolicy($name);
	$hash->{name} = $name;
	$hash->{rule} = $self->array_from_dir("objects/$name/rules");
	$hash->{servicepol} = $self->array_from_dir("objects/$name/services");
	return $hash;
}

sub _objectRuleNumber # (object, rule) 
{
	my ($self, $object, $rule) = @_;
	return $self->get_int("objects/$object/rules/$rule/order");
}

sub _objectRulesOrder # (object) 
{
	my ($self, $name) = @_;
	$self->dir_exists("objects/$name/rules") or return undef;
	return new EBox::Order($self, "objects/$name/rules");
}

sub _fwdRulesOrder
{
	my $self = shift;
	return new EBox::Order($self, "fwdrules");
}

sub _fwdRuleNumber # (rule)
{
	my ($self, $rule) = @_;
	return $self->get_int("fwdrules/$rule/order");
}

# Method: ObjectRuleUp
#
#	It moves up a given rule for an object
#
# Parameters: 
#
#	object - name of the object
#	rule - rule to move up
#
sub ObjectRuleUp # (object, rule) 
{
	my ($self, $object, $rule) = @_;
	my $order = $self->_objectRulesOrder($object);
	defined($order) or return;
	my $num = $self->_objectRuleNumber($object, $rule);
	if ($num == 0) {
		return;
	}

	my $prev = $order->prevn($num);
	$order->swap($num, $prev);
}

# Method: FwdRuleUp 
#
#	It moves up a given forward rule 
#
# Parameters: 
#
#	rule - rule to move up
#
sub FwdRuleUp # (rule)
{
	my ($self, $rule) = @_;
	my $order = $self->_fwdRulesOrder();
	defined($order) or return;
	my $num = $self->_fwdRuleNumber($rule);
	if ($num == 0) {
		return;
	}
	my $prev = $order->prevn($num);
	$order->swap($num, $prev);
}

# Method: ObjectRuleDown
#
#	It moves down a given rule for an object
#
# Parameters: 
#
#	object - name of the object
#	rule - rule to move down
#
sub ObjectRuleDown # (object, rule) 
{
	my ($self, $object, $rule) = @_;
	my $order = $self->_objectRulesOrder($object);
	defined($order) or return;
	my $num = $self->_objectRuleNumber($object, $rule);
	if ($num == 0) {
		return;
	}

	my $nextn = $order->nextn($num);
	$order->swap($num, $nextn);
}

# Method: FwdRuleDown
#
#	It moves down a given forward rule 
#
# Parameters: 
#
#	rule - rule to move down
#
sub FwdRuleDown # (rule)
{
	my ($self, $rule) = @_;
	my $order = $self->_fwdRulesOrder();
	defined($order) or return;
	my $num = $self->_fwdRuleNumber($rule);
	if ($num == 0) {
		return;
	}
	my $nextn = $order->nextn($num);
	$order->swap($num, $nextn);
}

# Method: ObjectRules 
#
#	Returns the set rules for an object
#
# Parameters: 
#
#	object - name of the object
#
# Returns:
#
#	array ref - each element contains a hash with the keys 'name', 'action'
#	, 'protocol', 'address', 'mask', 'active'
sub ObjectRules # (object) 
{
	my ($self, $name) = @_;
	my $order = $self->_objectRulesOrder($name);
	defined($order) or return undef;
	my @rules = @{$order->list};
	my @array = ();
	foreach (@rules) {
		push(@array, $self->hash_from_dir($_));
	}
	return \@array;
}

# Method: FwdRule 
#
#	Returns the configuration for a given rule
#
# Returns:
#
#	A hash reference holding:
#
# 	protocol - string: protocol (tcp|udp)
#	saddr - source address
#	smask - source network mask 
#	sportfrom - source port from
#	sportto - source port to
#	daddr - destination address
#	dmask - destination network mask 
#	dportfrom - destination port from
#	dportto - destination port to
#	nsaddr - FIXME source address
#	nsport - FIXME  source port
#	ndaddr - FIXME destiantion address
#	ndport - FIXME destination port
# 	action - string: action (deny|allow)
#	active - string: active (yes|no)
#
sub FwdRule # (rule)
{
	my ($self, $rulename) = @_;
	my $r = $self->hash_from_dir("fwdrules/$rulename");
	defined($r) or throw EBox::Exceptions::External(__('Rule not found'));
	return $r;
}

#
# Method: FwdRules
#
#	Returns the forward rules
#
# Return:
#
#	array ref - each element contains the same output hash as
#	<FwdRule> return value.
#
sub FwdRules
{
	my $self = shift;
	my $order = $self->_fwdRulesOrder();
	defined($order) or return undef;
	my @rules = @{$order->list};
	my @array = ();
	foreach (@rules) {
		push(@array, $self->hash_from_dir($_));
	}
	return \@array;
}

sub _lastObjectRule # (object) 
{
	my ($self, $name) = @_;
	my $order = $self->_objectRulesOrder($name);
	defined($order) or return 0;
	return $order->highest;
}

sub _lastFwdRule
{
	my $self = shift;
	my $order = $self->_fwdRulesOrder();
	defined($order) or return 0;
	return $order->highest;
}

# Method: ObjectServices
#	
#	Returns the services for a given object
#
# Returns: 
#
#	array ref - holding the services 
sub ObjectServices # (object) 
{
	my ($self, $name) = @_;
	return $self->array_from_dir("objects/$name/services");
}

# Method: ObjectServices
#	
#	Returns all the object names
#
# Returns: 
#
#	array ref - holding the names
#
sub ObjectNames
{
	my $self = shift;
	return $self->all_dirs_base("objects");
}


# Method: menu 
#
#       Overrides EBox::Module method.
#   
sub menu
{
	my ($self, $root) = @_;

	my $folder = new EBox::Menu::Folder('name' => 'Firewall',
					    'text' => __('Firewall'),
					    'order' => 4);

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/Filter',
					  'text' => __('Packet Filter')));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/Redirects',
					  'text' => __('Redirects')));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/FwdRules',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/FwdRuleEdit',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/FwdRule',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/Object',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/Objects',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/ObjectPolicy',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/ObjectRule',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/ObjectService',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Firewall/Redirection',
					  'text' => ''));

	$root->add($folder);
}

1;
