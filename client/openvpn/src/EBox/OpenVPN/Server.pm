package EBox::OpenVPN::Server;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkIP checkNetmask);
use EBox::NetWrappers;
use EBox::CA;
use Perl6::Junction qw(all);
use List::Util qw(first);
use EBox::Gettext;
use Params::Validate qw(validate_pos SCALAR);

sub new
{
    my ($class, $name, $openvpnModule) = @_;
   
    my $prefix= 'server';

    my $self = $class->SUPER::new($name, $prefix, $openvpnModule);
      bless $self, $class;

    return $self;
}




sub setProto
{
    my ($self, $proto) = @_;

    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "server's protocol", value => $proto, advice => __("The protocol only may be tcp or udp.")  );
    }

    $self->_checkPortIsNotDuplicate($self->port(), $proto);

    $self->setConfString('proto', $proto);
}

sub proto
{
    my ($self) = @_;
    return $self->getConfString('proto');
}


sub setPort
{
  my ($self, $port) = @_;

  checkPort($port, "server's port");
  if ( $port < 1024 ) {
      throw EBox::Exceptions::InvalidData(data => "server's port", value => $port, advice => __("The port must be a non-privileged port")  );
    }

  $self->_checkPortIsNotDuplicate($port, $self->proto());

  $self->setConfInt('port', $port);
}


sub _checkPortIsNotDuplicate
{
    my ($self, $port, $proto) = @_;

    my $ownName = $self->name();
    defined $proto or throw EBox::Exceptions::Internal 'Protocol must be set before port';
    my @serversNames = grep { $_ ne $ownName } $self->_openvpnModule->serversNames();


    foreach my $serverName (@serversNames) {
	my $server =  $self->_openvpnModule->server($serverName); 
	next if ($proto ne $server->proto);
	if ($port eq $server->port() ) {
	    throw EBox::Exceptions::External ("There are already a OpenVPN server that uses port $port");
	}
    }
}


sub port
{
    my ($self) = @_;
    return $self->getConfInt('port');
}

sub setLocal
{
  my ($self, $localIP) = @_;

  checkIP($localIP, "Local IP address that will be listenned by server");

  my @localAddresses = EBox::NetWrappers::list_local_addresses();
  if ($localIP ne all(@localAddresses)) {
 throw EBox::Exceptions::InvalidData(data => "Local IP address that will be listenned by server", value => $localIP, advice => __("This address does not correspond to any local address")  );
  }

  $self->setConfString('local', $localIP);
}

sub local
{
    my ($self) = @_;
    return $self->getConfString('local');
}



sub caCertificatePath
{
  my ($self) = @_;

  my $global = EBox::Global->instance();
  my $ca = $global->modInstance('ca');

  my $caCertificate = $ca->getCACertificateMetadata;
  defined $caCertificate or throw EBox::Exceptions::Internal('No CA certificate' );

  return $caCertificate->{path};
}



sub setCertificate
{
  my ($self, $certificateCN) = @_;
  validate_pos(@_, 1, 1);

  $self->_checkCertificate($certificateCN);
  
  $self->setConfString('server_certificate', $certificateCN);
}

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

sub certificatePath
{
  my ($self) = @_;

  my $cn = $self->certificate();
  ($cn) or throw EBox::Exceptions::External(__x('The server {name} has not certificate assigned', name => $self->name));

  my $certificate_r = $self->_checkCertificate($cn);
  return $certificate_r->{path};
}




sub key
{
    my ($self) = @_;

    my $certificateCN = $self->certificate();
    ($certificateCN) or throw EBox::Exceptions::External(__x('Can not get key of server {name} because it has not any certificate assigned', name => $self->name));

    $self->_checkCertificate($certificateCN);

    my $ca = EBox::Global->modInstance('ca');
    my $keys = $ca->getKeys($certificateCN);

    return $keys->{privateKey};
}


sub setSubnet
{
    my ($self, $net) = @_;

    checkIP($net, 'VPN subnet');
    $self->setConfString('vpn_net', $net);
}

sub subnet
{
    my ($self) = @_;
    my $net = $self->getConfString('vpn_net');
    return $net;
}


sub setSubnetNetmask
{
    my ($self, $netmask) = @_;
    checkNetmask($netmask, "VPN net\'s netmask");
    $self->setConfString('vpn_netmask', $netmask);
}


sub subnetNetmask
{
    my ($self) = @_;
    my $netmask = $self->getConfString('vpn_netmask');
    return $netmask;
}


sub setClientToClient
{
    my ($self, $clientToClientAllowed) = @_;
    $self->setConfBool('client_to_client', $clientToClientAllowed);
}

sub clientToClient
{
    my ($self) = @_;
    return $self->getConfBool('client_to_client');
}



sub tlsRemote
{
  my ($self) = @_;
  $self->getConfString('tlsRemote');
}


