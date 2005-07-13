# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::IPSec;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::FirewallObserver);

use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Config;
use EBox::Sudo qw( :all );
use File::Path;
use File::Copy;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::InvalidData;
use EBox::IPSecFirewall;
use EBox::Summary::Module;
use EBox::Summary::Section;
use EBox::Summary::Value;
use EBox::Summary::Status;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Gettext;

use constant IPSEC => "/usr/sbin/ipsec";
use constant IPSECCONFFILE => "/etc/ipsec.conf";
use constant IPSECSECRETS => "/etc/ipsec.secrets";
use constant IPSECINIT => "/etc/init.d/ipsec";
use constant PLUTOPIDFILE => "/var/run/pluto.pid";

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'ipsec', 
						domain => 'ebox-ipsec', 
						@_);
	bless($self, $class);
	unless (-f EBox::Config::conf . "/ipsecrsa") {
		mkdir(EBox::Config::conf . "/ipsecrsa", 0700);
	}
	return $self;
}

sub _checkAuthMethod # (string, name?)
{
	my ($string, $name) = @_;
	unless ($string) {
		if ($name) {
			throw EBox::Exceptions::DataMissing(
				'data' => $name);
		} else {
			return undef;
		}
	}
	if (($string ne 'rsa') and ($string ne 'sharedsecret')) {
		if ($name) {
			throw EBox::Exceptions::InvalidData(
				'data' => $name, 'value' => $string);
		} else {
			return undef;
		}
	}
	return 1;
}

## api functions

sub isRunning
{
	my $self = shift;
	(-f PLUTOPIDFILE) or return undef;
	unless ($self->pidFileRunning(PLUTOPIDFILE)) {
		my $log = EBox::Global->logger;
		$log->error("IPSec daemon died, file ". PLUTOPIDFILE . 
			"exists and daemon is not running");
		root("/bin/rm -f " . PLUTOPIDFILE);
		return undef;
	}
	return 1;
}

# Method: addWarriorConn 
#
#	Adds a road warrior connection
#
# Parameters:
#
#       name - connection name
#	localsubnet - local subnetwork which will be created
#	localsubnetmask - local subnetwork mask which will be create
#	remotesubnet - remote subnetwork which will be allowed  
#	remotesubnetmask - remote subnetwork mask 
#	localrsa - local rsa key to be used with this connection
#	remoteid - remote connection identifier
#	remotersa - remote public rsa key 
#
sub addWarriorConn # (name, iface, localsubnet, localsubnetmask, remotesubnet
		#	remotesubnetmask, localrsa, remoteid, remotersa)
{
	my ($self, $name, $iface, $lnet, $lmask, $rnet, $rmask, $lrsa, $rid, 
		$rrsa) = @_;

	checkCIDR("$lnet/$lmask", __("local subnet"));
	checkCIDR("$rnet/$rmask", __("remote subnet"));

	defined($lrsa) or throw EBox::Exceptions::DataMissing
					('data' => __('RSA key ID'));
	my $pubkey = $self->getRSAPublicKey($lrsa);
	checkDomainName($rid, __('remote ID'));
	unless ($rrsa and ($rrsa ne '')) {
		throw EBox::Exceptions::DataMissing
			('data' => __('remote RSA key'));
	}

	(defined($name) and $name ne '') or throw EBox::Exceptions::DataMissing(
					'data' => __("connection name"));

	my $network = EBox::Global->modInstance('network');
	$network->ifaceExists($iface) or throw EBox::Exceptions::DataNotFound
					('data' => __('network interface'),
					'value' => __($iface));

	my $id = $self->get_unique_id('w', 'roadwarrior');
	$self->set_string("roadwarrior/$id/name", $name);
	$self->set_string("roadwarrior/$id/iface", $iface);
	$self->set_string("roadwarrior/$id/lnet", $lnet);
	$self->set_string("roadwarrior/$id/lmask", $lmask);
	$self->set_string("roadwarrior/$id/rnet", $rnet);
	$self->set_string("roadwarrior/$id/rmask", $rmask);
	$self->set_string("roadwarrior/$id/lid", $lrsa);
	$self->set_string("roadwarrior/$id/rid", $rid);
	$self->set_string("roadwarrior/$id/rrsa", $rrsa);
	$self->set_bool("roadwarrior/$id/enabled", 1);
}

