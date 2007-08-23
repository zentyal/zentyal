# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
#
# This program is free softwa re; you can redistribute it and/or modify
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

package EBox::OpenVPN;
use base qw(EBox::GConfModule EBox::NetworkObserver EBox::FirewallObserver EBox::CA::Observer);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Sudo;
use EBox::OpenVPN::Server;
use EBox::OpenVPN::Client;
use EBox::OpenVPN::FirewallHelper;
use EBox::CA;
use EBox::CA::DN;
use EBox::NetWrappers qw();
use EBox::FileSystem;

use Perl6::Junction qw(any);
use Error qw(:try);


use constant  MAX_IFACE_NUMBER => 999999; # this is the last number which prints correctly in ifconfig

my @daemonTypes   = qw(server client); # in the daemons method they will appear in this order
my $anyDaemonType = any @daemonTypes;

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'openvpn');
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
    my ($self) = @_;

    $self->_writeConfFiles();
    $self->_cleanFiles();
    $self->_doDaemon();
}


#
# Method: confDir
#
#    Return the directory used to store OpenVPN's configuration files
#
# Returns:
#
#   String - the directory path
#
sub confDir
{
    my ($self) = @_;
    return $self->get_string('conf_dir');
}

#
# Method: confDir
#
#    Return the OpenVPN's binary location
#
# Returns:
#
#   String - path to the OpenVPN program
#
sub openvpnBin
{
   my ($self) = @_;
   return $self->get_string('openvpn_bin');
}


sub _writeConfFiles
{
    my ($self) = @_;

    $self->_writeRIPDaemonConf(); # XXX RIP stuff

    my $confDir = $self->confDir;

    my @daemons = $self->daemons();
    foreach my $daemon (@daemons) {
	$daemon->writeConfFile($confDir);
    }
}


sub _cleanFiles
{
    my ($self) = @_;
    my $confDir = $self->confDir;
    
    
    $self->dir_exists('toDelete') or return;

    my @rmTargets = map { "$confDir/$_"  } @{ $self->all_entries_base('toDelete') };
    EBox::Sudo::root(" rm -rf @rmTargets");

    $self->delete_dir('toDelete');
    
    # this is to avoid that the above deletion
    # XXX TODO: reimplement using ebox state
    my $global = EBox::Global->getInstance();
    $global->modRestarted('openvpn');
}

sub deleteOnRestart
{
  my ($self, @files) = @_;
  @files or throw EBox::Exceptions::MissingArgument("one or more files to delete on restart");
  $self  or throw EBox::Exceptions::MissingArgument("you must call this on a object");

  foreach my $file (@files) {
    $self->set_string("toDelete/$file", "");
  }
}


# all openvpn daemons related methods

#
# Method: daemons
#
#       return all daemons registered in the module
#
#
# Returns:
#
#   a list with daemons objects
#
sub daemons
{
  my ($self) = @_;
  my @daemons;

  foreach my $type (@daemonTypes) {
    my $listSub = $type . 's';
    push @daemons, $self->$listSub();
  }

  return @daemons;
}

#
# Method: activeDaemons
#
#  Return all active daemons registered in the module
#
#
# Returns:
#
#   array - a list with daemons objects
#
sub activeDaemons
{
    my ($self) = @_;
    return grep { $_->service } $self->daemons();
}

#
# Method: daemonsNames
#
#  return  the names of all daemons registered in the module
#
#
# Returns:
#
#   array - a list with daemons names
#
sub daemonsNames
{
  my ($self) = @_;
  my @daemonsNames;

  foreach my $type (@daemonTypes) {
    my $nameSub = $type . 'sNames';
    push @daemonsNames, $self->$nameSub();
  }

  return @daemonsNames;
}



sub _newDaemon
{
    my ($self, $type, $name, @initParams) = @_;

    ($type eq $anyDaemonType) or throw EBox::Exceptions::Internal("Unsupported daemon type: $type");
    $self->_checkName($name);
    
    $self->_createDaemonSkeleton($type, $name);

    my $daemon;
    try {
	$daemon = $self->$type($name);
	$daemon->init(@initParams);
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("$type/$name");
	$ex->throw();
    };

    return $daemon;
}

