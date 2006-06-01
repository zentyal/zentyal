package EBox::OpenVPN::Server::Test;
# Description:
use strict;
use warnings;

use base qw(EBox::Test::Class);

use EBox::GConfModule::Mock;
use EBox::Global::Mock;
use EBox::Test;
use Test::More;
use Test::Exception;
use Test::MockModule;
use Test::File;
use Test::Differences;

use lib '../../../';
use EBox::OpenVPN;

use English qw(-no_match_vars);

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}


sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
   

    $self->{openvpnModInstance} = EBox::OpenVPN->_create();

    my @gids = split '\s', $GID;

        my @config = (
		  '/ebox/modules/openvpn/user'  => $UID,
		  '/ebox/modules/openvpn/group' =>  $gids[0],
		  '/ebox/modules/openvpn/conf_dir' => $self->_confDir(),

		  '/ebox/modules/openvpn/server/macaco/port'    => 1194,
		  '/ebox/modules/openvpn/server/macaco/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/macaco/ca_certificate'   => 'monos.crt',
		  '/ebox/modules/openvpn/server/macaco/server_certificate'   => 'macaco.crt',
		  '/ebox/modules/openvpn/server/macaco/server_key'   => 'macaco.key',
		  '/ebox/modules/openvpn/server/macaco/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/macaco/vpn_netmask' => '255.255.255.0',

		  '/ebox/modules/openvpn/server/gibon/port'   => 1294,
		  '/ebox/modules/openvpn/server/gibon/proto'  => 'udp',

		  );

    EBox::GConfModule::Mock::setConfig(@config);
    EBox::Global::Mock::setEBoxModule('openvpn' => 'EBox::OpenVPN');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::Mock::setConfig();
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


sub setProtoTest : Test(6)
{
    my ($self) = @_;
 
    my $server          = $self->_newServer('macaco');
    my $portGetter_r    =  $server->can('proto');
    my $portSetter_r    =  $server->can('setProto');
    my $correctProtos   = [qw(tcp udp)];
    my $incorrectProtos = [qw(mkkp)];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $portGetter_r,
			  setter         => $portSetter_r,
			  straightValues => $correctProtos,
			  deviantValues  => $incorrectProtos,
			  propierty      => "Server\'s IP protocol",
			);
}


sub setPortTest : Test(20)
{
    my ($self) = @_;
 
    my $server          = $self->_newServer('macaco');
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


    # duplicates port test
    my $server2  = $self->_newServer('gibon');
    my $samePort = 3030;
    my $previousPort =  $server2->port();
    $server->setPort($samePort);

    dies_ok { $server2->setPort($samePort) } "Checking that setting a duplicate port raises error";
    is $server2->port(), $previousPort, "Checking that the port remains untouched after the failed setting operation";
}

sub setLocalTest : Test(12)
{
    my ($self) = @_;
    my $mockedNetWrappersModule = new Test::MockModule('EBox::NetWrappers');

    my $server          = $self->_newServer('macaco');
    my $localGetter_r    =  $server->can('local');
    my $localSetter_r    =  $server->can('setLocal');
    my $correctLocals   = [qw(192.168.5.21 127.0.0.1 68.45.32.43) ];
    my $incorrectLocals = [ qw(21 'ea' 192.168.5.22)];

    
    $mockedNetWrappersModule->mock('list_local_addresses' => sub { return @{ $correctLocals  } } );

    setterAndGetterTest(
			  object         => $server,
			  getter         => $localGetter_r,
			  setter         => $localSetter_r,
			  straightValues => $correctLocals,
			  deviantValues  => $incorrectLocals,
			  propierty      => "Server\'s IP local address",
			);

    $mockedNetWrappersModule->unmock_all();
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
    EBox::Config::Mock::setConfigKeys('stubs' => $stubDir, tmp => '/tmp');

  
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


sub setCACertificateTest : Test(6)
{
    my ($self) = @_;
    my $server                   = $self->_newServer('macaco');
    my $caCertificateGetter_r    = $server->can('caCertificate');
    my $caCertificateSetter_r    = $server->can('setCaCertificate');
    my $correctCaCertificates    = [
				    '/etc/openvpn/certs/ca.cert',
				    ];
    my $incorrectCaCertificates  = [
				    'openvpn/certs/ca.cert',
				    '/etc/../certs/ca.cert',
				    ];

    setterAndGetterTest(
			  object         => $server,
			  getter         => $caCertificateGetter_r,
			  setter         => $caCertificateSetter_r,
			  straightValues => $correctCaCertificates,
			  deviantValues  => $incorrectCaCertificates,
			  propierty      => "Server\'s caCertificate",
			);

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