# Method: addStaticConn
#
#	Adds a static connection
#
# Parameters:
#
#       name - connection name
#	iface - interface 
#	localsubnet - local subnetwork which will be created
#	localsubnetmask - local subnetwork mask which will be create
#	remoteIP - remote IP to connect
#	remoteSubnet- remote subnetwork which will be created
#	remotesubnetmask - remote subnetwork mask 
#	authmethod - sort of authentication
#	authinfo - authentication info
#	remoteid - (Optional) remote connection identifier
#	remotersa - (Optional) remote public rsa key 
#
sub addStaticConn # (name, iface, localsubnet, localsubnetmask, remoteIP,
			# remoteSubnet, remotesubnetmask, authmethod, authinfo,
			# remoteid?, remotersa?)
{
	my ($self, $name, $iface, $lnet, $lmask, $rIP, $rnet, $rmask, 
		$authmethod, $authinfo, $remoteid, $remotersa) =@_;

	checkCIDR("$lnet/$lmask", __("local subnet"));
	checkCIDR("$rnet/$rmask", __("remote subnet"));
	checkIP($rIP, __("remote IP address"));
	_checkAuthMethod($authmethod, __('authentication method'));

	if ($authmethod eq 'rsa') {
		defined($authinfo) or throw EBox::Exceptions::DataMissing
						('data' => __('RSA key ID'));
		my $pubkey = $self->getRSAPublicKey($authinfo);
		checkDomainName($remoteid, __('remote ID'));
		unless ($remotersa and ($remotersa ne '')) {
			throw EBox::Exceptions::DataMissing
					('data' => __('remote RSA key'));
		}
	} else {
		defined($authinfo) or throw EBox::Exceptions::DataMissing
						('data' => __('shared secret'));
		($authinfo ne '') or throw EBox::Exceptions::DataMissing
						('data' => __('shared secret'));
	}


	(defined($name) and $name ne '') or throw EBox::Exceptions::External(
						__("Connection name is empty"));

	my $network = EBox::Global->modInstance('network');
	$network->ifaceExists($iface) or throw EBox::Exceptions::DataNotFound
					('data' => __('network interface'),
					'value' => __($iface));


	my $id = $self->get_unique_id('c', 'static');
	$self->set_string("static/$id/name", $name);
	$self->set_string("static/$id/iface", $iface);
	$self->set_string("static/$id/lnet", $lnet);
	$self->set_string("static/$id/lmask", $lmask);
	$self->set_string("static/$id/rIP", $rIP);
	$self->set_string("static/$id/rnet", $rnet);
	$self->set_string("static/$id/rmask", $rmask);
	$self->set_string("static/$id/authmethod", $authmethod);
	$self->set_string("static/$id/authinfo", $authinfo);
	if ($authmethod eq 'rsa') {
		$self->set_string("static/$id/remoteid", $remoteid);
		$self->set_string("static/$id/remotersa", $remotersa);
	}
	$self->set_bool("static/$id/enabled", 1);
}

sub _dump_to_file # (dir?)
{
	my ($self, $dir) = @_;
	$self->SUPER::_dump_to_file($dir);
	($dir) or $dir = EBox::Config::conf;
	my $origdir = EBox::Config::conf . "/ipsecrsa";
	if ( -e "$dir/ipsecrsa.bak") {
		rmtree("$dir/ipsecrsa.bak") or throw EBox::Exceptions::Internal(
			__('Error while removing old rsa keys backup'));
	}
	mkdir("$dir/ipsecrsa.bak", 0700) or throw EBox::Exceptions::Internal(
			__('Error while making backup dir for rsa keys'));
	my @keys = @{$self->listRSAKeys()};
	foreach my $key (@keys) {
		next unless (-f "$origdir/$key");
		copy("$origdir/$key", "$dir/ipsecrsa.bak") or
			throw EBox::Exceptions::Internal(
				__('Error while backing up rsa keys'));
	}
}

sub _load_from_file # (dir?)
{
	my ($self, $dir) = @_;
	$self->SUPER::_load_from_file($dir);
	($dir) or $dir = EBox::Config::conf;
	my $destdir = EBox::Config::conf . "/ipsecrsa";
	( -d "$dir/ipsecrsa.bak") or
		throw EBox::Exceptions::Internal(
			__('rsa keys backup not found'));
	if ( -e "$destdir") {
		rmtree($destdir) or throw EBox::Exceptions::Internal(
			__('Error while removing rsa keys'));
	}
	mkdir("$destdir", 0700) or throw EBox::Exceptions::Internal(
			__('Error while making dir for rsa keys'));

	my @keys = @{$self->listRSAKeys()};
	foreach my $key (@keys) {
		next unless (-f "$dir/ipsecrsa.bak/$key");
		copy("$dir/ipsecrsa.bak/$key", "$destdir") or
			throw EBox::Exceptions::Internal(
				__('Error while restoring rsa keys'));
	}
}

