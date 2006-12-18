package EBox::OpenVPN::Server;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

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
    
    my $confKeysBase = "server/$name";
    if (!$openvpnModule->dir_exists($confKeysBase) ) {
	throw EBox::Exceptions::Internal("Tried to instantiate a server with a name not found in module configuration: $name");
    }

    my $self = { name => $name,  openvpnModule => $openvpnModule, confKeysBase => $confKeysBase   };
    bless $self, $class;

    return $self;
}

sub _confKey
{
    my ($self, $key) = @_;
    return $self->{confKeysBase} . "/$key";
}

sub _openvpnModule
{
    my ($self) = @_;
    return $self->{openvpnModule};
}

sub _getConfString
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->get_string($key);
}

sub _setConfString
{
    my ($self, $key, $value) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->set_string($key, $value);
}


sub _getConfInt
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->get_int($key);
}

sub _setConfInt
{
    my ($self, $key, $value) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->set_int($key, $value);
}


sub _confDirExists
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    return $self->_openvpnModule->dir_exists($key);
}

sub _allConfEntriesBase
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    return $self->_openvpnModule->all_entries_base($key);
}


sub _unsetConf
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    return $self->_openvpnModule->unset($key);
}


sub _getConfBool
{
    my ($self, $key) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->get_bool($key);
}

sub _setConfBool
{
    my ($self, $key, $value) = @_;
    $key = $self->_confKey($key);
    $self->_openvpnModule->set_bool($key, $value);
}


sub name
{
    my ($self) = @_;
    return $self->{name};
}

sub setProto
{
    my ($self, $proto) = @_;

    if ($proto ne 'tcp'  and ($proto ne 'udp') ) {
	throw EBox::Exceptions::InvalidData(data => "server's protocol", value => $proto, advice => __("The protocol only may be tcp or udp.")  );
    }

    $self->_checkPortIsNotDuplicate($self->port(), $proto);

    $self->_setConfString('proto', $proto);
}

sub proto
{
    my ($self) = @_;
    return $self->_getConfString('proto');
}


sub setPort
{
  my ($self, $port) = @_;

  checkPort($port, "server's port");
  if ( $port < 1024 ) {
      throw EBox::Exceptions::InvalidData(data => "server's port", value => $port, advice => __("The port must be a non-privileged port")  );
    }

  $self->_checkPortIsNotDuplicate($port, $self->proto());

  $self->_setConfInt('port', $port);
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
    return $self->_getConfInt('port');
}

sub setLocal
{
  my ($self, $localIP) = @_;

  checkIP($localIP, "Local IP address that will be listenned by server");

  my @localAddresses = EBox::NetWrappers::list_local_addresses();
  if ($localIP ne all(@localAddresses)) {
 throw EBox::Exceptions::InvalidData(data => "Local IP address that will be listenned by server", value => $localIP, advice => __("This address does not correspond to any local address")  );
  }

  $self->_setConfString('local', $localIP);
}

sub local
{
    my ($self) = @_;
    return $self->_getConfString('local');
}


# XXX certificates: 
# - existence control
# - file permision control (specially server key)




sub caCertificatePath
{
  my ($self) = @_;

  my $global = EBox::Global->instance();
  my $ca = $global->modInstance('ca');

  my $caCertificate = $ca->getCACertificate;
  defined $caCertificate or throw EBox::Exceptions::Internal('No CA certificate' );

  return $caCertificate->{path};
}



sub setCertificate
{
  my ($self, $certificateCN) = @_;
  validate_pos(@_, 1, 1);

  $self->_checkCertificate($certificateCN);
  
  $self->_setConfString('server_certificate', $certificateCN, 'Server certificate');
}

sub certificate
{
    my ($self) = @_;
    my $cn = $self->_getConfString('server_certificate');
    return $cn;
}


sub _checkCertificate
{
  my ($self, $cn) = @_;

  my $ca = EBox::Global->modInstance('ca');
  my $cert_r = $ca->getCertificate(cn => $cn);

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
    $self->_setConfString('vpn_net', $net);
}

