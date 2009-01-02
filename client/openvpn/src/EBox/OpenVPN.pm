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
use base qw(EBox::GConfModule 
           EBox::NetworkObserver  EBox::LogObserver
           EBox::FirewallObserver EBox::CA::Observer
           EBox::ServiceModule::ServiceInterface);

use strict;
use warnings;

use Perl6::Junction qw(any);
use Error qw(:try);

use EBox::Gettext;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::Sudo;
use EBox::Validate;
use EBox::OpenVPN::Server;
use EBox::OpenVPN::Client;
use EBox::OpenVPN::FirewallHelper;
use EBox::OpenVPN::LogHelper;
use EBox::CA;
use EBox::CA::DN;
use EBox::NetWrappers qw();
use EBox::FileSystem;

use Perl6::Junction qw(any);
use Error qw(:try);
use File::Slurp;

use constant MAX_IFACE_NUMBER => 999999;  # this is the last number which prints
                                          # correctly in ifconfig
use constant RESERVED_PREFIX => 'R_D_';

my @daemonTypes   = qw(server client); # in the daemons method they will appear in this order
my $anyDaemonType = any @daemonTypes;

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'openvpn', printableName => __('openVPN'));
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
    my ($self) = @_;

    $self->_writeConfFiles();
    $self->_prepareLogFiles();
    $self->_cleanupDeletedDaemons();
    $self->_doDaemon();
}


# Method: usedFiles
#
#	Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
	return [
		{
		 'file' => '/etc/quagga/daemons',
		 'module' => 'openvpn',
		 'reason' => __('To configure Quagga to run ripd and zebra')
		},
		{
		 'file' => '/etc/quagga/debian.conf',
		 'module' => 'openvpn',
         'reason' => __('To configure Quagga to listen on the given interfaces')
		},
		{
		 'file' => '/etc/quagga/zebra.conf',
		 'module' => 'openvpn',
         'reason' => __('Main zebra configuration file')
		},
		{
		 'file' => '/etc/quagga/ripd.conf',
		 'module' => 'openvpn',
         'reason' => __('To configure ripd to exchange routes with client '.
                        'to client connections')
		}
	       ];
}
# Method: enableActions
#
#	Override EBox::ServiceModule::ServiceInterface::enableActions
#
sub enableActions
{
    EBox::Sudo::root(EBox::Config::share() . '/ebox-openvpn/ebox-openvpn-enable');
}


# Method: serviceModuleName 
#
#	Override EBox::ServiceModule::ServiceInterface::serviceModuleName
#
sub serviceModuleName
{
	return 'openvpn';
}

#  Method: enableModDepends
#
#   Override EBox::ServiceModule::ServiceInterface::enableModDepends
#
sub enableModDepends 
{
    return ['network'];
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
	$daemon->writeUpstartFile();
    }
}

sub _prepareLogFiles
{
    my ($self) = @_;

    my $logDir = $self->logDir();
    foreach my $name (@{$self->daemonsNames()}) {
        for my $file ("$logDir/$name.log", "$logDir/status-$name.log") {
            try {
                EBox::Sudo::root("test -e $file");
            } otherwise {
                EBox::Sudo::root("touch $file");
            };
            EBox::Sudo::root("chown root:ebox $file");
            EBox::Sudo::root("chmod 0640 $file");
        }
    }

    # recreate log rotate configuration file
    my @logFiles = map {
        $_->logFile()
    } $self->daemons();

    my  $fileMode = {
                     uid  => 0,
                     gid  => 0,
                     mode => '0644',
    };

    # XXX ugly hack until writeConfFile had different behaviour
    EBox::GConfModule->writeConfFile('/etc/logrotate.d/ebox-openvpn',
                         '/openvpn/logrotate.mas',
                         [
                          logFiles => \@logFiles,
                         ],
                         $fileMode,
                        )
}

sub _cleanupDeletedDaemons
{
    my ($self) = @_;

    $self->dir_exists('deleted') or return;


    my %deletedDaemons = % { $self->_deletedDaemons() };

    while (my ($name, $properties) = each %deletedDaemons) {
        try {
            my $class = $properties->{class};
            my $type  = $properties->{type};
            try {
                $class->stopDeletedDaemon($name, $type);
            } otherwise {
                EBox::error("Couldn't stop deleted daemon $name");
            };

            for my $entry  (@{ $properties->{filesToDelete}}) {
                try {
                     EBox::Sudo::root(" rm -rf $entry");
                } otherwise {
                    EBox::error("Couldn't remove $entry");
                };
            }
        }
        otherwise {
            my $ex = shift;
            EBox::error("Failure when cleaning up the deleted openvpn daemon $name. Possibly you will need to do some manual cleanup");
            $ex->throw();
        };
    }

    $self->delete_dir('deleted');

# this is to avoid mark the modules as changed bz the removal of deleted information
# XXX TODO: reimplement using ebox state
    my $global = EBox::Global->getInstance();
    $global->modRestarted('openvpn');
}


