package EBox::OpenVPN::Server::Test;
# Description:
use strict;
use warnings;

use base qw(EBox::Test::Class);

use EBox::Test;
use EBox::TestStubs qw(fakeEBoxModule);

use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::File;
use Test::Differences;
use Perl6::Junction qw(any);

use lib '../../../';
use  EBox::OpenVPN::Test;
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

sub fakeFirewall 
{
  fakeEBoxModule(
		 name => 'firewall',
		 package => 'EBox::Firewall',
		 subs => [
			  availablePort => sub {
			    my ($self, @params) = @_;
			    my $openvpn = EBox::Global->modInstance('openvpn');
			    return not $openvpn->usesPort(@params);
			  }
			 ]

		)

}


# XXX replace with #419 when it is done
sub ignoreChownRootCommand : Test(startup)
{
  my $root_r = EBox::Sudo->can('root');

  my $rootIgnoreChown_r = sub {
    my ($cmd) = @_;
    my ($cmdWithoutParams) = split '\s+', $cmd;
    if (($cmdWithoutParams eq 'chown') or ($cmdWithoutParams eq '/bin/chown')) {
      return [];  
    }

    return $root_r->($cmd);
  };


  defined $root_r or die 'Can not get root sub from EBox::Sudo';

  Test::MockObject->fake_module(
				'EBox::Sudo',
				root => $rootIgnoreChown_r,
			       )
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
    EBox::OpenVPN::Test::fakeNetworkModule();
    fakeFirewall();
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();

    my $ca    = EBox::Global->modInstance('ca');
    $ca->destroyCA();
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

sub _newServer
{
    my ($self, $name) = @_;
    defined $name or $name = 'macaco';

    my $openVpnMod = $self->{openvpnModInstance};
    my $server =  new EBox::OpenVPN::Server($name, $openVpnMod);
    
    return $server;
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




sub usesPortTest : Test(11)
{
  my ($self) = @_;

  my $port     =  1194;
  my $distinctPort =  30000;
  my $proto = 'tcp';
  my $distinctProto = 'udp';

  my $oneIface  = 'eth0';
  my $noServerIface = 'wlan0';

  my $server = $self->_newServer('macaco');


  ok $server->usesPort($proto, $port, undef), 
    'same port, same protocol, all ifaces';
  ok (not $server->usesPort($proto, $distinctPort, undef)), 
    'same proto,distinct port, all ifaces';
  ok (not $server->usesPort($distinctProto, $port, undef)), 
    'distinct proto, same port, all ifaces';
  ok (not $server->usesPort($distinctProto, $distinctPort, undef)), 
    'distinct proto and port, all ifaces';
  ok $server->usesPort($proto, $port, $noServerIface),
    'same port, same protocol, specific iface';
  

  $server->setLocal($oneIface);
  diag 'now server listens on one interface';
  ok $server->usesPort($proto, $port, undef),
    'same port, same protocol, all ifaces';
  ok $server->usesPort($proto, $port, $oneIface),
    'same port, same protocol, the iface upon server listens';
  ok (not $server->usesPort($proto, $distinctPort, undef)),
    'same proto,distinct port, all ifaces';
  ok (not $server->usesPort($distinctProto, $port, undef)),
    'distinct proto, same port, all ifaces';
  ok (not $server->usesPort($distinctProto, $distinctPort, undef)),
    'distinct proto and port, all ifaces';
  ok (not $server->usesPort($proto, $port, $noServerIface)),
    'same port, same protocol, a iface upon server do not listens';
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



sub setTlsRemoteTest : Test(12)
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
    my $certificateGetter_r    =  $server->can('tlsRemote');
    my $certificateSetter_r    =  $server->can('setTlsRemote');
    my $correctCertificates   = [qw(certificate1 certificate2)];
    my $incorrectCertificates = [qw(inexistentCertificate expired revoked)];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $certificateGetter_r,
			  setter         => $certificateSetter_r,
			  straightValues => $correctCertificates,
			  deviantValues  => $incorrectCertificates,
			  propierty      => "Server\'s tls-remote option",
			);


  $server->tlsRemote() or die "Must return a tlsRemote or something it is rotten";
  
  lives_ok { $server->setTlsRemote(0) } 'Trying to disable tls-remote option';
  ok !$server->tlsRemote(), "Checking wether tls-remote option was disabled";
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


sub setLocalTest : Test(16)
{
    my ($self) = @_;

    my $server          = $self->_newServer('macaco');
    my $localGetter_r    =  $server->can('local');
    my $localSetter_r    =  $server->can('setLocal');

    my @extIfaces = qw(eth0 eth1);
    my @intIfaces = qw(eth2 eth3);


    # listen in all interfaces 
    EBox::OpenVPN::Test::fakeNetworkModule(\@extIfaces, \@intIfaces);

    my $correctLocals   = [ @extIfaces ];
    my $incorrectLocals = [ @intIfaces, qw(inx1 inx2 )];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $localGetter_r,
			  setter         => $localSetter_r,
			  straightValues => $correctLocals,
			  deviantValues  => $incorrectLocals,
			  propierty      => "Server\'s IP local interface (without masquerade active)",
			);

    lives_ok { $server->setLocal('')  } 'Unsetting local (i.e: all interfaces)';
    ok !$server->local(), 'Checking wether local value was unsetted';

    my $internalIface = $intIfaces[0];
    $server->setMasquerade(1);
    lives_ok { $server->setLocal($internalIface)  } 'Setting a internal iface after make sure masquerade is active';
    is $server->local(), $internalIface, 'Checking that internal iface was correctly set as listen -on interface';
}


sub setMasqueradeTest : Test(32)
{
    my ($self) = @_;

    my $server          = $self->_newServer('macaco');
    my $masqGetter_r    =  $server->can('masquerade');
    my $masqSetter_r    =  $server->can('setMasquerade');

    my @extIfaces = qw(eth0 eth1);
    my @intIfaces = qw(eth2 eth3);

    

    # listen in all interfaces 
    EBox::OpenVPN::Test::fakeNetworkModule(\@extIfaces, \@intIfaces);
    
    setterAndGetterTest(
			  object         => $server,
			  getter         => $masqGetter_r,
			  setter         => $masqSetter_r,
			  straightValues => [0, 1, 1, 0, 0,],
			  deviantValues  => [],
			  propierty      => "Server\'s masquerading when listening on all interfaces",
		       );

    # listen in all interfaces but all interfaces are local
    EBox::OpenVPN::Test::fakeNetworkModule([], \@intIfaces);
    setterAndGetterTest(
			  object         => $server,
			  getter         => $masqGetter_r,
			  setter         => $masqSetter_r,
			  straightValues => [1, 1],
			  deviantValues  => [0],
			  propierty      => "Server\'s masqurading when listening on all interfaces but all interfaces are local ",
		       );

    # listen in a external iface
    EBox::OpenVPN::Test::fakeNetworkModule(\@extIfaces, \@intIfaces);
    $server->setLocal('eth0');

    setterAndGetterTest(
			  object         => $server,
			  getter         => $masqGetter_r,
			  setter         => $masqSetter_r,
			  straightValues => [0, 1, 1, 0, 0,],
			  deviantValues  => [],
			  propierty      => "Server\'s masquerading when listening on a external interface",
		       );
    # listen in a internal iface
    EBox::OpenVPN::Test::fakeNetworkModule(\@extIfaces, \@intIfaces);
    $server->setMasquerade(1); # masuqerade must be on to be able to change to a
                               # local interface
    $server->setLocal('eth2');

    setterAndGetterTest(
			  object         => $server,
			  getter         => $masqGetter_r,
			  setter         => $masqSetter_r,
			  straightValues => [1, 1],
			  deviantValues  => [0],
			  propierty      => "Server\'s masquerading when listening on a internal interface",
		       );
}

sub setInternalTest : Test(4)
{
    my ($self) = @_;

  my $server          = $self->_newServer('macaco');

  dies_ok { $server->setInternal(1) };
  ok not $server->internal();

  lives_ok { $server->setInternal(0) };
  ok not $server->internal();
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

sub setSubnetAndMaskTest : Test(18)
{
    my ($self) = @_;
    my $server = $self->_newServer();

    my @goodCases = (
		     ['192.168.4.0', '255.255.255.0'],
		     ['10.0.0.0', '255.0.0.0'],
		    );

    my @badCases = (
		    ['192.168.257.0', '255.255.255.0'],  # bad address
		     ['10.0.0.0', '255.0.0.1'],        # bad mask
		     ['192.168.4.1', '255.255.255.0'], # host, not net
		     ['10.0.1.0', '255.0.0.0'],        # host, not net
		    );


    foreach my $case_r (@goodCases) {
      my ($addr, $mask) = @{ $case_r };
      lives_ok { $server->setSubnetAndMask($addr, $mask) } 'Calling setSubnetAndMask with good arguments';
      is $server->subnet(), $addr, 'Checking wether net address was correctly changed';
      is $server->subnetNetmask(), $mask, 'Checking wether netmask was correctly changed';
    }

    foreach my $case_r (@badCases) {
      my ($addr, $mask) = @{ $case_r };
      my $oldAddr = $server->subnet();
      my $oldMask = $server->subnetNetmask();

      dies_ok { $server->setSubnetAndMask($addr, $mask) } 'Calling setSubnetAndMask with bad arguments';
      is $server->subnet(), $oldAddr, 'Checking wether net address was preserved';
      is $server->subnetNetmask(), $oldMask, 'Checking wether netmask was preserved';
    }
}


# sub setSubnetNetmaskTest : Test(6)
# {
#     my ($self) = @_;
#     my $server = $self->_newServer('macaco');
#     my $subnetNetmaskGetter_r    = $server->can('subnetNetmask');
#     my $subnetNetmaskSetter_r    = $server->can('setSubnetNetmask');
#     my $straightValues            = [
# 				    '255.255.255.0',
# 				    ];
#     my $deviantValues             = [
# 				    '255.0.255.0',
# 				    '311.255.255.0',
# 				    ];

#     setterAndGetterTest(
# 			  object         => $server,
# 			  getter         => $subnetNetmaskGetter_r,
# 			  setter         => $subnetNetmaskSetter_r,
# 			  straightValues => $straightValues,
# 			  deviantValues  => $deviantValues,
# 			  propierty      => "Server\'s VPN subnet netmask",
# 			);

# }


sub addAndRemoveAdvertisedNet : Test(31)
{
  my ($self) = @_;
  my $server = $self->_newServer('macaco');

  my @straightNets = (
	      ['192.168.24.0', '255.255.255.0'],
	      ['192.168.86.0', '255.255.255.0'],
	      ['10.0.0.0', '255.0.0.0'],
	      [ '192.168.34.0', '255.255.255.0'], # not directly reacheable net
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



  # variables to control the tests' results
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
  dies_ok { $server->addAdvertisedNet('10.0.0.11', '255.255.255.0')  } 'Expecting error when adding a net with both a host insteead of a network';



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


sub certificateRevokedTest : Test(4)
{
  my ($self) = @_;

  my $server = $self->_newServer('macaco');
  my $serverCertificate = $server->certificate();
  my $otherCertificate  = 'no-' . $serverCertificate;


  my @trueCases = (
		   [$otherCertificate, 1],
		   [$serverCertificate, 1],
		   [$serverCertificate, 0],
		  );

  my @falseCases = (
		    [$otherCertificate, 0],
		   );

  foreach my $case_r (@trueCases) {
    ok $server->certificateRevoked(@{ $case_r  }), 'Checking wether certificateRevoked returns true';
  }
  foreach my $case_r (@falseCases) {
    ok !$server->certificateRevoked(@{ $case_r  }), 'Checking wether certificateRevoked returs false' ;
  }
}

sub certificateExpiredTest : Test(12)
{
  my ($self) = @_;

  my $server = $self->_newServer('macaco');
  $server->setService(1);
  my $serverCertificate = $server->certificate();
  my $otherCertificate  = 'no-' . $serverCertificate;

  my @innocuousCases = (
		    [$otherCertificate, 0],
		   );
  
  my @invalidateCertificateCases = (
		   [$otherCertificate, 1],
		   [$serverCertificate, 1],
		   [$serverCertificate, 0],
		  );

  foreach my $case_r (@innocuousCases) {
    lives_ok { $server->certificateExpired( @{ $case_r } ) } 'Notifying server of innocuous certificate expiration';
    is $server->certificate(), $serverCertificate, 'Checking wether server certificate was left unchanged';
    ok $server->service(), 'Checking wether service status of the server was left untouched';
  }

  foreach my $case_r (@invalidateCertificateCases) {
    lives_ok { $server->certificateExpired( @{ $case_r } ) } 'Notifying server of  certificate expiration';

    ok !$server->certificate(), 'Checking wether the server certificate was invalided';
    ok !$server->service(), 'Checking wether the server was disabled';

    # restoring server state
    $self->setUpConfiguration();
    $server = $self->_newServer('macaco');
    $server->setService(1);
  }
}


sub freeCertificateTest : Test(6)
{
  my ($self) = @_;

  my $server = $self->_newServer('macaco');
  $server->setService(1);
  my $serverCertificate = $server->certificate();
  my $otherCertificate  = 'no-' . $serverCertificate;

  lives_ok {  $server->freeCertificate($otherCertificate) } 'Forcing server to free a certificate which does not uses';
  is $server->certificate(), $serverCertificate, 'Checking wether server certificate was left unchanged';
  ok $server->service(), 'Checking wether service status of the server was left untouched';

  lives_ok { $server->freeCertificate($serverCertificate) } 'Forcing serve to release his certificate';
  ok !$server->certificate(), 'Checking wether the server certificate was invalided';
  ok !$server->service(), 'Checking wether the server was disabled';

}


sub ifaceMethodChangedTest : Test(6)
{
  my ($self) = @_;

  my $server = $self->_newServer();

  $server->setLocal('eth0');
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'whateverMethod'), "Checking wether changing the iface method to a non-'nonset' method is not considered disruptive even where done in the local inerface";

  $server->setLocal('');
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'nonset'), "Checking wether changing the iface method to 'nonset' is not considered disruptive where are ifaces left and the interface is not the local interface";

  $server->setLocal('eth0');
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'nonset'), "Checking wether changing the iface method to 'nonset' is considered disruptive if the interface is the local interface";


  EBox::OpenVPN::Test::fakeNetworkModule(['eth0'], []);
  $server->setLocal('');  
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'nonset'), "Checking wether changing the iface method to 'nonset' is  considered disruptive where are only one interface left";

  $server->setLocal('eth0');
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'nonset'), "Checking wether changing the iface method to 'nonset' is  considered disruptive where are only one interface lef0 and adittionally the change is in the local interface";
  ok !$server->ifaceMethodChanged('eth0', 'whatever', 'whateverMethod'), "Checking wether changing the iface method to a non-'nonset' method is not considered disruptive even where done in the local inerface and with only one interface left";
}