#
# Method: removeStaticConn
#
#	Removes a static connection
#
# Parameters:
#
#       id - connection identifier
#
sub removeStaticConn # (id)
{
	my ($self, $id) = @_;
	checkName($id) or throw EBox::Exceptions::Internal(__('Invalid id.'));
	$self->delete_dir("static/$id");
}

#
# Method: removeWarriorConn
#
#	Removes a road warrior connection
#
# Parameters:
#
#       id - connection identifier
#
sub removeWarriorConn # (id)
{
	my ($self, $id) = @_;
	checkName($id) or throw EBox::Exceptions::Internal(__('Invalid id.'));
	$self->delete_dir("roadwarrior/$id");
}

#
# Method: staticConnEnable
#
#	Enable/disable a static connection
#
# Parameters:
#
#       bool - true to enable, false to disable
#
sub staticConnEnable # (id, bool)
{
	my ($self, $id, $enable) = @_;
	my $name = $self->get_string("static/$id/name");
	defined($name) or return;
	$self->set_bool("static/$id/enable", $enable);
}

#
# Method: warriorConnEnable
#
#	Enable/disable a road warrior connection
#
# Parameters:
#
#       bool - true to enable, false to disable
#
sub warriorConnEnable # (id, bool)
{
	my ($self, $id, $enable) = @_;
	my $name = $self->get_string("roadwarrior/$id/name");
	defined($name) or return;
	$self->set_bool("roadwarrior/$id/enable", $enable);
}

# Method: changeStaticConn
#
#	Changes the configuration for a static connection
#
# Parameters:
#
#       name - connection name
#	iface - interface 
#	localsubnet - local subnetwork which will be created
#	localsubnetmask - local subnetwork mask which will be create
#	remoteIP - remote IP to connect
#	remoteSubnet- remote subnetwork which will be created
#	remotesubnetmask - remote subnetwork mask 
#	shareKey - shared key
#	enable - true to enable, false to disable
#	remoteid - (Optional) remote connection identifier
#	remotersa - (Optional) remote public rsa key 
#
sub changeStaticConn # (id, name, iface, localsubnet, $localsubnetmask, 
		# remoteIP, remoteSubnet, remotesubnetmask, sharedKey, enabled,
		# remoteid?, remotersa?)
{
	my ($self, $id, $name, $iface, $lnet, $lmask, $rIP, $rnet, $rmask, 
		$authmethod, $authinfo, $enabled, $remoteid, $remotersa) = @_;

	my $oldname = $self->get_string("static/$id/name");
	defined($oldname) or throw EBox::Exceptions::Internal(
					__('The connection does not exist.'));

	my $oldiface = $self->get_string("static/$id/iface");
	my $oldlnet = $self->get_string("static/$id/lnet");
	my $oldlmask = $self->get_string("static/$id/lmask");
	my $oldrIP = $self->get_string("static/$id/rIP");
	my $oldrnet = $self->get_string("static/$id/rnet");
	my $oldrmask = $self->get_string("static/$id/rmask");
	my $oldauthmethod = $self->get_string("static/$id/authmethod");
	my $oldauthinfo = $self->get_string("static/$id/authinfo");
	my $oldenabled = $self->get_bool("static/$id/enabled");

	my $oldremoteid;
	my $oldremotersa;
	if ($oldauthmethod eq 'rsa') {
		$oldremoteid = $self->get_string("static/$id/remoteid");
		$oldremotersa = $self->get_string("static/$id/remotersa");
	}

	checkCIDR("$lnet/$lmask", __("local subnet"));
	checkCIDR("$rnet/$rmask", __("remote subnet"));
	checkIP("$rIP", __("remote IP address"));

	if ($authmethod eq 'rsa') {
		defined($authinfo) or throw EBox::Exceptions::DataMissing
						('data' => __('RSA key ID'));
		my $pubkey = $self->getRSAPublicKey($authinfo);
		checkDomainName($remoteid, __('remote ID'));
		unless ($remotersa and ($remotersa ne '')) {
			throw EBox::Exceptions::DataMissing
					('data' => __('remote RSA key'));
		}
	} else {
		defined($authinfo) or throw EBox::Exceptions::DataMissing
						('data' => __('shared secret'));
		($authinfo ne '') or throw EBox::Exceptions::DataMissing
						('data' => __('shared secret'));
	}


	my $network = EBox::Global->modInstance('network');
	$network->ifaceExists($iface) or throw EBox::Exceptions::DataNotFound
					('data' => __('network interface'),
					'value' => __($iface));

	(defined($name) and $name ne '') or throw EBox::Exceptions::External(
						__("Connection name is empty"));

	if ($name ne $oldname) {
		$self->set_string("static/$id/name", $name);
	}

	if ($iface ne $oldiface) {
		$self->set_string("static/$id/iface", $iface);
	}

	if ($lnet ne $oldlnet) {
		$self->set_string("static/$id/lnet", $lnet);
	}

	if ($lmask ne $oldlmask) {
		$self->set_string("static/$id/lmask", $lmask);
	}

	if ($rIP ne $oldrIP) {
		$self->set_string("static/$id/rIP", $rIP);
	}

	if ($rnet ne $oldrnet) {
		$self->set_string("static/$id/rnet", $rnet);
	}

	if ($rmask ne $oldrmask) {
		$self->set_string("static/$id/rmask", $rmask);
	}

	if ($authmethod ne $oldauthmethod) {
		$self->set_string("static/$id/authmethod", $authmethod);
		if ($oldauthmethod eq 'rsa') {
			$self->unset("static/$id/remoteid");
			$self->unset("static/$id/remotersa");
		} else {
			$self->set_string("static/$id/remoteid", $remoteid);
			$self->set_string("static/$id/remotersa", $remotersa);
		}
	} elsif ($authmethod eq 'rsa') {
		if ($remoteid ne $oldremoteid) {
			$self->set_string("static/$id/remoteid", $remoteid);
		}
		if ($remotersa ne $oldremotersa) {
			$self->set_string("static/$id/remotersa", $remotersa);
		}
	}

	if ($authinfo ne $oldauthinfo) {
		$self->set_string("static/$id/authinfo", $authinfo);
	}

	if ($enabled ne $oldenabled) {
		$self->set_bool("static/$id/enabled", $enabled);
	}

}