sub setTlsRemote
{
  my ($self, $clientCN) = @_;

  if (!$clientCN) {   # disabling access by cn
    $self->unsetConf('tlsRemote');
    return;
  }

  $self->_checkCertificate($clientCN);
  $self->setConfString('tlsRemote', $clientCN);
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

  my @paramsNeeded = qw(subnet subnetNetmask local port caCertificatePath certificatePath key clientToClient user group proto dh tlsRemote);
  foreach  my $param (@paramsNeeded) {
    my $accessor_r = $self->can($param);
    defined $accessor_r or die "Can not found accesoor for param $param";
    my $value = $accessor_r->($self);
    defined $value or next;
    push @templateParams, ($param => $value);
  }

  my @advertisedNets =  $self->advertisedNets();
  push @templateParams, ( advertisedNets => \@advertisedNets);

  return \@templateParams;
}


sub setService # (active)
{
  my ($self, $active) = @_;
  ($active and $self->service)   and return;
  (!$active and !$self->service) and return;

  # servers with certificate trouble must not be activated
  if ($active) {  
    my $certificate = $self->certificate();
    $self->_checkCertificate($certificate);
  }

  $self->setConfBool('active', $active);
}


sub service
{
   my ($self) = @_;
   return $self->getConfBool('active');
}


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


sub setAdvertisedNets
{
  my ($self, $advertisedNets_r)  =  @_;
  
  foreach my $net_r (@{ $advertisedNets_r }) {
    my ($address, $netmask)= @{ $net_r };

    $self->_checkAdvertisedNet($address, $netmask);

    $self->setConfString("advertised_nets/$address", $netmask);
  }

  $self->_notifyStaticRoutesChange();
}

sub addAdvertisedNet
{
  my ($self, $net, $netmask) = @_;

  $self->_checkAdvertisedNet($net, $netmask);

  $self->setConfString("advertised_nets/$net", $netmask);

  $self->_notifyStaticRoutesChange();
}


sub _checkAdvertisedNet
{
  my ($self, $net, $netmask) = @_;

  checkIP($net, __('network address'));
  checkNetmask($netmask, __('network mask'));

  if ($self->getConfString("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Net {net} is already advertised in this server", net => $net));
  }


 if (! _EBoxIsGateway()) {
    throw EBox::Exceptions::External(__('EBox must be configured as gateway to be able to give client access to networks via OpenVPN'));
  }


  my $CIDRNet = EBox::NetWrappers::to_network_with_mask($net, $netmask);
  if (! defined EBox::NetWrappers::route_to_reach_network($CIDRNet)) {
    throw EBox::Exceptions::External(__('The OpenVPN server can not grant access to a network which can not be reached by eBox'))
  }

  
}


sub _EBoxIsGateway
{
  return 1;
}
 









sub removeAdvertisedNet
{
  my ($self, $net) = @_;

  EBox::Validate::checkIP($net,  __('network address'));

  if (!$self->getConfString("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Net {net} is not advertised in this server", net => $net));
  }

  $self->unsetConf("advertised_nets/$net");

  $self->_notifyStaticRoutesChange();
}


sub _notifyStaticRoutesChange
{
  my ($self) = @_;

  $self->_openvpnModule()->notifyStaticRoutesChange();
}

sub staticRoutes
{
  my ($self) = @_;

  my @advertisedRoutes  = $self->advertisedNets();
  my @staticRoutes = map {
    my ($net, $netmask) = @{$_};
    my $netWithMask = EBox::NetWrappers::to_network_with_mask($net, $netmask);
    my $gateway = EBox::NetWrappers::local_ip_to_reach_network($netWithMask) ;

    my $destination = $self->subnet();
    my $destinationNetmask = $self->subnetNetmask();
    ($netWithMask => {network => $destination, netmask => $destinationNetmask, gateway => $gateway });
  } @advertisedRoutes;

  return @staticRoutes;
}

sub setFundamentalAttributes
{
    my ($self, %params) = @_;

    (exists $params{subnet}) or throw EBox::Exceptions::External __("The server needs a subnet address for the VPN");
    (exists $params{subnetNetmask}) or throw EBox::Exceptions::External __("The server needs a submask for his VPN net");
    (exists $params{port} ) or throw EBox::Exceptions::External __("The server needs a port number");
    (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the server");
    (exists $params{certificate}) or throw EBox::Exceptions::External __("A  server certificate must be specified");


    $self->setSubnet($params{subnet});
    $self->setSubnetNetmask( $params{subnetNetmask} );
    $self->setProto($params{proto});
    $self->setPort($params{port});
    $self->setCertificate($params{certificate});    

    my @noFundamentalAttrs = qw(local clientToClient advertisedNets tlsRemote); 
    push @noFundamentalAttrs, 'service'; # service must be always the last attr so if there is a error before the server is not activated

    foreach my $attr (@noFundamentalAttrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
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
    EBox::info('Server ' . $self->name . ' is now inactive becasuse of certificate expiration issues');
    $self->_invalidateCertificate();
  } 
}

sub freeCertificate
{
  my ($self, $commonName) = @_;

  if ($commonName eq $self->certificate()) {
    EBox::info('Server ' . $self->name . ' is now inactive because server certificate expired or was revoked');
    $self->_invalidateCertificate();
  } 
}

sub _invalidateCertificate
{
  my ($self) = @_;
  $self->unsetConf('server_certificate');
  $self->setService(0);
}


1;