sub _removeDaemon
{
    my ($self, $type, $name) = @_;
    ($type eq $anyDaemonType) or throw EBox::Exceptions::Internal("Unsupported daemon type: $type");

    my $daemon = $self->$type($name);
    if (! $daemon) {
	throw EBox::Exceptions::External __x("Unable to remove daemon {name} of type {type} because it does not exist", name => $name, type => $type);
    }

    $daemon->delete(); # the daemon has to be able to delete itself
}


# server-related methods

#
# Method: servers
#
#   List all servers registered in the module
#
#
# Returns:
#
#   array - a list with servers objects
#
sub servers
{
    my ($self) = @_;
    my @servers = $self->serversNames();
    @servers = map { $self->server($_) } @servers;
    return @servers;
}

#
# Method: activeServers
#
#   List all active servers registered in the module
#
#
# Returns:
#
#   array - a list with active servers objects
#
sub activeServers
{
    my ($self) = @_;
    return grep { $_->service } $self->servers();
}

#
# Method: serverNames
#
#   List the names of all daemons registered in the module
#
#
# Returns:
#
#   array - a list with servers names
#
sub serversNames
{
    my ($self) = @_;
    
    my @serversNames = @{ $self->all_dirs_base('server') };
    return @serversNames;
}

# a object server cache may be a good idea?

#
# Method: server
#
#     Return the object representing the given server
#
# Parameters:
#
#    name - the servers name
#
# Returns:
#
#   <EBox::OpenVPN::Server> - the server object
#
sub server
{
    my ($self, $name) = @_;
    
    my $server = new EBox::OpenVPN::Server ($name, $self);
    return $server;
}



#
# Method: newServer
#
#     Create a new server
#
# Parameters:
#
#    $name - the server's name 
#
# *(Following the server name are the server's  attributes as named parameters)*
#
#  service        - wether rhe server is active or not *(default: disabled)*
#  subnet         - address of VPN net
#  subnetNetmask  - netmask of VPN net
#  port           - server's port
#  proto          - server's proto
#  certificate    - CN of server's certificate
#  local          - local interface to listen on *(optional)*
#  advertisedNets - advertised nets 
#  tlsRemote      - tls remote option
#  pullRoutes     - wether pull routes from clientes or not
#
# Returns:
#
#   <EBox::OpenVPN::Server> - the server object
#
sub newServer
{
    my ($self, $name, @initParams) = @_;
    return $self->_newDaemon('server', $name, @initParams);
}

#
# Method: removeServer
#
#     Remove the given server from the module
#
# Parameters:
#
#     name       - the server's name
#
sub removeServer
{
    my ($self, $name) = @_;
    $self->_removeDaemon('server', $name);
}

sub _portsByProtoFromServers
{
    my ($self, @servers) = @_;
    
    my %ports;
    foreach my $proto (qw(tcp udp)) {
	my @protoServers = grep { $_->proto eq $proto  } @servers;
	my @ports        = map  { $_->port } @protoServers;

	$ports{$proto} = \@ports;
    }

    return \%ports;
}



## clients

#
# Method: clients
#
#   List all clients registered in the module
#
#
# Returns:
#
#   array - a list with client's objects
#
sub clients
{
    my ($self) = @_;
    my @clients = $self->clientsNames();
    @clients = map { $self->client($_) } @clients;
    return @clients;
}

#
# Method: activeClients
#
#   List all active clients registered in the module
#
#
# Returns:
#
#   array - a list with active client's objects
#
sub activeClients
{
    my ($self) = @_;
    return grep { $_->service } $self->clients();
}

#
# Method: clientNames
#
#   List the names of all daemons registered in the module
#
#
# Returns:
#
#   array - a list with client's names
#
sub clientsNames
{
    my ($self) = @_;
    
    my @clientsNames = @{ $self->all_dirs_base('client') };
    return @clientsNames;
}

#
# Method: client
#
#    Return the object representing the given client
#
# Parameters:
#
#    name - the client's name
#
# Returns:
#
#   <EBox::OpenVPN::Client> - the client object
#
sub client
{
    my ($self, $name) = @_;
    
    my $client = new EBox::OpenVPN::Client ($name, $self);
    return $client;
}

