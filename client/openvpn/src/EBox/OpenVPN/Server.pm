package EBox::OpenVPN::Server;
# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkIP checkNetmask);
use EBox::NetWrappers;
use Perl6::Junction qw(all);
use EBox::Gettext;


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

sub _setConfPath
{
    my ($self, $key, $value, $name) = @_;
    checkAbsoluteFilePath($value, $name);
    $self->_setConfString($key, $value);
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

  $self->_checkPortIsNotDuplicate($port);

  $self->_setConfInt('port', $port);
}


sub _checkPortIsNotDuplicate
{
    my ($self, $port) = @_;

    my $ownName = $self->name();
    my @serversNames = grep { $_ ne $ownName } $self->_openvpnModule->serversNames();

    foreach my $serverName (@serversNames) {
	my $server =  $self->_openvpnModule->server($serverName); 
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
    return $self->_getConfInt('local');
}


# XXX certificates: 
# - existence control
# - file permision c9ntrol (specially server key)

sub setCaCertificate
{
    my ($self, $caCertificate) = @_;
    $self->_setConfPath('ca_certificate', $caCertificate, 'CA Certificate');
}

sub caCertificate
{
    my ($self) = @_;
    return $self->_getConfString('ca_certificate');
}

sub setServerCertificate
{
    my ($self, $serverCertificate) = @_;
    $self->_setConfPath('server_certificate', $serverCertificate, 'Server certificate');
}

sub serverCertificate
{
    my ($self) = @_;
    return $self->_getConfString('server_certificate');
}


sub setServerKey
{
    my ($self, $serverKey) = @_;
    $self->_setConfPath('server_key', $serverKey, 'Server key');
}

sub serverKey
{
    my ($self) = @_;
    return $self->_getConfString('server_key');
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


sub confFile
{
    my ($self, $confDir) = @_;
    my $confFile = $self->name() . '.conf';
    my $confFilePath = "$confDir/$confFile";

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

    my @paramsNeeded = qw(subnet subnetNetmask local port caCertificate serverCertificate serverKey clientToClient user group proto);
    foreach  my $param (@paramsNeeded) {
	my $accessor_r = $self->can($param);
	defined $accessor_r or die "Can not found accesoor for param $param";
	my $value = $accessor_r->($self);
	defined $value or next;
	push @templateParams, ($param => $value);
    }


    EBox::GConfModule->writeConfFile($confFilePath, $templatePath, \@templateParams, $defaults);
}


sub setFundamentalAttributes
{
    my ($self, %params) = @_;

    (exists $params{subnet}) or throw EBox::Exceptions::External __("The server needs a subnet address for the VPN");
    (exists $params{subnetNetmask}) or throw EBox::Exceptions::External __("The server needs a submask for his VPN net");
    (exists $params{port} ) or throw EBox::Exceptions::External __("The server needs a port number");
    (exists $params{proto}) or throw EBox::Exceptions::External __("A IP protocol must be specified for the server");
    (exists $params{caCertificate}) or throw EBox::Exceptions::External __("A path to a CA certificate must be specified");
    (exists $params{serverCertificate}) or throw EBox::Exceptions::External __("A path to the server certificate must be specified");
    (exists $params{serverKey}) or throw EBox::Exceptions::External __("A path to the server key must be specified");

    $self->setSubnet($params{subnet});
    $self->setSubnetNetmask( $params{subnetNetmask} );
    $self->setPort($params{port});
    $self->setProto($params{proto});
    $self->setCaCertificate($params{caCertificate});
    $self->setServerCertificate($params{serverCertificate});    
    $self->setServerKey($params{serverKey});

    my @noFundamentalAttrs = qw(local clientToClient);
    foreach my $attr (@noFundamentalAttrs)  {
	if (exists $params{$attr} ) {
	    my $mutator_r = $self->can("set\u$attr");
	    defined $mutator_r or die "Not mutator found for attribute $attr";
	    $mutator_r->($self, $params{$attr});
	}
    }
}

1;
