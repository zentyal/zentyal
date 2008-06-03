package EBox::OpenVPN::Client;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkHost);
use EBox::NetWrappers;
use EBox::Sudo;
use EBox::FileSystem;
use EBox::Gettext;
use EBox::OpenVPN::Client::ValidateCertificate;
use EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox;

use Params::Validate qw(validate_pos SCALAR);
use Error qw(:try);


sub new
{
    my ($class, $name, $openvpnModule) = @_;
   
    my $prefix= 'client';

    my $self = $class->SUPER::new($name, $prefix, $openvpnModule);
    bless $self, $class;

    return $self;
}



# Method: setProto
#
#  sets the client's protocol
#
# Parameters:
#    proto - protocol. Must be 'tcp' or 'udp'
sub setProto
{
    my ($self, $proto) = @_;

    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "client's protocol", value => $proto, advice => __("The protocol only may be tcp or udp.")  );
    }

    $self->setConfString('proto', $proto);
}

# Method: proto
#
# Returns:
#  returns the client's protocol
sub proto
{
    my ($self) = @_;
    return $self->getConfString('proto');
}



sub setCertificateFiles
{
  my ($self, $caCert, $cert, $pkey) = @_;
  EBox::OpenVPN::Client::ValidateCertificate::check($caCert, $cert, $pkey);

  $self->_setPrivateFile('caCertificate', $caCert);
  $self->_setPrivateFile('certificate' , $cert);
  $self->_setPrivateFile('certificateKey', $pkey);
}



# Method: caCertificate
#
# Returns:
#  returns the path to the CA certificate
sub caCertificate
{
  my ($self) = @_;
  return $self->getConfString('caCertificate');
}



# Method: certificate
#
# Returns:
#  returns the path to the certificate
sub certificate
{
  my ($self) = @_;
  return $self->getConfString('certificate');
}


# Method: certificateKey
#
# Returns:
#  returns the path to the private key
sub certificateKey
{
  my ($self) = @_;
  return $self->getConfString('certificateKey');
}



# Method: privateDir
#
#  gets the private dir used by the client ot store his certificates
#   and keys if it does not exists it will be created
#
# Returns:
#  returns the client's protocol
sub privateDir
{
  my ($self) = @_;

  my $openVPNConfDir = $self->_openvpnModule->confDir();
  my $dir = $self->confFile($openVPNConfDir) . '.d';

  if (not EBox::Sudo::fileTest('-d', $dir)) {
    if  ( EBox::Sudo::fileTest('-e', $dir) ) {
      throw EBox::Exceptions::Internal("$dir exists but is not a directory");
    }

    # create dir if it does not exist
    EBox::Sudo::root("mkdir --mode 0700  $dir");
  } 


  return $dir;
}


#  Method: setRipPasswd
#
#     set the password used by this daemon to secure RIP transmissions
#
#     Parameters:
#        passwd - not empty string
sub setRipPasswd
{
  my ($self, $passwd) = @_;
  
  $passwd or
      throw EBox::Exceptions::External(
         __('The client must have a non-empty RIP password')
				      );

  $self->setConfString('ripPasswd', $passwd);
}



sub _setPrivateFile
{
  my ($self, $type, $path) = @_;

  if (not EBox::Sudo::fileTest('-r', $path)) {
    throw EBox::Exceptions::Internal('Cannot read private file source' );
  } 

  my $privateDir = $self->privateDir();
  
  my $newPath = "$privateDir/$type"; 

  try {
    EBox::Sudo::root("cp '$path' '$newPath'");
    EBox::Sudo::root("chmod 0400 '$newPath'");
    EBox::Sudo::root("chown 0.0 '$newPath'");
  }
  otherwise {
    EBox::Sudo::root("rm -f '$newPath'");
  };

  $self->setConfString($type, $newPath);


}




# Method: daemonFiles
# Override <EBox::OpenVPN::Daemon::daemonFiles> method
sub daemonFiles
{
  my ($self) = @_;

  my @files = $self->SUPER::daemonFiles();
  push @files, $self->privateDir();

  return @files;
}


sub setService # (active)
{
  my ($self, $active) = @_;
  ($active and $self->service)   and return;
  (!$active and !$self->service) and return;

  if ($active) {
    if ($self->_availableIfaces() == 0) {
      throw EBox::Exceptions::External('Cannot activate OpenVPN clients because there is not any network interface available');
    }
  }

  $self->setConfBool('active', $active);

  # notifiy logs module so it no longer observes the lof gile of this daemon
  $self->_openvpnModule->notifyLogChange();
}


sub service
{
   my ($self) = @_;
   return $self->getConfBool('active');
}


