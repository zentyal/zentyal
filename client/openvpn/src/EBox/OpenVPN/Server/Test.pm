package EBox::OpenVPN::Server::Test;
# Description:
use strict;
use warnings;

use base qw(EBox::Test::Class);

use EBox::Test;
use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::File;
use Test::Differences;

use lib '../../../';
use EBox::OpenVPN;
use EBox::CA::TestStub;

use English qw(-no_match_vars);

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}

sub fakeCA : Test(startup)
{
  EBox::CA::TestStub::fake();
}

sub fakeServer : Test(startup)
{
  Test::MockObject->fake_module ( 'EBox::OpenVPN::Server',
				  _notifyStaticRoutesChange => sub {},
				);
}

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
 
    my $confDir = $self->_confDir();

    $self->{openvpnModInstance} = EBox::OpenVPN->_create();

    my @gids = split '\s', $GID;

    my $macacoCertificateCN ='macacoCertificate';

    my @config = (
		  '/ebox/modules/openvpn/user'  => $UID,
		  '/ebox/modules/openvpn/group' =>  $gids[0],
		  '/ebox/modules/openvpn/conf_dir' => $confDir,
		  '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",		      

		  '/ebox/modules/openvpn/server/macaco/port'    => 1194,
		  '/ebox/modules/openvpn/server/macaco/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/macaco/server_certificate'   => $macacoCertificateCN,
		  '/ebox/modules/openvpn/server/macaco/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/macaco/vpn_netmask' => '255.255.255.0',

		  '/ebox/modules/openvpn/server/gibon/port'   => 1294,
		  '/ebox/modules/openvpn/server/gibon/proto'  => 'udp',

		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    my $ca    = EBox::Global->modInstance('ca');
    

    #setup certificates
    my @certificates = (
			{
			 dn => 'CN=monos',
			 isCACert => 1,
			},
			{
			 dn => "CN=$macacoCertificateCN",
			 path => 'macaco.crt',
			 keys => [qw(macaco.pub macaco.key)],
			},
		       );

    $ca->setInitialState(\@certificates);
    
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();

    my $ca    = EBox::Global->modInstance('ca');
    $ca->destroyCA();
}

sub _useOkTest : Test
{
    use_ok ('EBox::OpenVPN::Server');
}

sub newServerTest : Test(6)
{
    my ($self) = @_;
    my $openVpnMod = $self->{openvpnModInstance};

    my @existentServers = qw(macaco gibon);
    foreach my $serverName (@existentServers) {
	my $serverInstance;
	lives_ok { $serverInstance = new EBox::OpenVPN::Server($serverName, $openVpnMod) };  
	isa_ok $serverInstance, 'EBox::OpenVPN::Server';
    }

    my @inexistentServers = qw(bufalo gacela);
    foreach my $serverName (@inexistentServers) {
	dies_ok {  new EBox::OpenVPN::Server($serverName, $openVpnMod) } 'Checking that we can not create OpenVPN servers objects if the server is not registered in configuration';  
    }
}


sub setCertificateTest : Test(10)
{
  my ($self) = @_;

    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
			{
			 dn => 'CN=monos',
			 isCACert => 1,
			},
			{
			 dn => 'CN=certificate1',
			 path => '/certificate1.crt',
			},
			{
			 dn    => 'CN=certificate2',
			 path => '/certificate2.crt',
			},
			{
			 dn    => 'CN=expired',
			 state => 'E',
			 path => '/certificate2.crt',
			},
			{
			 dn    => 'CN=revoked',
			 state => 'R',
			 path => '/certificate2.crt',
			},
		       );
  $ca->setInitialState(\@certificates);

    my $server          = $self->_newServer('macaco');
    my $certificateGetter_r    =  $server->can('certificate');
    my $certificateSetter_r    =  $server->can('setCertificate');
    my $correctCertificates   = [qw(certificate1 certificate2)];
    my $incorrectCertificates = [qw(inexistentCertificate expired revoked)];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $certificateGetter_r,
			  setter         => $certificateSetter_r,
			  straightValues => $correctCertificates,
			  deviantValues  => $incorrectCertificates,
			  propierty      => "Server\'s certificate",
			);


}


sub setProtoTest : Test(6)
{
    my ($self) = @_;
 
    my $server          = $self->_newServer('macaco');
    my $protoGetter_r    =  $server->can('proto');
    my $protoSetter_r    =  $server->can('setProto');
    my $correctProtos   = [qw(tcp udp)];
    my $incorrectProtos = [qw(mkkp)];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $protoGetter_r,
			  setter         => $protoSetter_r,
			  straightValues => $correctProtos,
			  deviantValues  => $incorrectProtos,
			  propierty      => "Server\'s IP protocol",
			);
}


sub setProtoTestForMultipleServers : Test(1)
{
  my ($self) = @_;

    my $samePort     =  20000;
    my $distinctPort =  30000;
    my $sameProto = 'tcp';
    my $distinctProto = 'udp';

    my $server = $self->_newServer('macaco');
    $server->setProto($distinctProto);
    $server->setPort($samePort);

    my $server2  = $self->_newServer('gibon');
    $server2->setProto($sameProto);
    $server2->setPort($samePort);

    dies_ok { $server->setProto($sameProto)   } 'Checking that setting protocol is not permitted when we have the same pair of protocol and port in another server';
}

