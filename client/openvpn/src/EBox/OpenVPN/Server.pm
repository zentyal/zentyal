package EBox::OpenVPN::Server;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkIP checkNetmask);
use EBox::NetWrappers;
use EBox::CA;
use EBox::FileSystem;
use Perl6::Junction qw(any);
use List::Util qw(first);
use EBox::Gettext;
use Params::Validate qw(validate_pos SCALAR);

use EBox::OpenVPN::Server::ClientBundleGenerator::Linux;
use EBox::OpenVPN::Server::ClientBundleGenerator::Windows;

sub new
{
    my ($class, $name, $openvpnModule) = @_;
   
    my $prefix= 'server';

    my $self = $class->SUPER::new($name, $prefix, $openvpnModule);
      bless $self, $class;

    return $self;
}


# Method: setProto
#
#   Set the protocol used by the server
#
#  Parametes:
#        $proto   - protocol. Must be 'tcp' or 'udp'

sub setProto
{
    my ($self, $proto) = @_;

    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "server's protocol", value => $proto, advice => __("The protocol only may be TCP or UDP.")  );
    }

    $self->_checkPortIsAvailable( $proto, $self->port(), $self->local);

    $self->setConfString('proto', $proto);
}

# Method: proto
#
#  Returns:
#    the protocol used by the server
#
sub proto
{
    my ($self) = @_;
    return $self->getConfString('proto');
}

# Method: setPort
#
#   Sets the port used by the server to receive connections. It must be a port
#    not used by another openvpn daemon
#
#  Parametes:
#        $port   - port number 
sub setPort
{
  my ($self, $port) = @_;

  checkPort($port, "server's port");
  if ( $port < 1024 ) {
      throw EBox::Exceptions::InvalidData(data => "server's port", value => $port, advice => __("The port must be a non-privileged port")  );
    }

  $self->_checkPortIsAvailable($self->proto(), $port, $self->local());

  $self->setConfInt('port', $port);
}



sub _checkPortIsAvailable
{
    my ($self, $proto, $port, $localIface) = @_;
    validate_pos(@_, 1, 1, 1, 1);

      # we must check we haven't already set the same port to avoid usesPort
      # false positive
    if ( ($port == $self->port()) and ($proto eq $self->proto)  ) {
      if (defined $localIface) {
	my $currentLocalIface = $self->local();
	if (not defined $currentLocalIface) {
	  return 1;
	}
	elsif ($currentLocalIface eq $localIface) {
	  return 1;
	}
      }
      else {
	return 1;	
      }
    }


    my $fw = EBox::Global->modInstance('firewall');
    my $availablePort =   $fw->availablePort($proto, $port, $localIface);
    if (not $availablePort) {
 	    throw EBox::Exceptions::External ( __x(
					      "The port {p}/{pro} is already in use",
						   p => $port,
						   pro => $proto,
						  )
					     );
	  }
}





# Method: port
#
#  Returns:
#   the port used by the server to receive conenctions. 
sub port
{
    my ($self) = @_;
    return $self->getConfInt('port');
}


# Method: setLocal
#
#  Sets the local network interface where the server will listen or
#   sets the server to listen in all interfaces
#
# Parameters: iface - the interface to listen on. An undef of false value
#   signals that we listen in all interfaces
sub setLocal
{
  my ($self, $iface) = @_;
  $iface or $iface = undef;

  $self->_checkPortIsAvailable($self->proto, $self->port, $iface);

  if (defined $iface) {
    $self->_checkLocal($iface);
    $self->setConfString('local', $iface);
  }
  else {
    $self->unsetConf('local');
  }
}

sub _checkLocal
{
  my ($self, $iface)  = @_;

  my $network = EBox::Global->modInstance('network');

  # XXX the ifaceMethod call is needed for #395
  if ((!$network->ifaceIsExternal($iface)) || ($network->ifaceMethod($iface) eq 'notset')) {
    if ($network->ifaceExists($iface)) {
      throw EBox::Exceptions::External(__x('OpenVPN can only listen on a external interface. The interface {iface} does not exist'), iface => $iface);
    } 
    else {
      throw EBox::Exceptions::External(__x('OpenVPN can only listen on a external interface. The interface {iface} is  internal'), iface => $iface);
    }
  }
}