sub subnet
{
    my ($self) = @_;
    my $net = $self->_getConfString('vpn_net');
    return $net;
}


sub setSubnetNetmask
{
    my ($self, $netmask) = @_;
    checkNetmask($netmask, "VPN net\'s netmask");
    $self->_setConfString('vpn_netmask', $netmask);
}


sub subnetNetmask
{
    my ($self) = @_;
    my $netmask = $self->_getConfString('vpn_netmask');
    return $netmask;
}


sub setClientToClient
{
    my ($self, $clientToClientAllowed) = @_;
    $self->_setConfBool('client_to_client', $clientToClientAllowed);
}

sub clientToClient
{
    my ($self) = @_;
    return $self->_getConfBool('client_to_client');
}


sub user
{
    my ($self) = @_;
    return $self->_openvpnModule->user();
}


sub group
{
    my ($self) = @_;
    return $self->_openvpnModule->group();
}

sub dh
{
    my ($self) = @_;
    return $self->_openvpnModule->dh();
}

sub confFile
{
    my ($self, $confDir) = @_;
    my $confFile = $self->name() . '.conf';
    my $confFilePath = defined $confDir ? "$confDir/$confFile" : $confFile;

    return $confFilePath;
}

sub writeConfFile
{
    my ($self, $confDir) = @_;

    my $confFilePath = $self->confFile($confDir);
    my $templatePath = "openvpn/openvpn.conf.mas";
    my @templateParams;
    my $defaults     = {
	uid  => $self->user,
	gid  => $self->group,
	mode => '0400',
    };

    my @paramsNeeded = qw(subnet subnetNetmask local port caCertificatePath certificatePath key clientToClient user group proto dh);
    foreach  my $param (@paramsNeeded) {
	my $accessor_r = $self->can($param);
	defined $accessor_r or die "Can not found accesoor for param $param";
	my $value = $accessor_r->($self);
	defined $value or next;
	push @templateParams, ($param => $value);
    }

    my @advertisedNets =  $self->advertisedNets();
    push @templateParams, ( advertisedNets => \@advertisedNets);

    EBox::GConfModule->writeConfFile($confFilePath, $templatePath, \@templateParams, $defaults);
}


sub setService # (active)
{
    my ($self, $active) = @_;
    ($active and $self->service)   and return;
    (!$active and !$self->service) and return;

    $self->_setConfBool('active', $active);
}


sub service
{
   my ($self) = @_;
   return $self->_getConfBool('active');
}


sub advertisedNets
{
  my ($self) = @_;

  my @net =  @{ $self->_allConfEntriesBase('advertised_nets') };
  @net = map {
    my $net = $_;
    my $netmask = $self->_getConfString("advertised_nets/$net");
    [$net, $netmask]
  } @net;
    
  return @net;
}


sub addAdvertisedNet
{
  my ($self, $net, $netmask) = @_;

  if ($self->_confDirExists("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Net {net} is already advertised in this server", net => $net));
  }

  $self->_setConfString("advertised_nets/$net", $netmask);

  $self->_notifyStaticRoutesChange();
}

sub removeAdvertisedNet
{
  my ($self, $net) = @_;

  if (!$self->_confDirExists("advertised_nets/$net")) {
    throw EBox::Exceptions::External(__x("Net {net} is not advertised in this server", net => $net));
  }

  $self->_unsetConf("advertised_nets/$net");

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
    (exists $params{certificate}) or throw EBox::Exceptions::External __("A path to the server certificate must be specified");


    $self->setSubnet($params{subnet});
    $self->setSubnetNetmask( $params{subnetNetmask} );
    $self->setProto($params{proto});
    $self->setPort($params{port});
    $self->setCertificate($params{certificate});    

    my @noFundamentalAttrs = qw(local clientToClient service);
    foreach my $attr (@noFundamentalAttrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
}

sub running
{
    my ($self) = @_;
    my $bin = $self->_openvpnModule->openvpnBin;
    my $name = $self->name;

    system "/usr/bin/pgrep -f $bin.*$name";

    return ($? == 0) ? 1 : 0;
}


1;
