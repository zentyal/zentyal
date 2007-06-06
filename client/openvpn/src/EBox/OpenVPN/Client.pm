package EBox::OpenVPN::Client;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkHost);
use EBox::NetWrappers;
use EBox::Sudo;
use EBox::Gettext;
use Params::Validate qw(validate_pos SCALAR);
use File::Basename;
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

# Method: caCertificatePath
#
# Returns:
#  returns the path to the CA certificate
sub caCertificatePath
{
  my ($self) = @_;
  return $self->getConfString('caCertificatePath');
}

# Method: setCaCertificatePath
#
#  sets a new CA certificate for the client.
#    the old one, if exists, will be deleted
#
# Parameters:
#  path - path to the new CA certificate
sub setCaCertificatePath
{
  my ($self, $path) = @_;
  my $prettyName = q{Certification Authority's certificate};
  $self->_setPrivateFile('caCertificatePath', $path, $prettyName);
}

# Method: certificatePath
#
# Returns:
#  returns the path to the certificate
sub certificatePath
{
  my ($self) = @_;
  return $self->getConfString('certificatePath');
}

# Method: setCertificatePath
#
#  sets a new  certificate for the client.
#    the old one, if exists, will be deleted
#
# Parameters:
#  path - path to the new client's certificate
sub setCertificatePath
{
  my ($self, $path) = @_;
  my $prettyName = q{client's certificate};
 $self->_setPrivateFile('certificatePath', $path, $prettyName);
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

# Method: setCertificateKey
#
#  sets a new  private key for the client.
#    the old one, if exists, will be deleted
#
# Parameters:
#  path - path to the new client's private key
sub setCertificateKey
{
  my ($self, $path) = @_;
  my $prettyName = q{certificate's key};
  $self->_setPrivateFile('certificateKey', $path, $prettyName);
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
    # create dir if it does not exist
    EBox::Sudo::root("mkdir --mode 0500  $dir");
  } 

  return $dir;
}

sub _setPrivateFile
{
  my ($self, $type, $path, $prettyName) = @_;

  # basic file check
  checkAbsoluteFilePath($path, __($prettyName));
  if (!EBox::Sudo::fileTest('-f', $path)) {
    throw EBox::Exceptions::External(__x('Inexistent file {path}', path => $path));
  }

  my $privateDir = $self->privateDir();
  
  my $newPath = "$privateDir/$type"; 

  try {
    EBox::Sudo::root("chmod 0400 $path");
    EBox::Sudo::root("chown 0.0 $path");
    EBox::Sudo::root("mv $path $newPath");
  }
  otherwise {
    EBox::Sudo::root("rm -f $newPath");
    EBox::Sudo::root("rm -f $path");
  };

  $self->setConfString($type, $newPath);


}


# Method: setHidden
#
#  sets the client's hidden state
#
# Parameters:
#    hidden - hiddencol. Must be 'tcp' or 'udp'
sub setHidden
{
    my ($self, $hidden) = @_;

   $self->setConfBool('hidden', $hidden);
}

# Method: hidden
#
#   tells wether the client must  been hidden  for users in the UI or not
#
# Returns:
#  returns the client's hidden state
sub hidden
{
    my ($self) = @_;
    return $self->getConfBool('hidden');
}



sub daemonFiles
{
  my ($self) = @_;

  my @files = $self->SUPER::daemonFiles();
  push @files, basename $self->privateDir();

  return @files;
}


sub setService # (active)
{
  my ($self, $active) = @_;
  ($active and $self->service)   and return;
  (!$active and !$self->service) and return;

  if ($active) {
    if ($self->_availableIfaces() == 0) {
      throw EBox::Exceptions::External('Can not activate OpenVPN clients because there is not any netowrk interface available');
    }
  }

  $self->setConfBool('active', $active);
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

  my @paramsNeeded = qw(caCertificatePath certificatePath certificateKey  user group proto );
  foreach my $param (@paramsNeeded) {
    my $accessor_r = $self->can($param);
    defined $accessor_r or die "Can not found accesoor for param $param";
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
#  hidden  - wethet the client is hidden from the web GUI *(default: false)*
sub init
{
    my ($self, %params) = @_;

    (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the server");
    (exists $params{caCertificatePath}) or throw EBox::Exceptions::External __("The CA certificate is needed");
    (exists $params{certificatePath}) or throw EBox::Exceptions::External __("The client certificate must be specified");
    (exists $params{certificateKey}) or throw EBox::Exceptions::External __("The client private key must be specified");
    (exists $params{servers}) or throw EBox::Exceptions::External __("Servers must be supplied to the client");
    

    exists $params{service} or $params{service} = 0;
    exists $params{hidden}  or $params{hidden}  = 0;


    my @attrs = qw(proto caCertificatePath certificatePath certificateKey servers service hidden);
    foreach my $attr (@attrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
}


sub ripDaemon
{
  my ($self) = @_;
  
  my $iface = $self->iface();
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

  return @summary;
}


1;
