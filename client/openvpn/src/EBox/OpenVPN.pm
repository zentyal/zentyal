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
use EBox::Sudo;
use Perl6::Junction qw(any);
use EBox::OpenVPN::Server;
use EBox::OpenVPN::Client;
use EBox::OpenVPN::FirewallHelper;
use EBox::CA;
use EBox::CA::DN;
use EBox::NetWrappers qw();
use Error qw(:try);


use constant  MAX_IFACE_NUMBER => 999999; # this is the last number which prints correctly in ifconfig

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
    $self->_cleanConfigDir();
    $self->_doDaemon();
}

sub confDir
{
    my ($self) = @_;
    return $self->get_string('conf_dir');
}


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


sub _cleanConfigDir
{
    my ($self) = @_;

    my @privateDir    = map { $_->privateDir()  } $self->clients();
    my $anyPrivateDir = any @privateDir;

    my $confDir = $self->confDir;
    opendir my $DH, $confDir or throw EBox::Exceptions::Internal("Can not open $confDir: $!");
    my @dirContents =  readdir $DH;
    closedir $DH;

    foreach (@dirContents) {
      next if $_ =~ m/^[.]+$/;

      my $file = "$confDir/$_";

      if (EBox::Sudo::fileTest('-d', $file)) {
	next if ($file eq $anyPrivateDir);

	EBox::info("OpenVPN's leftover dir found: $file. It will be removed");
	EBox::Sudo::root("rm -rf $file");
      }
    }

}


# all openvpn daemons related methods
sub daemons
{
  my ($self) = @_;
  return (
	  $self->servers(),
	  $self->clients(),
	 );
}


sub activeDaemons
{
    my ($self) = @_;
    return grep { $_->service } $self->daemons();
}

sub daemonsNames
{
    my ($self) = @_;
    
    my @daemonsNames = (
			$self->serversNames(),
			$self->clientsNames(),
		       );
    return @daemonsNames;
}


# server-relate method

sub servers
{
    my ($self) = @_;
    my @servers = $self->serversNames();
    @servers = map { $self->server($_) } @servers;
    return @servers;
}


sub activeServers
{
    my ($self) = @_;
    return grep { $_->service } $self->servers();
}

sub serversNames
{
    my ($self) = @_;
    
    my @serversNames = @{ $self->all_dirs_base('server') };
    return @serversNames;
}

# a object server cache may be a good idea?
sub server
{
    my ($self, $name) = @_;
    
    my $server = new EBox::OpenVPN::Server ($name, $self);
    return $server;
}




sub newServer
{
    my ($self, $name, %params) = @_;

    $self->_createDaemonSkeleton($name, 'server');

    my $server;
    try {
	$server = $self->server($name);
	$server->setFundamentalAttributes(%params);
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("server/$name");
	$ex->throw();
    };

    return $server;
}