sub _deletedDaemons 
{
  my ($self) = @_;

  my %deletedDaemons = ();
  foreach my $daemonName (@{ $self->all_dirs_base('deleted') }) {
    $deletedDaemons{$daemonName} = {};
    $deletedDaemons{$daemonName}->{class} = $self->get_string("deleted/$daemonName/class");
    $deletedDaemons{$daemonName}->{type} = $self->get_string("deleted/$daemonName/type");

    my @filesToDelete = map { 
      $self->get_string($_);
    }    $self->all_entries ("deleted/$daemonName/files") ;
    $deletedDaemons{$daemonName}->{filesToDelete} = [ sort @filesToDelete];
  }


  return  \%deletedDaemons;
}

sub notifyDaemonDeletion 
{
  my ($self, $name, %params) = @_;
  $self  or throw EBox::Exceptions::MissingArgument("you must call this on a object");
  $name  or throw EBox::Exceptions::MissingArgument("you must supply the name of tssub firewalhe daemon to delete");
  exists $params{class} or
    throw EBox::Exceptions::MissingArgument('class');
  exists $params{type} or
    throw EBox::Exceptions::MissingArgument('type');


  my @files = exists $params{files} ? @{ $params{files} } : ();

  $self->set_string("deleted/$name/class", $params{class});
  $self->set_string("deleted/$name/type", $params{type});

  my $id = 0;
  foreach my $file (@files) {
    $self->set_string("deleted/$name/files/$id", $file);
    $id += 1;
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

  return \@daemonsNames;
}



sub _newDaemon
{
    my ($self, $type, $name, @initParams) = @_;
    ($type eq $anyDaemonType) or throw EBox::Exceptions::Internal("Unsupported daemon type: $type");

    $self->_checkName($name);
    # we will check the correctness of the name's prefix after because we have to
    # set some internal state before...
      
    $self->_createDaemonSkeleton($type, $name);

    my $daemon;
    try {
	$daemon = $self->$type($name);
	$daemon->init(@initParams);

	$self->_checkNamePrefix($name, $daemon->internal());
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("$type/$name");
	$ex->throw();
    };

    return $daemon;
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
#   List the names of all servers registered in the module
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
# Method: serverExists
#
#   returns wether a given server exists or not
#
# Parameters:
#
#    name - the server's name
#
# Returns:
#  true if the server exists, false otherwise
#  
#
sub serverExists
{
  my ($self, $name) = @_;
  defined $name or throw EBox::Exceptions::MissingArgument();
    
    
  my $serverDir = "server/$name";
  return $self->dir_exists($serverDir);
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

    my $server = $self->_newDaemon('server', $name, @initParams);

    $self->notifyLogChange();

    return $server; 
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
#   List the names of all clients registered in the module
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


# Method: userClientsNames
#
#   List the names of all clents registeredby the user
# Returns:
#
#   list - a list with client's names
#
sub userClientsNames
{
    my ($self) = @_;
 
    my @clients = grep { not $_->internal } $self->clients();
    my @clientsNames = map { $_->name } @clients;

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
# Exceptions:
#
#   <EBox::Exceptions::Internal> - throw if the client does not exist
#
sub client
{
  my ($self, $name) = @_;
  my $client = new EBox::OpenVPN::Client ($name, $self);
  return $client;
}

#
# Method: clientExists
#
#   return whether a given client exists or not
#
# Parameters:
#
#    name - the client's name
#
# Returns:
#  true if the client exists, false otherwise
#  
#

sub clientExists
{
  my ($self, $name) = @_;
  defined $name or throw EBox::Exceptions::MissingArgument();
    
  my $clientDir = "client/$name";
  return $self->dir_exists($clientDir);
}
#

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
#  servers - client's servers list. Must be a list reference
#  containing a server and a port as an array ref.  The servers may be
#  hostnames or IP addresses.
#  proto - the client's IP protocol.
#
#  caCertificate  - Path to the CA's certificate.
#  certificate    - Path to the client's certificate.
#  certificateKey - Path to the client's certificate key.
#
#  service - whether the client is enabled or disabed. *(default: disabled)*
#
#  hidden  - whether the client is hidden from the web GUI *(default: false)*
#  * Named parameters except for first one
#
# Returns:
#
#   <EBox::OpenVPN::Client> - the client object
#
sub newClient
{
  my ($self, $name, @initParams) = @_;

  my $client = $self->_newDaemon('client', $name, @initParams);

  $self->notifyLogChange();

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

  unless ( EBox::Validate::checkName($name) ) {
    throw EBox::Exceptions::External ( __x(
					   'Invalid name {name}. Only alphanumerics '
                                           . 'and underscores characters are allowed '
                                           . 'with a maximum length of 20 characters',
					   name => $name,
					  )
				     );
  }

  my @names = ($self->serversNames(), $self->clientsNames());
  if ($name eq any(@names)) {
    throw EBox::Exceptions::DataExists(data => "OpenVPN instance's name", value => $name  );
  }

  my @deletedNames = keys %{ $self->_deletedDaemons() };
  if ($name eq any @deletedNames) {
    throw EBox::Exceptions::External(
        __x(
	    'Cannot use the name {name} because a  deleted daemon which has not been cleaned up has the same name.' 
             . ' If you want to use this name, please save changes first',
	    name => $name,
     ));
  }

}

sub _checkNamePrefix
{
  my ($self, $name, $internalDaemon) = @_;

  my $reservedPrefix = $self->reservedPrefix;
  my $isReservedName   = ( $name =~ m/^$reservedPrefix/);

  if ($isReservedName and (not $internalDaemon)) {
    throw EBox::Exceptions::External(__x(
					 'Invalid name {name}. Name which begins with the prefix {pf} are reserved for internal use',
					 name => $name,
					 pf => $reservedPrefix,
					)
				    );

  }
  elsif (not $isReservedName and $internalDaemon) {
    throw EBox::Exceptions::External( __x(
					  'Invalid name {name}. A internal daemon must have a name which begins with the prefix {pf}',
					  name => $name,
					  pf => $reservedPrefix,
					 )
				    );
  } 
}


#
# Method: reservedPrefix
#
#    Returns the prefix used in the name of daemons for internal use.
#    User's daemons cannot use it and internal daemons must use it.
#
# Returns:
#
#    String - the reserved prefix
#
sub reservedPrefix
{
  return RESERVED_PREFIX;
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
#    Gets the user will be used to run the openvpn daemons
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
#    Gets the group will be used to run the openvpn daemons
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

    my @servers = $self->servers();
    foreach my $server (@servers) {
      if ($server->usesPort($proto, $port, $iface)) {
	return 1;
      }
    }

    return undef;
}

sub firewallHelper
{
    my ($self) = @_;

    my $service = $self->service();

    my @activeServers =  $self->activeServers() ;

    my @ifaces = map {
       $_->iface();
    } @activeServers;
    
    my @ports = map {
            my $port = $_->port();
            my $proto = $_->proto();
            my $external = $_->runningOnInternalIface ? 0 : 1;
            
            { port => $port, proto => $proto, external => $external }
        }  @activeServers;
    

    my @networksToMasquerade = map {
            my $network = $_->subnet();
            my $mask    = $_->subnetNetmask();
            my $cidrNet = EBox::NetWrappers::to_network_with_mask($network,
                            $mask);
            $cidrNet
            } grep { $_->masquerade() and $_->can('subnet') } @activeServers;


    my $serversToConnect = $self->_serversToConnect();

    my $firewallHelper = new EBox::OpenVPN::FirewallHelper (
							    service          => $service,
							    ifaces           => \@ifaces,
							    ports     => \@ports,
							    serversToConnect => $serversToConnect,
							    networksToMasquerade => \@networksToMasquerade,
							    
							   );
    return $firewallHelper;
}



#  Method: CAIsReady
#
# return if the CA is ready to support servers (valid CA and at least one
# certificate are required for this)
sub CAIsReady
{
  my $ca = EBox::Global->modInstance('ca');
  if (not  $ca->isCreated) {
    return 0;
  }
  
  my $nValidCertificates = grep {
     $_->{state} eq 'V'
  } @{  $ca->listCertificates  };

  my $ready = ($nValidCertificates >= 2); # why 2? bz we need the CA certificate and
                                     # another certifcate for the server (when
                                     #  the CA is invalid all the other certs
                                     #  are invalid so if we have valid
                                     #  certificates we are sure one of the is
                                     #  the CA cert)

  return $ready;
}








sub service
{
  my ($self) = @_;

  return $self->isEnabled();
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
    my @activeUserDaemons = grep { (not $_->service) and (not $_->internal) } $self->daemons;
    return @activeUserDaemons == 0 ? 1 : 0;      
  }
  
  return 0;
}

sub userRunning
{
  my ($self) = @_;
  my @userDaemons = grep { not $_->internal } $self->daemons;

  foreach my $userDaemon (@userDaemons) {
    return 1 if $userDaemon->running;
  }

  return 0;   # XXX control that there isn't any user daemon incorrectly running
}


sub _startDaemon
{
  my ($self) = @_;


  try {
    my @daemons =  grep { $_->service   } $self->daemons;

    foreach my $daemon (@daemons) {
      $daemon->start();
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

    my @daemons = $self->daemons();

    foreach my $daemon (@daemons) {
      $daemon->stop();
    }
}

sub _runningInstances
{
  my ($self) = @_;

  my @daemons = $self->daemons();
  foreach my $d (@daemons) {
    return 1 if $d->running;
  }

  return 0;
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
			insecurePasswd => _insecureRipPasswd(),
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

sub changeIfaceExternalProperty # (iface, external)
{
   my ($self, @params) = @_;
  return $self->_invokeOnDaemons('changeIfaceExternalProperty', @params);     
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

sub openVPNWidget
{
    my ($self, $widget, $ovpn) = @_;
    my $section = new EBox::Dashboard::Section($ovpn);
    $widget->add($section);

    my $path = $self->logDir() . '/' . 'status-' . $ovpn . '.log';
    my @status = read_file($path);
    my $state = 0;

    my $titles = [__('Common name'),__('Address'), __('Connected since')];
    my $rows = {};

    for my $line (@status) {
        chomp($line);
        if($state == 0) {
            if($line =~m/^Common Name,/) {
                $state = 1;
            }
        } elsif($state == 1) {
            my @fields = split(',', $line);
            if(@fields != 5) {
                last;
            }
            my ($cname,$address,$recv,$sent,$date) = @fields;
            $rows->{$cname} = [$cname,$address,$date];
        }
    }
    my $ids = [sort keys %{$rows}];
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
        __('No users connected to the VPN')));
}

sub openVPNDaemonsWidget
{
    my ($self, $widget) = @_;

    my @daemons = $self->daemons();

    if ( @daemons == 0 ) {
        return undef;
    }

    foreach my $daemon (@daemons) {
        my @daemonSummary = $daemon->summary();
        @daemonSummary or next;

        my $name = shift @daemonSummary;
        my $section = new EBox::Dashboard::Section($daemon->name(),$name);

        while (@daemonSummary) {
            my ($valueName, $valueData) = splice(@daemonSummary, 0, 2);
            $section->add(new EBox::Dashboard::Value ($valueName, $valueData));
        }
        $widget->add($section);
    }
}

sub widgets
{
    my ($self) = @_;

    my $openvpns = $self->daemonsNames();

    my $widgets = {
        'openvpndaemons' => {
            'title' => __("OpenVPN daemons"),
            'widget' => \&openVPNDaemonsWidget,
            'default' => 1
        }
    };
    foreach my $ovpn (@{$openvpns}) {
        my $widget = {
            'title' => $ovpn,
            'widget' => \&openVPNWidget,
            'parameter' => $ovpn
        };
        $widgets->{'vpn' . $ovpn} = $widget;
    }
    return $widgets;
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

# log observer stuff
sub domain
{
  return 'ebox-openvpn';
}

sub logHelper
{
  my ($self, @params) = @_;
  return EBox::OpenVPN::LogHelper->new($self, @params);
}


sub tableInfo
{
  my ($self) = @_;
  my $titles = {
		timestamp => __('Date'),
		event    => __('Event'),
		daemon_name => ('Daemon'),
		daemon_type => __('Type'),
		from_ip     => __(q{Remote IP}),
		from_cert     => __(q{Remote Certificate}),
	       };
  my @order = qw(timestamp event daemon_name daemon_type from_ip from_cert );

  my $events = {  
		initialized => __('Initialization sequence completed'),

		verificationIssuerError => __('Certificate issuer not authorized'),
		verificationNameError  => __('Certificate common name not authorized'),
		verificationError => __('Certificate verification failed'),
		
		connectionInitiated => __('Client connection initiated'),
		connectionReset     => __('Client connection terminated'),

		serverConnectionInitiated => __('Connection to server initiated'),
		connectionResetByServer => __('Server connection terminated'),
	       };
  
  return [{
	  name => __('OpenVPN'),
	  index => 'openvpn',
	  titles => $titles,
	  'order' => \@order,
	  'tablename' => 'openvpn',
          'timecol' => 'timestamp',
	  'filter' => ['daemon_name', 'from_ip', 'from_cert'],
	  'events' => $events,
	  'eventcol' => 'event'
	 }];

}

sub _insecureRipPasswd
{
    my $insecure = EBox::Config::configkey('insecure_rip_conf');
    unless (defined($insecure)) {
        return undef;
    }
    if ($insecure eq 'no') {
        return 0;
    } elsif ($insecure eq 'yes') {
        return 1;
    } else {
        thore EBox::Exceptions::External(
            __('You must set insecure_rip_conf to yes or no'));
    }
}
# Method: notifyLogChange
#
#   this is used to notify the log module of changes which will affect the logs
sub notifyLogChange
{
  my ($self) = @_;

  my $logs = EBox::Global->modInstance('logs');
  defined $logs or return;

  $logs->setAsChanged();
}

1;