# Method: local
#
#  Gets the local network interface where the server will listen 
#
#   Returns:
#      undef if the server listens in all interfaces or
#        the interface name where it listens
sub local
{
    my ($self) = @_;
    my $iface = $self->getConfString('local');

    # gconf does not store undef values, with a undef key it returns ''
    if (not $iface) {
      $iface = undef;
    }

    return $iface;
}


# Method: caCertificatePath
#
#   Returns:
#      the path to the CA's certificate
sub caCertificatePath
{
  my ($self) = @_;

  my $global = EBox::Global->instance();
  my $ca = $global->modInstance('ca');

  my $caCertificate = $ca->getCACertificateMetadata;
  defined $caCertificate or throw EBox::Exceptions::Internal('No CA certificate' );

  return $caCertificate->{path};
}


# Method: setCertificate
#
#  Sets the certificate used by the server to identify itself
#
#   parameters:
#      certificateCN - the common name of the certificate
sub setCertificate
{
  my ($self, $certificateCN) = @_;
  validate_pos(@_, 1, 1);

  $self->_checkCertificate($certificateCN);
  
  $self->setConfString('server_certificate', $certificateCN);
}

# Method: certificate
#
#  Gets the certificate used by the server to identify itself
#
#   returns:
#      the common name of the certificate
sub certificate
{
    my ($self) = @_;
    my $cn = $self->getConfString('server_certificate');
    return $cn;
}


sub _checkCertificate
{
  my ($self, $cn) = @_;

  my $ca = EBox::Global->modInstance('ca');
  my $cert_r = $ca->getCertificateMetadata(cn => $cn);

  if (not defined $cert_r) {
    throw EBox::Exceptions::External(__x('The certificate {cn} does not exist', cn => $cn));
  }
  elsif ($cert_r->{state} eq 'E') {
    throw EBox::Exceptions::External(__x('The certificate {cn} has expired', cn => $cn));
  }
  elsif ($cert_r->{state} eq 'R') {
    throw EBox::Exceptions::External(__x('The certificate {cn} has been revoked', cn => $cn));
  }

  return $cert_r;
}

# Method: certificatePath
#
# Returns:
#  the path to the certificate file
sub certificatePath
{
  my ($self) = @_;

  my $cn = $self->certificate();
  ($cn) or throw EBox::Exceptions::External(__x('The server {name} does not have certificate assigned', name => $self->name));

  my $certificate_r = $self->_checkCertificate($cn);
  return $certificate_r->{path};
}



# Method: key
#
# Returns:
#  the path to the private key for the server's certificate
sub key
{
    my ($self) = @_;

    my $certificateCN = $self->certificate();
    ($certificateCN) or throw EBox::Exceptions::External(__x('Cannot get key of server {name} because it does not have any certificate assigned', name => $self->name));

    $self->_checkCertificate($certificateCN);

    my $ca = EBox::Global->modInstance('ca');
    my $keys = $ca->getKeys($certificateCN);

    return $keys->{privateKey};
}

# Method: crlVerify
#
#   returns the value needed for the crlVerify openvpn's option
#
# Returns:
#  the path to the current certificates revoked list
sub crlVerify
{
  my ($self) = @_;

  my $ca = EBox::Global->modInstance('ca');
  return $ca->getCurrentCRL();
}

# Method: setSubnetAndMask
#
#   sets the subnet and the netmask of the VPN provided by the server
#
# Parameters:
#   net  - the network address
#   mask - the network netmask
sub setSubnetAndMask
{
  my ($self, $net, $mask) = @_;
  $self->_checkSubnetAndMask($net, $mask);

  checkIP($net, 'VPN subnet');
  checkNetmask($mask, "VPN network netmask");

  $self->setConfString('vpn_net', $net);
  $self->setConfString('vpn_netmask', $mask);
}

sub _checkSubnetAndMask
{
  my ($self, $net, $mask) = @_;

  # XXX ugly change it when we have #396
  checkIP($net, 'VPN subnet');
  checkNetmask($mask, "VPN network netmask");

  if (EBox::Validate::checkIPNetmask($net, $mask)) {
    throw EBox::Exceptions::External(__x('Network address {net} with netmask {mask} is not a valid network', net => $net, mask => $mask));
  }

}

sub setSubnet
{
  my ($self, $net) = @_;
  
  $self->_checkSubnetAndMask($net, $self->subnetNetmask);

  $self->setConfString('vpn_net', $net);
}