# Method: changeWarriorConn 
#
#	Changes the configuration for s a road warrior connection
#
# Parameters:
#
#	id - connection identifier
#       name - connection name
#	localsubnet - local subnetwork which will be created
#	localsubnetmask - local subnetwork mask which will be create
#	remotesubnet - remote subnetwork which will be allowed  
#	remotesubnetmask - remote subnetwork mask 
#	localrsa - local rsa key to be used with this connection
#	remoteid - remote connection identifier
#	remotersa - remote public rsa key 
#	enabled - true to enable, false to disable
#
sub changeWarriorConn # (id, name, iface, localsubnet, localsubnetmask,
	#remotesubnet remotesubnetmask, localrsa, remoteid, remotersa, enabled)
{
	my ($self, $id, $name, $iface, $lnet, $lmask, $rnet, $rmask, $lrsa,
		$rid, $rrsa, $enabled) = @_;

	checkCIDR("$lnet/$lmask", __("local subnet"));
	checkCIDR("$rnet/$rmask", __("remote subnet"));

	defined($lrsa) or throw EBox::Exceptions::DataMissing
					('data' => __('RSA key ID'));
	my $pubkey = $self->getRSAPublicKey($lrsa);
	checkDomainName($rid, __('remote ID'));
	unless ($rrsa and ($rrsa ne '')) {
		throw EBox::Exceptions::DataMissing
			('data' => __('remote RSA key'));
	}

	(defined($name) and $name ne '') or throw EBox::Exceptions::DataMissing(
					'data' => __("connection name"));

	my $network = EBox::Global->modInstance('network');
	$network->ifaceExists($iface) or throw EBox::Exceptions::DataNotFound
					('data' => __('network interface'),
					'value' => __($iface));

	my $oldname = $self->get_string("roadwarrior/$id/name");
	my $oldiface = $self->get_string("roadwarrior/$id/iface");
	my $oldlnet = $self->get_string("roadwarrior/$id/lnet");
	my $oldlmask = $self->get_string("roadwarrior/$id/lmask");
	my $oldrnet = $self->get_string("roadwarrior/$id/rnet");
	my $oldrmask = $self->get_string("roadwarrior/$id/rmask");
	my $oldlrsa = $self->get_string("roadwarrior/$id/lid");
	my $oldrid = $self->get_string("roadwarrior/$id/rid");
	my $oldrrsa = $self->get_string("roadwarrior/$id/rrsa");
	my $oldenabled = $self->get_bool("roadwarrior/$id/enabled");

	$self->set_string("roadwarrior/$id/name", $name);
	$self->set_string("roadwarrior/$id/iface", $iface);
	$self->set_string("roadwarrior/$id/lnet", $lnet);
	$self->set_string("roadwarrior/$id/lmask", $lmask);
	$self->set_string("roadwarrior/$id/rnet", $rnet);
	$self->set_string("roadwarrior/$id/rmask", $rmask);
	$self->set_string("roadwarrior/$id/lid", $lrsa);
	$self->set_string("roadwarrior/$id/rid", $rid);
	$self->set_string("roadwarrior/$id/rrsa", $rrsa);
	$self->set_bool("roadwarrior/$id/enabled", 1);

	if ($name ne $oldname) {
		$self->set_string("roadwarrior/$id/name", $name);
	}

	if ($iface ne $oldiface) {
		$self->set_string("roadwarrior/$id/iface", $iface);
	}

	if ($lnet ne $oldlnet) {
		$self->set_string("roadwarrior/$id/lnet", $lnet);
	}

	if ($lmask ne $oldlmask) {
		$self->set_string("roadwarrior/$id/lmask", $lmask);
	}

	if ($rnet ne $oldrnet) {
		$self->set_string("roadwarrior/$id/rnet", $rnet);
	}

	if ($rmask ne $oldrmask) {
		$self->set_string("roadwarrior/$id/rmask", $rmask);
	}

	if ($lrsa ne $oldlrsa) {
		$self->set_string("roadwarrior/$id/lid", $lrsa);
	}

	if ($rid ne $oldrid) {
		$self->set_string("roadwarrior/$id/rid", $rid);
	}

	if ($rrsa ne $oldrrsa) {
		$self->set_string("roadwarrior/$id/rrsa", $rrsa);
	}

	if ($enabled ne $oldenabled) {
		$self->set_bool("roadwarrior/$id/enabled", $enabled);
	}
}

