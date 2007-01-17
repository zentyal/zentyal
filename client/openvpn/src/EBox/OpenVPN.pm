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
use base qw(EBox::GConfModule EBox::FirewallObserver EBox::DHCP::StaticRouteProvider EBox::CA::Observer);

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

    my $confDir = $self->confDir;

    my @daemons = $self->daemons();
    foreach my $daemon (@daemons) {
	$daemon->writeConfFile($confDir);
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
    my $type = exists $params{type} ? delete $params{type} : 'one2many'; # type is ignored for now.. Now we use only a type of server

    $self->_checkName($name);
 
    
    $self->set_string("server/$name/type" => $type);
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
	throw EBox::Exceptions::External __x("Unable to remove because there is not a openvpn server named {name}", name => $name);
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
	throw EBox::Exceptions::External __x("Unable to remove because there is not a openvpn client named {name}", name => $name);
    }

	
    $self->delete_dir($clientDir);
}

sub newClient
{
    my ($self, $name, %params) = @_;


    $self->_checkName($name);
 
    my $holderKey = "client/$name/holder";
    $self->set_string($holderKey => 1); # we have to  set some data to bootstrap the client because we can not create empty conf dirs
    my $client;
    try {
	$client = $self->client($name);
	$client->init(%params);
	$self->unset($holderKey);
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("client/$name");
	$ex->throw();
    };

    return $client;
}


# a object client cache may be a good idea?
sub client
{
    my ($self, $name) = @_;
    
    my $client = new EBox::OpenVPN::Client ($name, $self);
    return $client;
}





sub _checkName
{
  my ($self, $name) = @_;

   unless ( $name =~ m{^\w+$} ) {
	throw EBox::Exceptions::External (__x("{name} is a invalid name for a OpenVPN instance. Only alphanumerics and underscores are allowed", name => $name) );
    }

  my @names = ($self->serversNames(), $self->clientsNames());
  if ($name eq any(@names)) {
      throw EBox::Exceptions::DataExists(data => "OpenVPN instance's name", value => $name  );
    }

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

    my $portsByProto = $self->_portsByProtoFromServers($self->activeServers); 

    my $firewallHelper = new EBox::OpenVPN::FirewallHelper (portsByProto => $portsByProto);
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
	    $self->_startDaemon();
	}
    }
    else {
	if ($running) {
	    $self->_stopDaemon();
	  }
    }
}

sub running
{
    my ($self) = @_;
    my $bin = $self->openvpnBin;
    system "/usr/bin/pgrep -f $bin";
    return ($? == 0) ? 1 : 0;
}


sub _startDaemon
{
    my ($self) = @_;

    my @daemons =  grep { $_->service } $self->daemons();
    foreach my $daemon (@daemons) {
	my $command = $self->rootCommandForStartDaemon($daemon->confFile, $daemon->name);
	EBox::Sudo::root($command);
    }
}

sub _stopDaemon
{
    my ($self) = @_;
    my $stopCommand = $self->rootCommandForStopDaemon();
    EBox::Sudo::root($stopCommand);
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
    EBox::Service::manage('openvpn','stop');
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



sub staticRoutes
{
  my ($self) = @_;

  $self->service() or return [];
  
  my @servers =  grep { $_->service } $self->servers();

  my @staticRoutes;
  foreach my $server (@servers) {
    push @staticRoutes, $server->staticRoutes(); 
  }

  return \@staticRoutes;
}



# ca observer stuff

sub certificateRevoked
{
  my ($self, @params) = @_;
  foreach my $server ($self->servers()) {
    if ($server->certificateRevoked()) {
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

# Method: menu 
#
#       Overrides EBox::Module method.
#
sub menu
{
        my ($self, $root) = @_;
    
        my $item = new EBox::Menu::Item('url' => 'OpenVPN/Index',
                                        'text' => __('OpenVPN server'));
	$root->add($item);
}

sub summary
{
	my ($self) = @_;
	my $summary = new EBox::Summary::Module(__("OpenVPN servers"));

	foreach my $server ($self->servers) {
	    my $section = new EBox::Summary::Section($server->name);

	    my $service = $server->service ? __('Enabled') : __('Disabled');
	    $section->add(new EBox::Summary::Value (__("Service"), $service));

	    my $running = $server->running ? __('Running') : __('Stopped');
	    $section->add(new EBox::Summary::Value (__("Daemon status"), $running));

	    my $subnet  = $server->subnet . '/' . $server->subnetNetmask;
	    $section->add(new EBox::Summary::Value (__("VPN subnet"), $subnet));

	    $summary->add($section);
	}
				    

	return $summary;
}

sub statusSummary
{
    my ($self) = @_;
    return new EBox::Summary::Status('openvpn', __('OpenVPN service'), $self->running, $self->service);
}

1;