# Method: subnet
#
# Returns:
#  the address of the VPN provided by the server
sub subnet
{
    my ($self) = @_;
    my $net = $self->getConfString('vpn_net');
    return $net;
}


sub setSubnetNetmask
{
    my ($self, $netmask) = @_;

    $self->_checkSubnetAndMask($self->subnet(), $netmask);

    $self->setConfString('vpn_netmask', $netmask);
}

# Method: subnetNetmask
#
# Returns:
#  the netmask of the VPN provided by the server
sub subnetNetmask
{
    my ($self) = @_;
    my $netmask = $self->getConfString('vpn_netmask');
    return $netmask;
}

# Method: setClientToClientAllowed
# 
#  sets wether connection is alloweb bettween clients though the VPN or not
#
# Parameters:
#  clientToClientAllowed - true if it is allowed, false otherwise
sub setClientToClient
{
    my ($self, $clientToClientAllowed) = @_;
    $self->setConfBool('client_to_client', $clientToClientAllowed);
}

# Method: clientToClientAllowed
#
# Returns:
#  wether conenction is alloweb bettween clients though the VPN or not
sub clientToClient
{
    my ($self) = @_;
    return $self->getConfBool('client_to_client');
}


# Method: tlsRemote
#
# Returns:
#  value of the openvpn's tlsRemote option
sub tlsRemote
{
  my ($self) = @_;
  $self->getConfString('tls_remote');
}

# Method: tlsRemote
#
# Returns:
#  value of the openvpn's tlsRemote option
sub setTlsRemote
{
  my ($self, $clientCN) = @_;

  if (!$clientCN) {   # disabling access by cn
    $self->unsetConf('tls_remote');
    return;
  }

  $self->_checkCertificate($clientCN);
  $self->setConfString('tls_remote', $clientCN);
}


# Method: pullRoutes
#
# Returns:
#  wether the server may pull routes from client or not
sub pullRoutes
{
  my ($self) = @_;
  return $self->getConfBool('pull_routes');
}

# Method: setPullRoutes
#
#  sets wether the server may pull routes from client or not
sub setPullRoutes
{
  my ($self, $value) = @_;
  return $self->setConfBool('pull_routes', $value);
}

sub ripDaemon
{
  my ($self) = @_;
  
  $self->pullRoutes() or return undef;

  my $iface = $self->iface();
  return { iface => $iface };
}

sub confFileTemplate
{
  my ($self) = @_;
  return "openvpn/openvpn.conf.mas";
}

sub confFileParams
{
  my ($self) = @_;
  my @templateParams;

  push @templateParams, (dev => $self->iface());

  my @paramsNeeded = qw(name subnet subnetNetmask  port caCertificatePath certificatePath key crlVerify clientToClient user group proto dh tlsRemote);
  foreach  my $param (@paramsNeeded) {
    my $accessor_r = $self->can($param);
    defined $accessor_r or die "Cannot found accesor for param $param";
    my $value = $accessor_r->($self);
    defined $value or next;
    push @templateParams, ($param => $value);
  }

  

  # local parameter needs special mapping from iface -> ip
  push @templateParams, $self->_confFileLocalParam();

  my @advertisedNets =  $self->advertisedNets();
  push @templateParams, ( advertisedNets => \@advertisedNets);

  return \@templateParams;
}

# Method: localAddress
#
# Returns:
#  the ip address where the server will listen or undef if it
# listens in all network interfaces
sub localAddress
{
  my ($self) = @_;

 my $localAddress;
  my $localIface = $self->local();
  if ($localIface) {
    # translate local iface to a local ip 
    my $network = EBox::Global->modInstance('network');
    my $ifaceAddresses_r = $network->ifaceAddresses($localIface);
    my @addresses = @{ $ifaceAddresses_r };
    if (@addresses == 0) {
      throw EBox::Exceptions::External(__x('No IP address found for interface {iface}', iface => $localIface));
    }

    my $selectedAddress =  shift @addresses; # XXX may be we have to look up a better address resolution method
    $localAddress = $selectedAddress->{address};
  }
  else {
    $localAddress = undef;
  }
}


sub _confFileLocalParam
{
  my ($self) = @_;

  my $localParamValue = $self->localAddress();
  return (local => $localParamValue);
}