sub confFileTemplate
{
  my ($self) = @_;
  return "openvpn/openvpn-client.conf.mas";
}

sub confFileParams
{
  my ($self) = @_;
  my @templateParams;

  push @templateParams, (dev => $self->iface);

  my @paramsNeeded = qw(name caCertificate certificate certificateKey  user group proto );
  foreach my $param (@paramsNeeded) {
    my $accessor_r = $self->can($param);
    defined $accessor_r or die "Cannot found accessor for param $param";
    my $value = $accessor_r->($self);
    defined $value or next;
    push @templateParams, ($param => $value);
  }

  push @templateParams, (servers =>  $self->servers() );


  return \@templateParams;
}

# Method: servers
#
# gets the servers to which the client will try to connecet
#
# Returns:
#  a reference to the list of server. Each item in the list of 
#  servers is a reference to a list which contains the IP address
#  and port of one server
sub servers
{
  my ($self) = @_;

  my @serverAddrs = @{ $self->allConfEntriesBase('servers') };
  my @servers = map {
    my $port = $self->getConfInt("servers/$_");
    [ $_ => $port ]
  } @serverAddrs;

  
  return \@servers;
}

# Method: setServers
#
# sets the servers to which the client will try to connecet
#
# Parameters:
#  servers_r: a reference to the list of server. Each item in the list of 
#  servers is a reference to a list which contains the  address
#  and port of one server
sub setServers
{
  my ($self, $servers_r) = @_;
  my @servers = @{ $servers_r };
  (@servers > 0) or throw EBox::Exceptions::External(__('You must supply at least one server for the client'));


  foreach my $serverParams_r (@servers) {
    $self->_checkServer(@{  $serverParams_r  });
  }

  $self->deleteConfDir('servers');

  foreach my $serverParams_r (@servers) {
    my ($addr, $port) = @{  $serverParams_r  };
    $self->setConfInt("servers/$addr", $port);
  }
}


# Method: addServer
#
# adds a server to the list of servers 
#
# Parameters:
#       addr - address of the server
#       port - server's port
sub addServer
{
  my ($self, $addr, $port) = @_;

  $self->_checkServer($addr, $port);

  $self->setConfInt("servers/$addr", $port);
}