sub vifaceDeleteTest : Test(4)
{
  my ($self) = @_;

  my $server = $self->_newServer();

  ok !$server->vifaceDelete('eth0', 'eth2'), 'Checking wether deleting a virtual interface is not reported as disruptive if the interface is not the local interface and there are interfaces left';

  $server->setLocal('eth2');
  ok $server->vifaceDelete('eth0', 'eth2'), 'Checking wether deleting a virtual interface is reported as disruptive when the interface is the local interface';  

  EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

  $server->setLocal('');  
  ok $server->vifaceDelete('eth0', 'eth2'), 'Checking wether deleting a virtual interface is reported as disruptive when the interface is the only interfaces left';  

  $server->setLocal('eth2');
  ok $server->vifaceDelete('eth0', 'eth2'), 'Checking wether deleting a virtual interface is reported as disruptive when the interface is the local interface and there is no interfaces left';  
}


sub freeIfaceTest : Test(4)
{
  my ($self) = @_;

  my $server = $self->_newServer();
  $server->setService(1);

  $server->setLocal('');
  $server->freeIface('eth8'); 
  ok $server->service(), 'Checking wether freeing a interface which is not the local interface in a system which has more interfaces available does not deactivate the server';

  $server->setLocal('eth0');
  $server->freeIface('eth0'); 
  ok !$server->service(), 'Checking wether freeing a interface which is the local interface in a system which has more interfaces available  deactivates the server';


  EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

  $server->setLocal('');  
  $server->setService(1);
  $server->freeIface('eth2');
  ok !$server->service(), 'Checking wether freeing a interface which is not the local interface in a system which has only this  interface available  deactivates the server';

  $server->setLocal('eth2');
  $server->setService(1);
  $server->freeIface('eth2');
  ok !$server->service(), 'Checking wether freeing a interface which is the local interface in a system which has only this  interface available  deactivates the server';
}