#
# Method: newClient
#
#    Create a new client
#
# Parameters:
#
#    name - the client's name 
#  *(Following the client name there are the client attributes as named parameters)*
#
#  servers - client's servers list. Muast be a list reference. The servers may be
#  hostnames or IP addresses.
#  proto - the client's IP protocol.
#
#  caCertificatePath - Path to the CA's certificate.
#  certificatePath   -  Path to the client's certificate.
#  certificateKey    -  Path yo the client's certificate key.
#
#  service - wether the client is enabled or disabed. *(Default: disabled)*
#
# Returns:
#
#   <EBox::OpenVPN::Client> - the client object
#
sub newClient
{
  my ($self, $name, @initParams) = @_;

  return $self->_newDaemon('client', $name, @initParams);
}


#
# Method: removeClient
#
#    Remove the given client from the module
#
# Parameters:
#
#    name       - the client's name
#
sub removeClient
{
  my ($self, $name) = @_;
  $self->_removeDaemon('client', $name);
}





# return a ref to a list of [proto server port]
sub _serversToConnect
{
  my ($self) = @_;
  my @clients = $self->activeClients();

  my @servers = map {
    my $client = $_;
    my $proto = $client->proto();

    my @serversForClient;
    foreach my $server_r (@{ $client->servers() } ) {
      my ($server, $serverPort) = @{ $server_r };
      push @serversForClient, [$proto, $server, $serverPort];
    }

    @serversForClient;
  } @clients;

  return \@servers;
}


sub _checkName
{
  my ($self, $name) = @_;

   unless ( $name =~ m{^\w+$} ) {
	throw EBox::Exceptions::External (__x("{name} is a invalid name for a OpenVPN daemon. Only alphanumerics and underscores are allowed", name => $name) );
    }

  my @names = ($self->serversNames(), $self->clientsNames());
  if ($name eq any(@names)) {
      throw EBox::Exceptions::DataExists(data => "OpenVPN instance's name", value => $name  );
    }

}


sub _createDaemonSkeleton
{
  my ($self, $type, $name) = @_;

  my $ifaceNumber    = $self->_newIfaceNumber();  
  my $ifaceNumberKey = "$type/$name/iface_number";
  $self->set_int($ifaceNumberKey, $ifaceNumber); 
}


# Returns:
#   directory to store the log files (not status log files)
#
sub logDir
{
  my ($class) = @_;

  my $dir = EBox::Config::log() . 'openvpn';
  return $dir;
}



#
# Method: user
#
#    Get the user will be used to run openvpn daemon
#    after root drops privileges
#
# Returns:
#
#    String - the user's name
#
sub user
{
    my ($self) = @_;
    return $self->get_string('user');
}

#
# Method: group
#
#    Get the group will be used to run openvpn daemon
#    after root drops privileges
#
# Returns:
#
#    String - the group's name
#
sub group
{
    my ($self) = @_;
    return $self->get_string('group');
}

#
# Method: dh
#
#    Get the path to the Diffie-Hellman
#    parameters file used by openvpn server
#
# Returns:
#
#    String - the path to the Diffie-Hellman parameters file
#
sub dh
{
    my ($self) = @_;
    return $self->get_string('dh');
}




sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;

     if (!$self->service) {
	 return undef;
     }
   

    if (defined $iface and ($iface =~ m/tun\d+/ )) {  # see if we are asking about openvpn virtual iface
	return 1;
    }


    my @servers = $self->activeServers();

    if (defined $iface) {
      my $anyIfaceAddr   = any(EBox::NetWrappers::iface_addresses($iface));
      @servers = grep { my $lAddr = $_->local(); (!defined $lAddr) or ($lAddr eq  $anyIfaceAddr) } @servers;
    }

    my $portsByProto = $self->_portsByProtoFromServers(@servers);

    exists $portsByProto->{$proto} or return undef;
    my @ports        = @ {$portsByProto->{$proto} };

    my $portUsed = ( $port == any(@ports) );


    return $portUsed ? 1 : undef;
}