sub setPortTestForSingleServer : Test(19)
{
    my ($self) = @_;
 
    my $server          = $self->_newServer('macaco');
    
    dies_ok {$server->setPort(100)} 'Setting port before protocol must raise a error';

    $server->setProto('tcp');

    my $portGetter_r    = $server->can('port');
    my $portSetter_r    = $server->can('setPort');
    my $correctPorts    = [1024, 1194, 4000];
    my $incorrectPorts  = [0, -1, 'ea', 1023, 40, 0.4];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $portGetter_r,
			  setter         => $portSetter_r,
			  straightValues => $correctPorts,
			  deviantValues  => $incorrectPorts,
			  propierty      => "Server\'s IP port",
			);

 
}


sub setPortTestForMultipleServers : Test(4)
{
    my ($self) = @_;
 
    my $samePort     =  20000;
    my $distinctPort =  30000;
    my $sameProto = 'tcp';
    my $distinctProto = 'udp';

    my $server = $self->_newServer('macaco');
    $server->setProto($sameProto);
    $server->setPort($samePort);

    my $server2  = $self->_newServer('gibon');
    $server2->setProto($sameProto);
    $server2->setPort($distinctPort);

    dies_ok { $server2->setPort($samePort) } "Checking that setting a duplicate port and protocol combination raises error";
    is $server2->port(), $distinctPort, "Checking that the port remains untouched after the failed setting operation";

    $server2->setProto($distinctProto);
    lives_ok { $server2->setPort($samePort) } "Checking that is correct for two servers be setted to the same port number as long they are not using the same protocol";
    is $server2->port(), $samePort, "Checking that prevoius setPort call was successful";
}


sub setLocalTest : Test(12)
{
    my ($self) = @_;

    my $server          = $self->_newServer('macaco');
    my $localGetter_r    =  $server->can('local');
    my $localSetter_r    =  $server->can('setLocal');
    my $correctLocals   = [qw(192.168.5.21 127.0.0.1 68.45.32.43) ];
    my $incorrectLocals = [ qw(21 'ea' 192.168.5.22)];

    
    Test::MockObject->fake_module('EBox::NetWrappers', 'list_local_addresses' => sub { return @{ $correctLocals  } } );

    setterAndGetterTest(
			  object         => $server,
			  getter         => $localGetter_r,
			  setter         => $localSetter_r,
			  straightValues => $correctLocals,
			  deviantValues  => $incorrectLocals,
			  propierty      => "Server\'s IP local address",
			);

}


sub keyTest : Test(2)
{
  my ($self) = @_;
  
  my $server          = $self->_newServer('macaco');

  lives_ok { $server->key() } 'key' ;

  EBox::TestStubs::setConfigKey('/ebox/modules/openvpn/server/macaco/server_certificate' => undef);
  dies_ok {  $server->key()  } 'Checking that trying to get the key from a server without certificate raises error';
}

sub setterAndGetterTest
{
    my %params = @_;
    my $object         = $params{object};
    my $propierty      = exists $params{propierty} ? $params{propierty} : 'propierty';
    my @straightValues = @{ $params{straightValues} };
    my @deviantValues  = @{ $params{deviantValues} };
    my $setter_r       = $params{setter};
    my $getter_r       = $params{getter};

    foreach my $value (@straightValues) {
	lives_ok { $setter_r->($object, $value) } "Trying to set $propierty to $value";

	my $actualValue = $getter_r->($object);
	is $actualValue, $value, "Using getter to check that $propierty was correcty setted" ;
    }

    foreach my $value (@deviantValues) {
	my $beforeValue = $getter_r->($object);

	dies_ok { $setter_r->($object, $value) } "Checking that setting $propierty to the invalid value $value raises error";

	my $actualValue = $getter_r->($object);
	is $actualValue, $beforeValue, "Checking that $propierty\'s value was left untouched";
    }
}



sub writeConfFileTest : Test(2)
{
    my ($self) = @_;

    my $stubDir  = $self->testDir() . '/stubs';
    my $confDir =   $self->testDir() . "/config";
    foreach my $testSubdir ($confDir, $stubDir, "$stubDir/openvpn") {
	system ("rm -rf $testSubdir");
	($? == 0) or die "Error removing  temp test subdir $testSubdir: $!";
	system ("mkdir -p $testSubdir");
	($? == 0) or die "Error creating  temp test subdir $testSubdir: $!";
    }
    
    
    system "cp ../../../../stubs/openvpn.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";
    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir, tmp => '/tmp');

  
    my $server = $self->_newServer('macaco');
    lives_ok { $server->writeConfFile($confDir)  } 'Calling writeConfFile method in server instance';
    file_exists_ok("$confDir/macaco.conf", "Checking if the new configuration file was written");
    diag "TODO: try to validate automatically the generated conf file without ressorting a aspect-like thing. (You may validate manually with openvpn --config)";
}