sub freeVifaceTest : Test(4)
{
  my ($self) = @_;

  my $server = $self->_newServer();
  $server->setService(1);

  $server->setLocal('');
  $server->freeViface('eth0', 'eth8'); 
  ok $server->service(), 'Checking wether freeing a virtual interface which is not the local virtual interface in a system which has more virtual interfaces available does not deactivate the server';

  $server->setLocal('eth2');
  $server->freeViface('eth8', 'eth2'); 
  ok !$server->service(), 'Checking wether freeing a virtual interface which is the local virtual interface in a system which has more virtual interfaces available  deactivates the server';


  EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

  $server->setLocal('');  
  $server->setService(1);
  $server->freeViface('eth0', 'eth2');
  ok !$server->service(), 'Checking wether freeing a virtual interface which is not the local virtual interface in a system which has only this  virtual interface available  deactivates the server';

  $server->setLocal('eth2');
  $server->setService(1);
  $server->freeViface('eth0', 'eth2');
  ok !$server->service(), 'Checking wether freeing a virtual interface which is the local virtual interface in a system which has only this  virtual interface available  deactivates the server';
}

sub otherNetworkObserverMethodsTest : Test(2)
{
  my ($self) = @_;
  my $server = $self->_newServer();

  ok !$server->staticIfaceAddressChanged('eth0', '192.168.45.4', '255.255.255.0', '10.0.0.1', '255.0.0.0'), 'Checking wether server notifies that is not disrupted after staticIfaceAddressChanged invokation';

  ok !$server->vifaceAdded('eth0', 'eth0:1', '10.0.0.1', '255.0.0.0'), 'Checking wether server notifies that is not disrupted after staticIfaceAddressChanged invokation';
}