sub firewallHelper
{
    my ($self) = @_;

    my $service = $self->service();

    my @ifaces = map {
      $_->iface()
    }  $self->activeDaemons() ;

    my $portsByProto = $self->_portsByProtoFromServers($self->activeServers); 
    my $serversToConnect = $self->_serversToConnect();

    my $firewallHelper = new EBox::OpenVPN::FirewallHelper (
							    service          => $service,
							    ifaces           => \@ifaces,
							    portsByProto     => $portsByProto,
							    serversToConnect => $serversToConnect,
							   );
    return $firewallHelper;
}


sub CAIsCreated
{
  my $ca = EBox::Global->modInstance('ca');
  return $ca->isCreated;
}

sub setService # (active)
{
    my ($self, $active) = @_;

    my $actualService   = $self->service;

    if ($active) {
      $actualService and return;
      $self->CAIsCreated() or throw EBox::Exceptions::Internal('Tying to activate OpenVPN service when there is not certification authority created');
    }
    else {
      (not $actualService) and return;
    }

    $self->set_bool('active', $active);
}


sub service
{
   my ($self) = @_;
   my $service =  $self->get_bool('active');

   if ($service) {
      if (! $self->CAIsCreated()) {
	EBox::warn('OpenVPN service disbled because certification authority is not setted up');
	return 0;
      }
   }

   return $service;
}

sub _doDaemon
{
    my ($self) = @_;
    my $running = $self->running();

    if ($self->service) {
	if ($running) {
	    $self->_stopDaemon();
	    $self->_startDaemon();
	}
	else {

	  # XXX rip stuff to assure that quagga is in good state
	  if ($self->ripDaemonRunning) { # tame leftover rip daemons
	    $self->_stopRIPDaemon();
	  }

	  $self->_startDaemon();
	}
    }
    else {
	if ($running) {
	    $self->_stopDaemon();
	  }
	# XXX rip stuff to assure that quagga is stopped
	elsif ($self->ripDaemonRunning) { # tame leftover rip daemons
	  $self->_stopRIPDaemon();
	}
    }
}

sub running
{
  my ($self) = @_;
  
  if ($self->_runningInstances()) {
    return 1;
  } 
  elsif ($self->service) {
    my @activeDaemons = $self->activeDaemons();
    return @activeDaemons == 0 ? 1 : 0;      
  }
  
  return 0;
}



sub _startDaemon
{
  my ($self) = @_;


  try {
    my @daemons =  grep { $_->service } $self->daemons();
    foreach my $daemon (@daemons) {
      my $command = $self->rootCommandForStartDaemon($daemon->confFile, $daemon->name);
      EBox::Sudo::root($command);
    }
  }
 finally {
   $self->_startRIPDaemon() ; # XXX RIP stuff
 };
}

sub _stopDaemon
{
    my ($self) = @_;
    
    $self->_stopRIPDaemon(); # XXX RIP stuff

    if ($self->_runningInstances()) {  # the service may be running but no daemon running
      my $stopCommand = $self->rootCommandForStopDaemon();
      EBox::Sudo::root($stopCommand);
    }

}


sub _runningInstances
{
  my ($self) = @_;
  my $bin = $self->openvpnBin;

  `/usr/bin/pgrep -f $bin`;
  return ($? == 0);
}


sub rootCommandForStartDaemon
{
    my ($self, $file, $name) = @_;

    my $bin     = $self->openvpnBin();
    my $confDir = $self->confDir();

    my $confOption = "--config $confDir/$file";
    my $daemonOption =  " --daemon $name";

    return "$bin $daemonOption $confOption";
}

sub rootCommandForStopDaemon
{
    my ($self) = @_;
    my $bin = $self->openvpnBin();
    return "/usr/bin/killall $bin";
}





sub _stopService
{
  my ($self) = @_;
  $self->_stopDaemon();
}

#  rip daemon/quagga stuff

#
# Method: ripDaemons
#
#    Get the parameters of the RIP daemon
#    if the OpenVPN module needs one
#
# Returns:
#
#    - undef if not RIP daemon is neccessary
#    - if RIP is neccessary a hash ref with RIP daemosn parameters:
#          ifaces      - list of ifaces to use by RIP daemon
#          redistribute - bool parameters which signal if routes 
#                           redistribution is required
#
sub ripDaemon
{
  my ($self) = @_;

  my @ifaces;
  my $redistribute;

  foreach my $daemon ($self->daemons()) {
    my $rip = $daemon->ripDaemon();
    if (defined $rip) {
      push @ifaces, $rip->{iface};
      if ( (exists $rip->{redistribute}) && $rip->{redistribute}) {
	$redistribute = 1;
      }
    }
  }

  if (@ifaces) {
    return { ifaces => \@ifaces, redistribute => $redistribute  };
  }
  else {
    return undef;    
  }

}