# Method: listStaticConns
#
#	Gathers a list of the static connections
#
# Returns:
#
#	array ref - holding the connection identifiers
sub listStaticConns
{
	my $self = shift;
	return $self->all_dirs_base("static");
}

# Method: listWarriorConns
#
#	Gathers a list of the road warrior  connections
#
# Returns:
#
#	array ref - holding the connection identifiers
sub listWarriorConns
{
	my $self = shift;
	return $self->all_dirs_base("roadwarrior");
}

# Method: getStaticConn 
#
#	Given a static connection identifier it returns all its parameters
#
# Parameters:
#
#	id - connection identifier
# 
# Returns:
#	
#	A hash reference holding the keys:
#
#	ifaceg - interface 
#	lnetg - local subnet
#	lmaskg - local subnet mask
#	rIPg - remote IP
#	rnetg - remote network
#	rmaskg - remote network mask
#	authmethodg - authentication method
#	authinfog - authentication method
#	enabledg - enabled
#	id - identifier
sub getStaticConn # (id)
{
	my ($self, $id) = @_;
	checkName($id) or throw EBox::Exceptions::Internal(
						__('Invalid connection name'));
	my $conn = $self->hash_from_dir("static/$id");
	if (keys(%{$conn})) {
		$conn->{id} = $id;
		return $conn;
	}
	return undef;
}

# Method: getStaticConn 
#
#	Given a road warrior connection  identifier it returns all its parameters
#
# Parameters:
#
#	id - connection identifier
# 
# Returns:
#	
#	A hash reference holding the keys:
#
#	ifaceg - interface 
#	lnetg - local subnet
#	lmaskg - local subnet mask
#	rnetg - remote network
#	rmaskg - remote network mask
#	lid - local identifier
#	lird  - remote identifier
#	enabledg - enabled
sub getWarriorConn # (id)
{
	my ($self, $id) = @_;
	checkName($id) or throw EBox::Exceptions::Internal(
						__('Invalid connection name'));
	my $conn = $self->hash_from_dir("roadwarrior/$id");
	if (keys(%{$conn})) {
		$conn->{id} = $id;
		return $conn;
	}
	return undef;
}