sub setService # (active)
{
  my ($self, $active) = @_;
  ($active and $self->service)   and return;
  (!$active and !$self->service) and return;


  if ($active) {  
    # servers with certificate trouble must not be activated
    my $certificate = $self->certificate();
    $self->_checkCertificate($certificate);

    # servers  with iface trouble shuld not activated
    my $local = $self->local();
    if ($local) {
      $self->_checkLocal($local)
    }
    else {
      # we need at least one interface
      my $network = EBox::Global->modInstance('network');
      my @ifaces = @{ $network->ExternalIfaces };
      # XXX it should care of internal ifaces only until we close #391
      push @ifaces, @{ $network->InternalIfaces };
      if (@ifaces == 0) {
	throw EBox::Exceptions::External(__x('OpenVPN server {name} cannot be activated because there is not any network interface available', name => $self->name));
      }
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

# Method: advertisedNets
#
#  gets the nets wich will be advertised to client as reacheable thought the server
#
# Returns:
#  a list of references to a lists containing the net addres and netmask pair
sub advertisedNets
{
  my ($self) = @_;

  my @net =  @{ $self->allConfEntriesBase('advertised_nets') };
  @net = map {
    my $net = $_;
    my $netmask = $self->getConfString("advertised_nets/$net");
    [$net, $netmask]
  } @net;
    
  return @net;
}

# Method: setAdvertisedNets
#
#  sets the server's advertised nets
#
# Parameters:
#    advertisedNets_r - the list of advertised net. Each net is a list
#  reference to a net address and netmask pair
sub setAdvertisedNets
{
  my ($self, $advertisedNets_r)  =  @_;
  
  foreach my $net_r (@{ $advertisedNets_r }) {
    my ($address, $netmask)= @{ $net_r };

    $self->_checkAdvertisedNet($address, $netmask);

    $self->setConfString("advertised_nets/$address", $netmask);
  }

}

# Method: addAdvertisedNet
#
#  add a net to the advertised nets list
#
# Parameters:
#  net     - network address
#  netmask - network's netmask
sub addAdvertisedNet
{
  my ($self, $net, $netmask) = @_;

  $self->_checkAdvertisedNet($net, $netmask);

  $self->setConfString("advertised_nets/$net", $netmask);

}


sub _checkAdvertisedNet
{
  my ($self, $net, $netmask) = @_;

  checkIP($net, __('network address'));
  checkNetmask($netmask, __('network mask'));

  if ($self->getConfString("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Network {net} is already advertised in this server", net => $net));
  }
}



# Method: removeAdvertisedNet
#
#  remove a net from  the advertised nets list
#
# Parameters:
#  net     - network address
#  netmask - network's netmask
sub removeAdvertisedNet
{
  my ($self, $net) = @_;

  EBox::Validate::checkIP($net,  __('network address'));

  if (!$self->getConfString("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Network {net} is not advertised in this server", net => $net));
  }

  $self->unsetConf("advertised_nets/$net");

}


# Method: setInternal
#
#
# This method is overriden here beacuse servers cannot be internal; 
#  so trying to set them as internals we raise error
#
# Parameters:
#    internal - bool. 
sub setInternal
{
  my ($self, $internal) = @_;

  if ($internal) {
    throw EBox::Exceptions::External(
                      __('OpenVPN servers cannot be used for internal services')
				    );
  }

  $self->SUPER::setInternal($internal);
}



# Method: init
#
#  initialisation method
#
# Parameters:
#
#  *(Named parameters)*   
#
#  service        - wether the server is active or not *(default: disabled)*
#  subnet         - address of VPN net
#  subnetNetmask  - netmask of VPN net
#  port           - server's port
#  proto          - server's proto
#  certificate    - CN of server's certificate
#  local          - local interface to listen on *(optional)*
#  advertisedNets - advertised nets 
#  tlsRemote      - tls remote option
#  pullRoutes     - wether pull routes from clientes or not
sub init
{
    my ($self, %params) = @_;

    (exists $params{subnet}) or throw EBox::Exceptions::External __("The server requires a network address for the VPN");
    (exists $params{subnetNetmask}) or throw EBox::Exceptions::External __("The server requires a netmask for its VPN network");
    (exists $params{port} ) or throw EBox::Exceptions::External __("The server requires a port number");
    (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the server");
    (exists $params{certificate}) or throw EBox::Exceptions::External __("A  server certificate must be specified");

    $self->setSubnetAndMask($params{subnet}, $params{subnetNetmask});

    $self->setProto($params{proto});
    $self->setPort($params{port});
    $self->setCertificate($params{certificate});    

    my @noFundamentalAttrs = qw(local clientToClient advertisedNets tlsRemote pullRoutes internal); 
    push @noFundamentalAttrs, 'service'; # service must be always the last attr so if there is a error before the server is not activated

    foreach my $attr (@noFundamentalAttrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
}



sub clientBundle
{
  my ($self, $os, $clientCertificate, $addresses) = @_;

  if ( !($os eq any('linux', 'windows')) ) {
    throw EBox::Exceptions::External('Unsupported operative system: {os}', os => $os);
  }

  my $class = 'EBox::OpenVPN::Server::ClientBundleGenerator::' . ucfirst $os;

  return $class->clientBundle($self, $clientCertificate, $addresses);
}





sub certificateRevoked # (commonName, isCACert)
{
  my ($self, $commonName, $isCACert) = @_;

  return 1 if $isCACert;
  return ($commonName eq $self->certificate()) ;
}



sub certificateExpired
{
  my ($self, $commonName, $isCACert) = @_;

  if ($isCACert or  ($commonName eq $self->certificate())) {
    EBox::info('OpenVPN server ' . $self->name . ' is now inactive because of certificate expiration issues');
    $self->_invalidateCertificate();
  } 
}

sub freeCertificate
{
  my ($self, $commonName) = @_;

  if ($commonName eq $self->certificate()) {
    EBox::info('OpenVPN server ' . $self->name . ' is now inactive because server certificate expired or was revoked');
    $self->_invalidateCertificate();
  } 
}

sub _invalidateCertificate
{
  my ($self) = @_;
  $self->unsetConf('server_certificate');
  $self->setService(0);
}


sub usesPort
{
  my ($self, $proto, $port, $iface) = @_;


  my $ownProto = $self->proto;
  defined $ownProto or 
    return undef; # uninitialized server
  if ($proto ne $ownProto) {
    return undef;
  }


  my $ownPort = $self->port;
  defined $ownPort or 
    return undef; #uninitialized server
  if ($port ne $ownPort) {
    return undef;
  }


  my $ownIface = $self->local;
  if ((defined $iface) and (defined $ownIface)) {
    if ($iface ne $ownIface) {
      return undef;
    }
  }

  return 1;
}


sub ifaceMethodChanged
{
  my ($self, $iface, $oldmethod, $newmethod) = @_;

  if ($self->_onlyListenOnIface($iface)) {
    return 1 if $newmethod eq 'notset';
  }

  return undef;
}


sub vifaceDelete
{
  my ($self, $iface, $viface) = @_;
  return $self->_onlyListenOnIface($viface);
}


sub freeIface
{
  my ($self, $iface) = @_;

  if ($self->_onlyListenOnIface($iface)) {
    $self->setService(0);
    EBox::warn('OpenVPN server ' . $self->name . " was deactivated because it was dependent on the interface $iface");
  }
}

sub freeViface
{
  my ($self, $iface, $viface) = @_;
  $self->freeIface($viface);
}

sub _onlyListenOnIface
{
  my ($self, $iface) = @_;

  if ($iface eq $self->local()) {
    return 1;
  }
  else { 
    # the server listens in all ifaces...
    my $network = EBox::Global->modInstance('network');
    my @ifaces = @{ $network->ExternalIfaces };
    # XXX it should care of internal ifaces only until we close #391
    push @ifaces, @{ $network->InternalIfaces };

    if (@ifaces == 1) {
      return 1;
    }
  }

  return undef;
}

# Method: summary
#
#  returns the contents which will be used to create a summary section
#
sub summary
{
  my ($self) = @_;

  my @summary;
  push @summary, __x('Server {name}', name => $self->name);

  my $service = $self->service ? __('Enabled') : __('Disabled');
  push @summary, (__('Service'), $service);

  my $running = $self->running ? __('Running') : __('Stopped');
  push @summary,(__('Daemon status'), $running);


  my $localAddress = $self->localAddress();
  defined $localAddress or $localAddress = __('All external interfaces');
  push @summary, (__('Local address'), $localAddress);
  

  my $proto   = $self->proto();
  my $port    = $self->port();
  my $portAndProtocol = "$port/\U$proto";
  push @summary,(__('Port'), $portAndProtocol);

  my $subnet  = $self->subnet . '/' . $self->subnetNetmask;
  push @summary,(__('VPN subnet'), $subnet);

  return @summary;
}



1;