sub setSubnetTest : Test(6)
{
    my ($self) = @_;
    my $server = $self->_newServer('macaco');
    my $subnetGetter_r    = $server->can('subnet');
    my $subnetSetter_r    = $server->can('setSubnet');

    my $straightCases =[
			'10.8.0.0'
			];
    my $deviantCases = [
			'255.3.4.3',
			'domainsnotok.com',
			];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $subnetGetter_r,
			  setter         => $subnetSetter_r,
			  straightValues => $straightCases,
			  deviantValues  => $deviantCases,
			  propierty      => "Server\'s VPN subnet",
			);

   

  
}


sub setSubnetNetmaskTest : Test(6)
{
    my ($self) = @_;
    my $server = $self->_newServer('macaco');
    my $subnetNetmaskGetter_r    = $server->can('subnetNetmask');
    my $subnetNetmaskSetter_r    = $server->can('setSubnetNetmask');
    my $straightValues            = [
				    '255.255.255.0',
				    ];
    my $deviantValues             = [
				    '255.0.255.0',
				    '311.255.255.0',
				    ];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $subnetNetmaskGetter_r,
			  setter         => $subnetNetmaskSetter_r,
			  straightValues => $straightValues,
			  deviantValues  => $deviantValues,
			  propierty      => "Server\'s VPN subnet netmask",
			);

}


sub addAndRemoveAdvertisedNet : Test(25)
{
  my ($self) = @_;
  my $server = $self->_newServer('macaco');

  my @straightNets = (
	      ['192.168.24.1', '255.255.255.0'],
	      ['192.168.86.0', '255.255.255.0'],
	      ['10.0.0.0', '255.0.0.0'],
	     );

  # assure straights nets can be reached using fake routes
  EBox::TestStubs::setFakeIfaces(
				 'eth0' => {
					    up => 1,
					    address => {
					    '192.168.34.21' => '255.255.255.0',
						       }
					   },
				) ;
  my @fakeRoutes = map {
    my $addr = EBox::NetWrappers::to_network_with_mask(@{ $_ });
     ( $addr => '192.168.34.21')  # (route, gateway)
  } @straightNets;

  EBox::TestStubs::setFakeRoutes(@fakeRoutes);



  # varaibles to control the tests' results
  my ($address, $mask);
  my @nets;
  my $netCount = 0;
  my $netFound;

  # add straight cases 

  foreach my $net (@straightNets) {
    ($address, $mask)= @{ $net };
    lives_ok { $server->addAdvertisedNet($address, $mask)  } 'Adding advertised net to the server';
    $netCount += 1;

    @nets = $server->advertisedNets();
    is @nets, $netCount, 'Checking if the net count is coherent';
    
    $netFound = _advertisedNetFound($address, $mask, @nets);
    ok $netFound, 'Checking wether net was correctly reported by the server as used';
  }

  # add deviant cases 
  dies_ok { $server->addAdvertisedNet($address, $mask)  } 'Expecting error when adding a duplicate net';
  dies_ok { $server->addAdvertisedNet('10.0.0.0.0', '255.255.255.0')  } 'Expecting error when adding a net with a incorrect address';
  dies_ok { $server->addAdvertisedNet('10.0.0.0', '256.255.255.0')  } 'Expecting error when adding a net with a incorrect netmask';
  dies_ok { $server->addAdvertisedNet('10.0.0.0.1111', '0.255.255.0')  } 'Expecting error when adding a net with both a incorrect address and netmask';
   dies_ok { $server->addAdvertisedNet('192.168.34.0', '255.255.255.0')  } 'Expecting error when adding a private net not reacheable by eBox'; 

  # remove straight cases 
  
  foreach my $net (@straightNets) {
    ($address, $mask)= @{ $net };
    lives_ok { $server->removeAdvertisedNet($address, $mask)  } 'Removing advertised net from the server';

    $netCount -= 1;

    @nets = $server->advertisedNets();
    is @nets, $netCount, 'Checking if the net count is coherent';

    $netFound = _advertisedNetFound($address, $mask, @nets);
    ok !$netFound, 'Checked wether net was correctly removed from the server';
  }

  # remove deviant cases
  dies_ok { $server->removeAdvertisedNet('192.168.45.0', '255.255.255.0')  } 'Expecting error when removing a inexistent net';
  throws_ok { $server->removeAdvertisedNet('10.0.0.0.0', '255.255.255.0')  } 'EBox::Exceptions::InvalidData', 'Expecting error when removing a net with a incorrect address';
}

sub _advertisedNetFound
 {
   my ($address, $mask, @advertisedNets) = @_;

    my $netFound = grep {
      my ($address2, $mask2) = @{ $_ };
      ($address2 eq $address) and ($mask eq $mask2)
    } @advertisedNets;

   return $netFound;
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

sub _newServer
{
    my ($self, $name) = @_;
    my $openVpnMod = $self->{openvpnModInstance};
    my $server =  new EBox::OpenVPN::Server($name, $openVpnMod);
    
    return $server;
}

1;