# Method: staticConnsArray
#
#	Returns all the static connections
#
# Returns:
#	
#	An array reference of hash references holding the keys:
#
#       ifaceg - interface 
#       lnetg - local subnet
#       lmaskg - local subnet mask
#       rnetg - remote network
#       rmaskg - remote network mask
#       lid - local identifier
#       lird  - remote identifier
#       enabledg - enabled
sub staticConnsArray
{
	my $self = shift;
	my @array = ();
	foreach my $conn (@{$self->listStaticConns()}) {
		my $hash = $self->getStaticConn($conn);
		if ($hash) {
			push(@array, $hash);
		}
	}
	return \@array;
}

# Method: warriorConnsArray
#
#	Returns all the road warrior connections
#
# Returns:
#	
#	An array reference of hash references holding the keys:
#
#	ifaceg - interface 
#	lnetg - local subnet
#	lmaskg - local subnet mask
#	rnetg - remote network
#	rmaskg - remote network mask
#	lid - local identifier
#	lird  - remote identifier
#	enabledg - enabled
sub warriorConnsArray
{
	my $self = shift;
	my @array = ();
	foreach my $conn (@{$self->listWarriorConns()}) {
		my $hash = $self->getWarriorConn($conn);
		if ($hash) {
			push(@array, $hash);
		}
	}
	return \@array;
}

# Method: staticActiveConnsArray
#
#	Returns all the active static connections
#
# Returns:
#	
#	An array reference of hash references holding the keys:
#
#       ifaceg - interface 
#       lnetg - local subnet
#       lmaskg - local subnet mask
#       rnetg - remote network
#       rmaskg - remote network mask
#       lid - local identifier
#       lird  - remote identifier
#       enabledg - enabled
sub staticActiveConnsArray
{
	my $self = shift;
	my $network = EBox::Global->modInstance('network');
	my $conns = $self->staticConnsArray();
	my @connsfiltered = ();
	foreach my $conn (@{$conns}) {
		my $addr = $network->ifaceAddress($conn->{iface});
		(defined($addr) && $addr ne "") or next;
		$conn->{enabled} or next;
		# FIXME - auto configuration
		$conn->{auto} = "start";
		$conn->{lIP} = $addr;
		if ($conn->{authmethod} eq 'rsa') {
			$conn->{localrsa} =
				$self->getRSAPublicKey($conn->{authinfo});
		} 
		push(@connsfiltered, $conn);
	}
	return \@connsfiltered;
}

# Method: warriorActiveConnsArray
#
#	Returns all the active road warrior connections
#
# Returns:
#	
#	An array reference of hash references holding the keys:
#
#	ifaceg - interface 
#	lnetg - local subnet
#	lmaskg - local subnet mask
#	rnetg - remote network
#	rmaskg - remote network mask
#	lid - local identifier
#	lird  - remote identifier
#	enabledg - enabled
sub warriorActiveConnsArray
{
	my $self = shift;
	my $network = EBox::Global->modInstance('network');
	my $conns = $self->warriorConnsArray();
	my @connsfiltered = ();
	foreach my $conn (@{$conns}) {
		my $addr = $network->ifaceAddress($conn->{iface});
		(defined($addr) && $addr ne "") or next;
		$conn->{enabled} or next;
		$conn->{auto} = "add";
		$conn->{lIP} = $addr;
		$conn->{lrsa} = $self->getRSAPublicKey($conn->{lid});
		push(@connsfiltered, $conn);
	}
	return \@connsfiltered;
}

sub _setIPSecConf
{
	my $self = shift;
	my $conns = $self->staticActiveConnsArray();
	my $warriors = $self->warriorActiveConnsArray();
	my @array = ();
	push(@array, 'shared_secret_conns' => $conns);
	push(@array, 'road_warrior_conns' => $warriors);
	$self->writeConfFile(IPSECCONFFILE, "ipsec/ipsec.conf.mas", \@array);
	push(@array, 'includedir' => EBox::Config::conf . "/ipsecrsa/*");
	$self->writeConfFile(IPSECSECRETS, "ipsec/ipsec.secrets.mas", \@array);
}

sub _serviceNeeded
{
	my $self = shift;
	my $conns = $self->staticActiveConnsArray();
	if (@{$conns} > 0) {
		return 1;
	}
	return undef;
}