sub removeServer
{
    my ($self, $name) = @_;
    my $serverDir = "server/$name";

    if (! $self->dir_exists($serverDir)) {
	throw EBox::Exceptions::External __x("Unable to remove server {name} because it does not exist", name => $name);
    }

	
    $self->delete_dir($serverDir);
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

sub clients
{
    my ($self) = @_;
    my @clients = $self->clientsNames();
    @clients = map { $self->client($_) } @clients;
    return @clients;
}


sub activeClients
{
    my ($self) = @_;
    return grep { $_->service } $self->clients();
}

sub clientsNames
{
    my ($self) = @_;
    
    my @clientsNames = @{ $self->all_dirs_base('client') };
    return @clientsNames;
}


sub removeClient
{
    my ($self, $name) = @_;
    my $clientDir = "client/$name";

    if (! $self->dir_exists($clientDir)) {
	throw EBox::Exceptions::External __x("Unable to remove client {name} because it does not exist", name => $name);
    }

    $self->delete_dir($clientDir);
}

sub newClient
{
    my ($self, $name, %params) = @_;

    $self->_createDaemonSkeleton($name, 'client');

    my $client;
    try {
	$client = $self->client($name);
	$client->init(%params);
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("client/$name");
	$ex->throw();
    };

    return $client;
}



sub client
{
    my ($self, $name) = @_;
    
    my $client = new EBox::OpenVPN::Client ($name, $self);
    return $client;
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
  my ($self, $name, $prefix) = @_;

  $self->_checkName($name);

  my $ifaceNumber    = $self->_newIfaceNumber();  
  my $ifaceNumberKey = "$prefix/$name/iface_number";
  $self->set_int($ifaceNumberKey, $ifaceNumber); 
}


sub user
{
    my ($self) = @_;
    return $self->get_string('user');
}

sub group
{
    my ($self) = @_;
    return $self->get_string('group');
}


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

    if (!$self->service) {
	 return undef;
     }


    my @ifaces = map {
      $_->iface()
    }  $self->activeDaemons() ;

    my $portsByProto = $self->_portsByProtoFromServers($self->activeServers); 
    my $serversToConnect = $self->_serversToConnect();

    my $firewallHelper = new EBox::OpenVPN::FirewallHelper (
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
   else {
      my @activeDaemons = $self->activeDaemons();
      return @activeDaemons == 0 ? 1 : 0;      
    }
    
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

  system "/usr/bin/pgrep -f $bin";
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


sub ripDaemonRunning
{
  my ($self) = @_;

  # check for ripd and zebra daemons
  system "pgrep ripd";
  system "pgrep zebra" if $? != 0;

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

sub _invokeOnServers
{
  my ($self, $method, @methodParams) = @_;
  foreach my $server ($self->servers()) {
    my $method_r = $server->can($method);
    defined $method_r or throw EBox::Exceptions::Internal("No such method $method");
     $method_r->($server, @methodParams);
  }
}

sub _anyServerReturnsTrue
{
  my ($self, $method, @methodParams) = @_;
  foreach my $server ($self->servers()) {
    my $method_r = $server->can($method);
    defined $method_r or throw EBox::Exceptions::Internal("No such method $method");
    if ($method_r->($server, @methodParams)) {
      return 1;
    } 
  }

  return undef;
}


sub ifaceMethodChanged
{
  my ($self, @params) = @_;
  return $self->_anyServerReturnsTrue('ifaceMethodChanged', @params);
}


sub vifaceDelete
{
  my ($self, @params) = @_;
  return $self->_anyServerReturnsTrue('vifaceDelete', @params);
}


sub freeIface
{
  my ($self, @params) = @_;
  return $self->_invokeOnServers('freeIface', @params);
}

sub freeViface
{
  my ($self, @params) = @_;
  return $self->_invokeOnServers('freeViface', @params);
}


# Method: menu 
#
#       Overrides EBox::Module method.
#
sub menu
{
        my ($self, $root) = @_;
    
        my $item = new EBox::Menu::Item('url' => 'OpenVPN/Index',
                                        'text' => __('OpenVPN'));
	$root->add($item);
}


sub _externalAddresses
{
  my ($self) = @_;

  my $network = EBox::Global->modInstance('network');

  my @externalAddr = map {
    my $ifaceAddresses_r = $network->ifaceAddresses($_);
    @{  $ifaceAddresses_r }
  }  @{ $network->ExternalIfaces };

  # massage to a readable way
  @externalAddr  =  map {
      $_->{address} . '/' . $_->{netmask};
    } @externalAddr;

  return \@externalAddr;
}

sub summary
{
	my ($self) = @_;

	if ( $self->daemons()  == 0) {
	  return undef;
	}


	my $summary = new EBox::Summary::Module(__('OpenVPN daemons'));

       # prefetch data for servers summary
	my $externalAddresses = $self->_externalAddresses();

	foreach my $server ($self->servers) {
	    my $section = new EBox::Summary::Section(__x('Server {name}', name => $server->name));

	    my $service = $server->service ? __('Enabled') : __('Disabled');
	    $section->add(new EBox::Summary::Value (__('Service'), $service));

	    my $running = $server->running ? __('Running') : __('Stopped');
	    $section->add(new EBox::Summary::Value (__('Daemon status'), $running));

	    $self->_addServerAddressesToServerSection( $section, $server, $externalAddresses);

	    my $proto   = $server->proto();
	    my $port    = $server->port();
	    my $portAndProtocol = "$port/\U$proto";
	    $section->add(new EBox::Summary::Value (__('Port'), $portAndProtocol));

	    my $subnet  = $server->subnet . '/' . $server->subnetNetmask;
	    $section->add(new EBox::Summary::Value (__('VPN subnet'), $subnet));

	    $summary->add($section);
	}
				    

	foreach my $client ($self->clients) {
	  my $section = new EBox::Summary::Section(__x('Client {name}', name => $client->name));

	  my $service = $client->service ? __('Enabled') : __('Disabled');
	  $section->add(new EBox::Summary::Value (__('Service'), $service));

	  my $running = $client->running ? __('Running') : __('Stopped');
	  $section->add(new EBox::Summary::Value (__('Daemon status'), $running));

	  my $proto   = $client->proto();
	  my @servers = @{  $client->servers  };
	  # XXX only one server supported now!
	  my ($addr, $port) = @{ $servers[0]  };
	  my $server = "$addr $port/\U$proto";
	  $section->add(new EBox::Summary::Value (__('Connection target'), $server));

	  $summary->add($section);
	}

	return $summary;
}





sub _addServerAddressesToServerSection
{
  my ($self, $section, $server, $externalAddr_r) = @_;

  my @serverAddress;
  my $localAddress = $server->localAddress();
  if ($localAddress) {
    push @serverAddress, $localAddress;
  } 
  else {
    @serverAddress = @{ $externalAddr_r };
  }

  foreach my $addr (@serverAddress) {
    $section->add(new EBox::Summary::Value (__('Local address'), $addr));
  }

}

sub statusSummary
{
    my ($self) = @_;
    return new EBox::Summary::Status('openvpn', __('OpenVPN service'), $self->running, $self->service);
}

1;