sub _checkServer
{
  my ($self, $addr, $port) = @_;

  checkHost($addr, __(q{Server's address}));
  checkPort($port, __(q{Server's port}));
}

# Method: removeServer
#
# removes a server from the list of servers 
#
# Parameters:
#       addr - address of the server
# Todo:
#   it must use address AND port to discriminate between servers
sub removeServer
{
  my ($self, $addr) = @_;

  my $serverKey = "servers/$addr";

  if (!$self->confDirExists($serverKey)) {
    throw EBox::Exceptions::External("Requested server does not exist");
  }


  $self->unsetConf($serverKey);
}


# Method: init
#
#  initialisation method
#
# Parameters: 
#
#  *( named parameters)*   
#
#  servers - client's servers list. Must be a list reference. The servers may be
#  hostnames or IP addresses.
#  proto - the client's IP protocol.
#
#  caCertificate - Path to the CA's certificate.
#  certificate  -  Path to the client's certificate.
#  certificateKey    -  Path yo the client's certificate key.
#  ripPasswd      - rip password from the server
#
#  service - wether the client is enabled or disabed. *(Default: disabled)*
#
#  internal  - wethet the client is hidden from the web GUI *(default: false)*
sub init
{
    my ($self, %params) = @_;


    if ($params{bundle}) {
      %params = (%params, EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox->initParamsFromBundle($params{bundle}) );
    }

    try {
      (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the client");
      (exists $params{caCertificate}) or throw EBox::Exceptions::External __("The CA certificate is needed");
      (exists $params{certificate}) or throw EBox::Exceptions::External __("The client certificate must be specified");
      (exists $params{certificateKey}) or throw EBox::Exceptions::External __("The client private key must be specified");
      (exists $params{servers}) or throw EBox::Exceptions::External __("Servers must be supplied to the client");

      
      exists $params{service} or $params{service} = 0;
      exists $params{internal}  or $params{internal}  = 0;

      # ripPasswd is not neccesary for internal clietns bz 
      if (not exists $params{internal}) {
	(exists $params{ripPasswd}) or 
	  throw EBox::Exceptions::External __("Server's tunnel password missing");
      }

      
    $self->setCertificateFiles($params{caCertificate}, $params{certificate}, $params{certificateKey});
      
   my @attrs = qw(proto servers service internal ripPasswd);
      foreach my $attr (@attrs)  {
	if (exists $params{$attr} ) {
	  my $mutator_r = $self->can("set\u$attr");
	  defined $mutator_r or die "Not mutator found for attribute $attr";
	  $mutator_r->($self, $params{$attr});
	}
      }


    }
    finally {
      if ($params{bundle}) {
	system 'rm -rf ' . $params{tmpDir};
      }
    };
}




sub ripDaemon
{
  my ($self) = @_;

  # internal client don't need to push routes to the server
  return undef if $self->internal();
  
  my $iface = $self->ifaceWithRipPasswd();
  return { iface => $iface, redistribute => 1 };
}

sub ifaceMethodChanged
{
  my ($self, $iface, $oldmethod, $newmethod) = @_;
  if ($newmethod eq 'nonset') {
    return 1 if $self->_availableIfaces() == 1;
  }

  return undef;
}


sub vifaceDelete
{
  my ($self, $iface, $viface) = @_;

  return 1 if $self->_availableIfaces() == 1;
  return undef;
}


sub freeIface
{
  my ($self, $iface) = @_;
  my $ifaces = $self->_availableIfaces();
  if ($ifaces == 1) {
    $self->setService(0);
    EBox::warn("OpenVPN client " . $self->name . " was deactivated because there is not any network interfaces available");
  }
}

sub freeViface
{
  my ($self, $iface, $viface) = @_;
  $self->freeIface($viface); 
}

sub changeIfaceExternalProperty # (iface, external)
{
   my ($self, $iface, $external) = @_;
   # no effect for openvpn clients. Except that the server may not be reacheable
   # anymore but we don't check this in any moment..
   return;
}

sub _availableIfaces
{
  my ($self) = @_;

  my $network = EBox::Global->modInstance('network');
  my @ifaces = @{ $network->ExternalIfaces };
  # XXX it should care of internal ifaces only until we close #391
  push @ifaces, @{ $network->InternalIfaces };

  return scalar @ifaces;
}

sub summary
{
  my ($self) = @_;

  if ($self->internal) { # no summary for internal clients
    return ();
  }

  my @summary;
  push @summary, __x('Client {name}', name => $self->name);

  my $service = $self->service ? __('Enabled') : __('Disabled');
  push @summary,__('Service'), $service;

  my $running = $self->running ? __('Running') : __('Stopped');
  push @summary,__('Daemon status'), $running;

  my $proto   = $self->proto();
  my @servers = @{  $self->servers  };
  # XXX only one server supported now!
  my ($addr, $port) = @{ $servers[0]  };
  my $server = "$addr $port/\U$proto";
  push @summary,__('Connection target'), $server;


  my $ifAddr = $self->ifaceAddress();
  if ($ifAddr) {
    push @summary, (__('VPN interface address'), $ifAddr);
  }
  else {
    push @summary, (__('VPN interface address'), __('No active'));
  }


  return @summary;
}


sub backupCertificates
{
  my ($self, $dir) = @_;

  my $d = "$dir/" . $self->name;
  EBox::FileSystem::makePrivateDir($d);

  EBox::Sudo::root('cp ' . $self->caCertificate . " $d/caCertificate" );
  EBox::Sudo::root('cp ' . $self->certificate   . " $d/certificate" );
  EBox::Sudo::root('cp ' . $self->certificateKey    . " $d/certificateKey" );
  EBox::Sudo::root("chown ebox.ebox $d/*");
}


sub restoreCertificates
{
  my ($self, $dir) = @_;

  my $d = "$dir/" . $self->name;
  if (not -d $d) {
    # XXX we don't abort to mantain compability with previous bakcup version
    EBox::error('No directory found with saved certificates for client ' .
		$self->name .
		'. Current certificates will be left untouched'

	       );
    next;
      
  }

  # before copyng and overwritting files, check if all needed files are valid
  # why? if there is a error is a little less probable we left a
  # unusable state
  my @files = ("$d/caCertificate", "$d/certificate", "$d/certificateKey" );
  EBox::OpenVPN::Client::ValidateCertificate::check(
						    "$d/caCertificate",
						    "$d/certificate",
						    "$d/certificateKey"
						   );

  # set the files from the backup in the client
  try {
    $self->setCertificateFiles(
				"$d/caCertificate",
				"$d/certificate",
				"$d/certificateKey"
			       );
  }
  otherwise {
      my $e = shift;
      EBox::error(
		  'Error restoring certifcates for client ' . $self->name .
		  '. Probably the certificates will be  inconsistents' 
		 );
      $e->throw();
    };

}


sub usesPort
{
  my ($self, $proto, $port, $iface) = @_;
  # openvpn client doesn't listen in any port
  return 0;
}


1;