sub _daemon
{
	my ($self, $action) = @_;
	my $command = IPSECINIT . " $action 2>&1";
	root($command);
}

sub _stopService
{
	my $self = shift;
	if ($self->isRunning) {
		$self->_daemon('stop');
	}
}

sub _doDaemon
{
	my $self = shift;
	if ($self->_serviceNeeded and $self->isRunning) {
		$self->_daemon('restart');
	} elsif ($self->_serviceNeeded) {
		$self->_daemon('start');
	} elsif ($self->isRunning) {
		$self->_daemon('stop');
	}
}

sub _regenConfig
{
	my $self = shift;
	$self->_setIPSecConf;
	$self->_doDaemon();
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
        my ($self, $protocol, $port, $iface) = @_;

	return undef unless ($protocol eq 'udp');

	return 1 if ($port eq '500');
	return 1 if ($port eq '4500');

	return undef;
}

sub firewallHelper
{
	my $self = shift;
	if ($self->_serviceNeeded) {
		return new EBox::IPSecFirewall();
	}
	return undef;
}

sub listRSAKeys
{
	my $self = shift;
	return $self->all_entries_base("rsa");
}

sub getRSAPublicKey # (id)
{
	my ($self, $id) = @_;
	my $file;
	my $dir = EBox::Config::conf . "/ipsecrsa";

	checkDomainName($id, __('RSA key ID'));
	$file = $id;

	unless ($self->get_bool("rsa/$file")) {
		throw EBox::Exceptions::DataNotFound('data' => __('RSA key'),
							'value' => $file);
	}
	
	$self->_checkMissingRSAKeys();
	
	my $cmd = IPSEC . ' showhostkey --id @'."$id --file $dir/$file --left ".
		"| /usr/bin/tail -1";
	my $key = `/usr/bin/sudo $cmd 2> /dev/null` or
		throw EBox::Exceptions::Internal(__('Error getting RSA key'));
	$key =~ s/^.*leftrsasigkey=//;
	chomp($key);
	return $key;
}

# Method: generateRSAKey
#
#	It generates a RSA key for a given identifier
#
# Parameters:
#
#	id - identifier
sub generateRSAKey # (id)
{
	my ($self, $id) = @_;
	my $file;
	my $dir = EBox::Config::conf . "ipsecrsa";

	$id =~ s/^@//;
	checkDomainName($id, __('RSA key ID'));
	$file = $id;

	if (-f "$dir/$file") {
		throw EBox::Exceptions::DataExists('data' => __('RSA key'), 
						'value' => $id);
	}
	my $cmd = IPSEC . " newhostkey --output - --quiet";
	my $key = `/usr/bin/sudo $cmd 2> /dev/null` or
		throw EBox::Exceptions::Internal(
			__('Error while generating RSA key'));

	$self->set_bool("rsa/$file", 1);
	my @array = ();
	push(@array, 'id' => $id);
	push(@array, 'key' => $key);
	$self->writeConfFile("$dir/$file", "ipsec/rsakey.mas", \@array);
}

sub _checkMissingRSAKeys
{
	my $self = shift;
	my $dir = EBox::Config::conf . "ipsecrsa";

	my $ok = 1;
	for my $file (@{$self->listRSAKeys()}){
		next if (-f "$dir/$file");
		$self->unset("rsa/$file");	
		$ok = undef;	
	}
	unless ($ok) {
		throw EBox::Exceptions::External(
			"Some RSA keys can't be found, as it seems they're ".
			"not stored anymore its identifiers has been removed");
	}
}

sub _RSAKeyIsUsed # (id)
{
	my ($self, $id) = @_;

	checkDomainName($id, __('RSA key ID'));

	foreach my $conn (@{$self->listWarriorConns()}) {
		my $hash = $self->getWarriorConn($conn);
		($hash) or next;
		($hash->{lid} eq $id) and return 1;
	}

	foreach my $conn (@{$self->listStaticConns()}) {
		my $hash = $self->getStaticConn($conn);
		($hash) or next;
		($hash->{authmethod} eq 'rsa') or next;
		($hash->{authinfo} eq $id) and return 1;
	}

	return undef;
}