#
# Method: ripDaemonService
#
#   Check whether a RIP daemon is neccesary or not
#
# Returns:
#
#    bool
sub ripDaemonService
{
  my ($self) = @_;

  foreach my $daemon ($self->activeDaemons()) {
    my $rip = $daemon->ripDaemon();
    if (defined $rip) {
      return 1;
    }
  }

  return undef;
}

#
# Method: ripDaemonRunning
#
#   Check whether a RIP daemon is running or not
#
# Returns:
#
#    bool
sub ripDaemonRunning
{
  my ($self) = @_;

  # check for ripd and zebra daemons
  `pgrep ripd`;
  `pgrep zebra` if $? != 0;

  return 1 if ($? == 0);
  return undef;
}


sub _startRIPDaemon
{
  my ($self) = @_;

  $self->ripDaemonService()  or return;
  $self->_runningInstances() or return; # if there are not openvpn instances running (surely for error) don't bother to start daemon

  my $cmd = '/etc/init.d/quagga start';
  EBox::Sudo::root($cmd);
}


sub _stopRIPDaemon
{
  my ($self) = @_;

  if ($self->ripDaemonRunning()) {
    my $cmd = '/etc/init.d/quagga stop';
    EBox::Sudo::root($cmd);
  }


}

sub _writeRIPDaemonConf
{
  my ($self) = @_;

  my $ripDaemon =  $self->ripDaemon();
  defined $ripDaemon or return;

  my $ifaces       = $ripDaemon->{ifaces};
  my $redistribute = $ripDaemon->{redistribute};

  my $confDir = '/etc/quagga';
  my ($quaggaUser, $quaggaPasswd, $quaggaUid, $quaggaGid) = getpwnam('quagga');
  defined $quaggaUser or throw EBox::Exceptions::Internal('No quagga user found in the system');


  my $fileAttrs = {
		  uid  => $quaggaUid,
		  gid  => $quaggaGid,
		  mode => '0400',
		 };


  $self->writeConfFile("$confDir/debian.conf", '/quagga/debian.conf.mas', [], $fileAttrs);
  $self->writeConfFile("$confDir/daemons", '/quagga/daemons.mas', [], $fileAttrs);
  $self->writeConfFile("$confDir/zebra.conf", '/quagga/zebra.conf.mas', [], $fileAttrs);

  my @ripdConfParams = (
			ifaces       => $ifaces,
			redistribute => $redistribute,
		       );
  $self->writeConfFile("$confDir/ripd.conf", '/quagga/ripd.conf.mas', \@ripdConfParams, $fileAttrs);
 
}


sub _newIfaceNumber
{
  my ($self) = @_;
  my $number = $self->get_int('interface_count');

  if ($number > MAX_IFACE_NUMBER) {
    # XXX reuse unused numbers

    throw EBox::Exceptions::Internal('Maximum interface count reached. Contact your eBox support');
  }
  else {
    my $newNumber = $number + 1;
    $self->set_int('interface_count', $newNumber);
  }

  return $number;
}

#
# Method: availableCertificates
#
#   Get the certificates which are available to use with OpenVPN
#
# Returns:
#
#    array ref -  a list with the common names of available certificates
sub availableCertificates
{
  my ($self) = @_;
  
  my $ca = EBox::Global->modInstance('ca');
  my $certificates_r = $ca->listCertificates(state => 'V', excludeCA => 1);
  my @certificatesCN = map {
    $_->{dn}->attribute('commonName');
  } @{ $certificates_r };

  return \@certificatesCN;
}





# ca observer stuff

sub certificateRevoked
{
  my ($self, @params) = @_;
  foreach my $server ($self->servers()) {
    if ($server->certificateRevoked(@params)) {
      return 1;
    }
  }

  return 0;
}

sub certificateExpired
{
  my ($self, @params) = @_;
  $self->_invokeOnServers('certificateExpired', @params);
}