sub setServiceTest : Test(56)
{
  my ($self) = @_;
  my $server = $self->_newServer();
  $server->setService(0);

  my @serviceStates = ('0', '1', '1', '0');
  
  diag 'Server in correct state';
  foreach my $newService (@serviceStates) {
    lives_ok { $server->setService($newService) } "Setting server service to $newService";
    is $server->service() ? 1 : 0, $newService, 'Checking wether service was correctly setted';
  }

  diag 'Setting local interface to listen on to a inexistent interface';
  $server->setConfString('local', 'fw5');
  $self->_checkSetServiceWithBadStatus($server, 'using a inexistent interface as local interface to listen on');

  diag 'Setting local interface to listen on to a internal interface';
  $server->setConfString('local', 'eth1');
  $self->_checkSetServiceWithBadStatus($server, 'using a internal interface as local interface to listen on');

  diag 'Setting server to listen in all interfaces but with no interfaces left';
  $server->unsetConf('local');
  EBox::OpenVPN::Test::fakeNetworkModule([], []);
  $self->_checkSetServiceWithBadStatus($server, 'no networks interfaces available');
  EBox::OpenVPN::Test::fakeNetworkModule();

  # certificates bad states
  my $ca    = EBox::Global->modInstance('ca');
  my @certificates = (
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
  

  diag 'Setting server to use a inexistent certificate';
  $server->setConfString('inexistent');
  $self->_checkSetServiceWithBadStatus($server, 'using a inexistent certificate');

  diag 'Setting server to use a expired certificate';
  $server->setConfString('expired');
  $self->_checkSetServiceWithBadStatus($server, 'using a expired certificate');

  diag 'Setting server to use a revoked certificate';
  $server->setConfString('revoked');
  $self->_checkSetServiceWithBadStatus($server, 'using a revoked certificate');
}


sub setPullRoutesAndRipPasswdTest : Test(11)
{
  my ($self) = @_;
  my $server = $self->_newServer();

  my @correctCases = (
		      [0, ''],
		      [0, 'anyPasswd'],
		      [1, 'passwd'],
		     );

  foreach my $case (@correctCases) {
      my ($pull, $passwd) = @{ $case };
      
      lives_ok {
	  $server->setRipPasswd($passwd);
	  $server->setPullRoutes($pull);
      } "Setting server password '$passwd' with pullRoutes $pull";
      
      is $server->ripPasswd(), $passwd, 'checking wether the password was correctly changed';

      my $serverPull = $server->pullRoutes ? 1 : 0;
      is $serverPull, $pull, 'checking wether pull routes states is correct';
  }


  # incorrect case: setting pullRoutes when thereisn't RIP password
  $server->setPullRoutes(0);
  $server->setRipPasswd('');

  dies_ok {
      $server->setPullRoutes(1);
  } 'Checking that tryng to set pull routes option without RIP password raises error';

  ok (not $server->pullRoutes), 'Checking that pullRoutes option remains disabled after incorrect aptemtp to activate it';

}

sub _checkSetServiceWithBadStatus
{
  my ($self, $server, $badState) = @_;

  my @serviceStates = ('0', '1', '1', '0');
  foreach my $newService (@serviceStates) {
    if ($newService) {
      dies_ok { $server->setService($newService) } 'Changing wether activating service with bad state: $badState';
      ok !$server->service, 'Checking wether the client continues inactive';
    }
    else {
      lives_ok { $server->setService($newService) } 'Changing service status to inactive';
      is $server->service() ? 1 : 0, $newService, 'Checking wether the service change was done';
    }
  }
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



1;