# Method: removeRSAKey
#
#	Removes the RSA key for a given identifier
#
# Parameters:
#
#	id - identifier
sub removeRSAKey # (id)
{
	my ($self, $id) = @_;
	my $file;
	my $dir = EBox::Config::conf . "ipsecrsa";

	checkDomainName($id, __('RSA key ID'));
	$file = $id;

	unless ($self->get_bool("rsa/$file")) {
		throw EBox::Exceptions::DataNotFound('data' => __('RSA key'),
							'value' => $file);
	}

	if ($self->_RSAKeyIsUsed($id)) {
		throw EBox::Exceptions::External(__('There are tunnels '.
			'configured to use this RSA key, it cannot be '.
			'deleted.'));
	}

	$self->unset("rsa/$file");
	command("rm -f  $dir/$file");
}

# Method: rootCommands 
#
#       Overrides EBox::Module method.
#   
#    
sub rootCommands
{
	my $self = shift;
	my @array = ();
	push(@array, IPSEC);
	push(@array, IPSECINIT);
	push(@array, "/bin/mv ". EBox::Config::tmp . "* " .  
		     EBox::Config::conf . "ipsecrsa/*");
	push(@array, "/bin/chmod * " . IPSECCONFFILE);
	push(@array, "/bin/chown * " . IPSECCONFFILE);
	push(@array, "/bin/chmod * " . IPSECSECRETS);
	push(@array, "/bin/chown * " . IPSECSECRETS);
	push(@array, "/bin/mv ". EBox::Config::tmp . "* " .  IPSECCONFFILE);
	push(@array, "/bin/mv ". EBox::Config::tmp . "* " .  IPSECCONFFILE);
	push(@array, "/bin/mv ". EBox::Config::tmp . "* " .  IPSECSECRETS);
	push(@array, "/bin/rm -f " . PLUTOPIDFILE);
	return @array;
}

sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('ipsec','IPSec', 
				$self->isRunning, $self->_serviceNeeded);
}

sub summary
{
	my $self = shift;
	my $ipsecStatus = root(IPSEC . " auto --status");
	my $item = new EBox::Summary::Module(__("IPSec VPNs"));
	my $section;
	my $staticConns = $self->staticActiveConnsArray();
	if (scalar(@{$staticConns})) {
		$section = new EBox::Summary::Section(__("Static tunnels"));
		$item->add($section);
		foreach my $static (@{$staticConns}) {
			$static->{'enabled'} or next;
			my $status = 0;
			my $value = __('Down');
			my $regex = '"' . $static->{'id'} . '".*STATE_MAIN_I4.*ISAKMP SA established';
			foreach my $line (@{$ipsecStatus}) {
				if ($line=~/$regex/) {
					if ($status == 0) {
						$regex = '"' . $static->{'id'} . '".*STATE_QUICK_I2.*IPsec SA established';
						$status = 1;
					} else {
						$status = 2;
						$value = __('Up');
						last;
					}
				}
			}
			$section->add(new EBox::Summary::Value($static->{'name'},$value));
		}
	}
	my $warriors = $self->warriorActiveConnsArray();
	if (scalar(@{$warriors})) {
		$section = new EBox::Summary::Section(__("Road warriors"));
		$item->add($section);
		foreach my $warrior (@{$warriors}) {
			$warrior->{'enabled'} or next;
			my $status = 0;
			my $value = __('Down');
			my $regex = '"' . $warrior->{'id'} . '".*STATE_MAIN_I4.*ISAKMP SA established';
			foreach my $line (@{$ipsecStatus}) {
				if ($line=~/$regex/) {
					if ($status == 0) {
						$regex = '"' . $warrior->{'id'} . '".*STATE_QUICK_I2.*IPsec SA established';
						$status = 1;
					} else {
						$status = 2;
						$value = __('Up');
						last;
					}
				}
			}
			$section->add(new EBox::Summary::Value($warrior->{'name'},$value));
		}
	}
	return $item;
}

# Method: rootCommands 
#
#       Overrides EBox::Module method.
#   
#    
sub menu
{
        my ($self, $root) = @_;
        my $folder = new EBox::Menu::Folder('name' => 'IPSec',
                                            'text' => __('IPSec VPNs'));

        $folder->add(new EBox::Menu::Item('url' => 'IPSec/Static',
                                          'text' => __('Static tunnels')));
        $folder->add(new EBox::Menu::Item('url' => 'IPSec/RoadWarrior',
                                          'text' => __('Road warriors')));
        $folder->add(new EBox::Menu::Item('url' => 'IPSec/RSA',
                                          'text' => __('RSA keys')));
        $root->add($folder);
}


1;