sub freeCertificate
{
  my ($self, @params) = @_;
  $self->_invokeOnServers('freeCertificate', @params);
}




# network observer stuff

sub ifaceMethodChanged
{
  my ($self, @params) = @_;
  return $self->_anyDaemonReturnsTrue('ifaceMethodChanged', @params);
}


sub vifaceDelete
{
  my ($self, @params) = @_;
  return $self->_anyDaemonReturnsTrue('vifaceDelete', @params);
}


sub freeIface
{
  my ($self, @params) = @_;
  return $self->_invokeOnDaemons('freeIface', @params);
}

sub freeViface
{
  my ($self, @params) = @_;
  return $self->_invokeOnDaemons('freeViface', @params);
}


# common listeners helpers..

sub _invokeOnServers
{
  my ($self, $method, @methodParams) = @_;
  foreach my $server ($self->servers()) {
    my $method_r = $server->can($method);
    defined $method_r or throw EBox::Exceptions::Internal("No such method $method");
     $method_r->($server, @methodParams);
  }
}

sub _invokeOnDaemons
{
  my ($self, $method, @methodParams) = @_;
  foreach my $daemon ($self->daemons()) {
    my $method_r = $daemon->can($method);
    defined $method_r or throw EBox::Exceptions::Internal("No such method $method");
     $method_r->($daemon, @methodParams);
  }
}

sub _anyDaemonReturnsTrue
{
  my ($self, $method, @methodParams) = @_;
  foreach my $daemon ($self->daemons()) {
    my $method_r = $daemon->can($method);
    defined $method_r or throw EBox::Exceptions::Internal("No such method $method");
    if ($method_r->($daemon, @methodParams)) {
      return 1;
    } 
  }

  return undef;
}


#  XXX this ugly override is to assure than changes in openvpn. mark network as changed
#  this is necessary because network-dependent modules must be aware of the network interface
#  changes that openvpn provokes (the _backup method is used to mark the modules as changed)
# XXX we do not usae it because the order of initialization rends it useless.. for the moment
# sub _backup
# {
#   my ($self) = @_;

#   my $network = EBox::Global->modInstance('network');
#   $network->setAsChanged();

#   # continue normal invokation..
#   $self->SUPER::_backup();
# }



# Method: menu 
#
#       Overrides <EBox::Module::menu> method.
#
sub menu
{
        my ($self, $root) = @_;
    
        my $item = new EBox::Menu::Item('url' => 'OpenVPN/Index',
                                        'text' => __('OpenVPN'));
	$root->add($item);
}



sub summary
{
  my ($self) = @_;

  my @daemons = $self->daemons();

  if ( @daemons == 0 ) {
    return undef;
  }

  my $summary = new EBox::Summary::Module(__('OpenVPN daemons'));

  foreach my $daemon (@daemons) {
    my @daemonSummary = $daemon->summary();
    @daemonSummary or next;
	  
    my $name = shift @daemonSummary;
    my $section = new EBox::Summary::Section($name);

    while (@daemonSummary) {
      my ($valueName, $valueData) = splice(@daemonSummary, 0, 2);
      $section->add(new EBox::Summary::Value ($valueName, $valueData));
    }


    $summary->add($section);
  }


  return $summary;
}






sub statusSummary
{
    my ($self) = @_;
    return new EBox::Summary::Status('openvpn', __('OpenVPN service'), $self->running, $self->service);
}


sub _backupClientCertificatesDir
{
  my ($self, $dir) = @_;
  return $dir .'/clientCertificates';
}

sub dumpConfig
{
  my ($self, $dir) = @_;

  
  # save client's certificates
  my $certificatesDir = $self->_backupClientCertificatesDir($dir);
  EBox::FileSystem::makePrivateDir($certificatesDir);


  foreach my $client ($self->clients) {
    $client->backupCertificates($certificatesDir);
  }
}

sub restoreConfig
{
  my ($self, $dir) = @_;

  # restore client certificates
  my $certificatesDir = $self->_backupClientCertificatesDir($dir);

  my @clients = $self->clients();
  foreach my $client (@clients) {
    $client->restoreCertificates($certificatesDir);
  }
}


1;
