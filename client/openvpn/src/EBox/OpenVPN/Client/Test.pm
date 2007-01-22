package EBox::OpenVPN::Client::Test;
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



sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
 
    my $confDir = $self->_confDir();

    $self->{openvpnModInstance} = EBox::OpenVPN->_create();

    my @gids = split '\s', $GID;


    my @config = (
		  '/ebox/modules/openvpn/user'  => $UID,
		  '/ebox/modules/openvpn/group' =>  $gids[0],
		  '/ebox/modules/openvpn/conf_dir' => $confDir,
		  '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",

		  '/ebox/modules/openvpn/client/client1/service' => 0,	
		  '/ebox/modules/openvpn/client/client1/proto'   => 'tcp',	
		  '/ebox/modules/openvpn/client/client1/caCertificatePath'   => '/etc/openvpn/ca.pem',	
		  '/ebox/modules/openvpn/client/client1/certificatePath'   => '/etc/openvpn/client.pem',	
		  '/ebox/modules/openvpn/client/client1/certificateKey'   => '/etc/openvpn/client.key',	
		  '/ebox/modules/openvpn/client/client1/servers/openvpn.macaco.org'   => 1040,	
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');


}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();


}

sub _useOkTest : Test
{
    use_ok ('EBox::OpenVPN::Client');
}

sub newClientTest : Test(4)
{
    my ($self) = @_;
    my $openVpnMod = $self->{openvpnModInstance};

    my @existentClients = qw(client1);
    foreach my $clientName (@existentClients) {
	my $clientInstance;
	lives_ok { $clientInstance = new EBox::OpenVPN::Client($clientName, $openVpnMod) };  
	isa_ok $clientInstance, 'EBox::OpenVPN::Client';
    }

    my @inexistentClients = qw(bufalo gacela);
    foreach my $clientName (@inexistentClients) {
	dies_ok {  new EBox::OpenVPN::Client($clientName, $openVpnMod) } 'Checking that we can not create OpenVPN clients objects if the client is not registered in configuration';  
    }
}




sub setProtoTest : Test(6)
{
    my ($self) = @_;
 
    my $client          = $self->_newClient();
    my $protoGetter_r    =  $client->can('proto');
    my $protoSetter_r    =  $client->can('setProto');
    my $correctProtos   = [qw(tcp udp)];
    my $incorrectProtos = [qw(mkkp)];

    setterAndGetterTest(
			  object         => $client,
			  getter         => $protoGetter_r,
			  setter         => $protoSetter_r,
			  straightValues => $correctProtos,
			  deviantValues  => $incorrectProtos,
			  propierty      => "Client\'s IP protocol",
			);
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


sub setServersTest : Test(12)
{
    my ($self) = @_;
 
    my $client          = $self->_newClient();

    my @correctServers   = (
			     [ 
			      ['192.168.34.24', 10005],   
			     ],
			     [ 
			      ['openvpn.antropoides.com', 10007],   
			     ],
			     [ 
			      ['10.40.34.24',   5004],   
			      ['openvpn.monos.org', 10001],   
			     ],
			    );

    my @incorrectServers = (
			     [ 
			      ['192.168.34.257', 10005],   # bad ip address
			     ],
			     [ 
			      ['openvpn_antropoides.com', 10007],  # bad hostname 
			     ],
			     [ 
			      ['10.40.34.24',   5004],         # bad second server
			      ['', 10001],   
			     ],

			    );

    foreach my $servers_r (@correctServers) {
      lives_ok { $client->setServers($servers_r) } 'Setting correct servers';
      eq_or_diff $client->servers(), $servers_r, 'Checking wether servers were correctly stored';
    }

    foreach my $servers_r (@incorrectServers) {
      my $actualServers_r = $client->servers();
      dies_ok { $client->setServers($servers_r) } 'Checking wether trying to set incorrect server raises error';
      eq_or_diff $client->servers(), $actualServers_r, 'Checking wether stored server were left untouched after faield attempt of settign them';
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
    
    
    system "cp ../../../../stubs/openvpn-client.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";
    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir, tmp => '/tmp');

  
    my $client = $self->_newClient();
    lives_ok { $client->writeConfFile($confDir)  } 'Calling writeConfFile method in client instance';
    file_exists_ok("$confDir/client1.conf", "Checking if the new configuration file was written");
    diag "TODO: try to validate automatically the generated conf file without ressorting a aspect-like thing. (You may validate manually with openvpn --config)";
}





sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

sub _newClient
{
    my ($self, $name) = @_;
    defined $name or $name = 'client1';

    my $openVpnMod = $self->{openvpnModInstance};
    my $server =  new EBox::OpenVPN::Client($name, $openVpnMod);
    
    return $server;
}

1;
