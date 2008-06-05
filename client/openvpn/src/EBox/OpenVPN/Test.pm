package EBox::OpenVPN::Test;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;



use Test::More;
use Test::Exception;
use Test::Differences;
use Test::MockObject;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeEBoxModule);

use Perl6::Junction qw(all any);

use EBox::NetWrappers::TestStub;
use EBox::CA::TestStub;



use lib '../..';

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}


sub _confDir
{
    my ($self) = @_;
    return $self->testDir . '/conf';
}

sub _moduleInstantiationTest : Test
{
    checkModuleInstantiation('openvpn', 'EBox::OpenVPN');
}


sub _setupDirs : Test(startup)
{
  my ($self) = @_;

  my $testDir = $self->testDir();
  my $confDir = $self->_confDir();

  foreach my $dir ($testDir, $confDir) {
    system "rm -rf $dir";
    ($? == 0) or die "$!";
    system "mkdir -p $dir";
    ($? == 0) or die "$!";
  }

}


sub useGlobalTmpDir : Test(startup)
{
  EBox::TestStubs::setEBoxConfigKeys(tmp => '/tmp');
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





sub fakeNetworkModule
{
  my ($externalIfaces_r, $internalIfaces_r) = @_;

  my @externalIfaces = defined $externalIfaces_r ? @{ $externalIfaces_r } :  qw(eth0 eth2);
  my @internalIfaces = defined $internalIfaces_r ? @{ $internalIfaces_r } : ('eth1', 'eth3');

  my $anyExternalIfaces = any(@externalIfaces);
  my $anyInternalIfaces = any(@internalIfaces);

  my $ifaceExistsSub_r = sub {
    my ($self, $iface) = @_;

    return 1 if grep { $iface eq $_ } @externalIfaces;
    return 1 if grep { $iface eq $_ } @internalIfaces;

    return 0;
  };

  my $ifaceIsExternalSub_r = sub {
    my ($self, $iface) = @_;
    return  ($iface eq $anyExternalIfaces);
  };

  my $ifacesSub_r = sub {
      my ($self) = @_;
      my @ifaces = (@externalIfaces, @internalIfaces);
      return \@ifaces;
  };


  fakeEBoxModule(
		 name => 'network',
		 package => 'EBox::Network',
		 subs => [
			  ifaceIsExternal => $ifaceIsExternalSub_r,
			  ifaceExists     => $ifaceExistsSub_r,
			  ExternalIfaces  => sub { return \@externalIfaces },
			  InternalIfaces  => sub { return \@internalIfaces },
			  ifaces          => $ifacesSub_r,
			  ifaceMethod     => sub { return 'anythingButNonSet' },# this if for bug #395

			 ],
		);

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


sub fakeCA : Test(startup)
{
  EBox::CA::TestStub::fake();
}

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
   
    my $confDir = $self->_confDir();
    if (! -d $confDir) {
      system "mkdir -p $confDir" or die "$!";
    }


    my @config = (
		  '/ebox/modules/openvpn/userActive'  => 1,
		  '/ebox/modules/openvpn/internalActive'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $confDir,
		  '/ebox/modules/openvpn/interface_count' => 0,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    fakeInterfaces();
    fakeFirewall();
    fakeNetworkModule();
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}





sub newAndRemoveClientTest : Test(32)
{

  my ($self) = @_;

  my $openVPN = EBox::OpenVPN->_create();
 
  my $reservedClient    =  EBox::OpenVPN->reservedPrefix() . 'test';
  my @clientsNames      = (qw(client1 client2), $reservedClient);
  my @userClientsNames = qw(client1 client2);

  my @clientCerts = $self->_clientCertificates();

  my %clientsParams = (
		       client1 =>  [ 
				    proto => 'tcp',
                                    @clientCerts,
				    servers           => [
							  ['192.168.55.21' => 1040],
							 ],
				    service           => 1,
				    ripPasswd         => 'passwd',
				   ],

		       client2 =>  [ 
				    proto => 'tcp',
                                    @clientCerts,
				    servers           => [
							  ['192.168.55.21' => 1040],
							  ['192.168.55.23' => 1041],
							 ],
				    service           => 1,
				    internal            => 0,
				    ripPasswd         => 'passwd',
				   ],

		       $reservedClient =>  [ 
				     proto => 'tcp',
                                     @clientCerts,
				     servers           => [
							   ['192.168.55.21' => 1040],
							   ['192.168.55.23' => 1041],
							  ],
				     service           => 1,
				     internal            => 1,
			 	    ripPasswd         => 'passwd',
				    ],
		      );


    foreach my $name (@clientsNames) {
	my @params = @{ $clientsParams{$name} };
	$self->_createClientCertificates();

	my $instance;
	lives_ok { $instance = $openVPN->newClient($name, @params)  } 
	  "Testing addition of new client: $name";
	isa_ok $instance, 'EBox::OpenVPN::Client', 
	  'Checking that newClient has returned a client instance';
	ok $openVPN->clientExists($name);
	dies_ok { $instance  = $openVPN->newClient($name, @params)  } 
	  'Checking that the clients cannot be added a second time';
    }

    my @actualClientsNames = $openVPN->clientsNames();
    eq_or_diff [sort @actualClientsNames], [sort @clientsNames], 
      "Checking returned test clients names";


    my @actualClientsNamesForUI = $openVPN->userClientsNames();
    eq_or_diff [sort @actualClientsNamesForUI], [sort @userClientsNames], 
      "Checking returned test clients names for UI";



    # removal cases..
 
	
    foreach my $name (@clientsNames) {
      _checkDeleteDaemon($openVPN, $name, 'client');
#       my $instance;
#       lives_ok { 
# 	my $client = $openVPN->client($name) ;
# 	$client->delete();
# 	} "Testing client removal $name";
# 	dies_ok  { 
# 	  $openVPN->client($name) 
# 	} 'Testing that can not get the client object that represents the deleted client ';

# 	my @actualClientsNames = $openVPN->clientsNames();
# 	ok $name ne all(@actualClientsNames), 
# 	  "Checking that deleted clients name does not appear longer in serves names list";
# 	ok not $openVPN->clientExists($name);



    }
  


}



sub newClientFromBundleTest : Test(7)
{
  my ($self) =@_;

  my $bundlePath = 'testdata/bundle-EBoxToEBox.tar.gz';

  my $name = 'clientFromBundle';

  my $openVPN = EBox::OpenVPN->_create();


  lives_ok {
    $openVPN->newClient($name, bundle => $bundlePath, internal => 0);
  } 'creating client form bundle file';

  my %expectedAttrs = (
		       proto => 'tcp',
		       ripPasswd => 'aaaaa',
		       servers   =>  [ [ '192.168.45.4' => 10008 ] ],
		      );

  my $client = $openVPN->client($name);

  while (my ($attr, $expectedValue) = each %expectedAttrs) {
    if (ref $expectedValue) {
      is_deeply $client->$attr(), $expectedValue, "checking server created from bundle for poperty $attr";      
    }
    else {
      is $client->$attr(), $expectedValue, "checking server created from bundle for popierty $attr";      
    }

  }

  my @certGetters = qw(caCertificate certificate certificateKey);
  foreach my $certGetter (@certGetters) {
    my $certPath = $client->$certGetter();
    diag "path $certPath";
    my $fileExists =  (-r $certPath);
    ok $fileExists , 'checking that certificate file $certGetter exists';
  }

}     

sub _checkDeleteDaemon
{
  my ($openVPN, $name, $type) = @_;
  my $existsMethod = $type . 'Exists';
  my $listMethod = $type . 'sNames';

  my $daemon = $openVPN->$type($name) ;
  my $expectedDeletedData = _expectedDeletedDaemonData($daemon);

  lives_ok { 
    $daemon->delete();
  } "Testing client removal $name";

  dies_ok  { 
    $openVPN->type($name) 
  } 'Testing that can not get the $type object that represents the deleted daemon ';

  my @actualDaemonsNames = $openVPN->$listMethod();
  ok $name ne all(@actualDaemonsNames), 
    "Checking that deleted $type 's name does not appear longer in $type names list";
  ok (not $openVPN->$existsMethod($name)), "Checking negative result of $existsMethod";

  _checkDeletedDaemonData($openVPN, $name, $expectedDeletedData);
}

sub _expectedDeletedDaemonData
{
  my ($daemon) = @_;
  my %deletedData;
  $deletedData{class} = ref $daemon;

  my $type = ref $daemon;
  $type =~ s/^.*:://;
  $type = lc $type;
  $deletedData{type} = $type;

  $deletedData{filesToDelete} = [$daemon->daemonFiles];

  return \%deletedData;
}

sub _checkDeletedDaemonData
{
  my ($openVPN, $daemonName, $expectedDeleted) = @_;

  my $deletedDaemons = $openVPN->_deletedDaemons();

  my $existsDaemon = exists $deletedDaemons->{$daemonName};
  ok  $existsDaemon, "Checking wether $daemonName appears in the list of deleted daemons";
 SKIP:{
    skip 1, 'the daemon do not appear in deleted daemons data' if (not $existsDaemon);
    is_deeply $expectedDeleted, $deletedDaemons->{$daemonName}  ,
    'Checking the deleted daemon information';
  }
}


sub _createClientCertificates
{
  my ($self) = @_;

  my %certs = $self->_clientCertificates;
  
  system 'cp ../OpenVPN/Client/t/testdata/cacert.pem ' . $certs{caCertificate};
  system 'cp ../OpenVPN/Client/t/testdata/cert.pem ' . $certs{certificate};
  system 'cp ../OpenVPN/Client/t/testdata/pkey.pem ' . $certs{certificateKey};  


}

sub _clientCertificates
{
  my ($self) = @_;

  my $dir = $self->testDir;
  return (
	  caCertificate =>  "$dir/ca",
	  certificate   =>   "$dir/cert",
	  certificateKey    => "$dir/key",
	 );
}


sub newClientWithBadPrefixTest : Test(3)
{
  my ($self) = @_;

  # bad prefix cases
  my $openVPN = EBox::OpenVPN->_create();

  my $regularName  = 'mandrill';
  my $reservedName = EBox::OpenVPN->reservedPrefix() . 'baboon';
  my @creationParams =  (
			 proto => 'tcp',
			 servers           => [
					       ['192.168.55.21' => 1040],
					      ],
			 service           => 1,
			);

  
  push @creationParams, $self->_clientCertificates();
  $self->_createClientCertificates();

  my @ripPasswdParam = (ripPasswd => 'ea'); # only needed for no internal cliet

  dies_ok {
    $openVPN->newClient($reservedName, @creationParams, @ripPasswdParam, internal => 0);
  } 'Checking that we cannot create a no internalclient with a reserved name';
  dies_ok {
    $openVPN->newClient($regularName, @creationParams, internal => 1);
  } 'Checking that we cannot create a internal client without a server name';
  is $openVPN->clientsNames(), 0, 'Checking that neither client with incorrect name was added';

}

sub newAndRemoveServerTest  : Test(26)
{

  my $ca = EBox::Global->modInstance('ca');
  my @fakeCertificates = (
			  {
			   dn => 'CN=monos',
			   isCACert => 1,
			  },
			  {
			   dn => "CN=serverCertificate",
			   path => 'certificate.crt',
			   keys => [qw(certificate.pub certificate.key)],
			  },
			 );
  $ca->setInitialState(\@fakeCertificates);


  my $openVPN = EBox::OpenVPN->_create();
  
  my @serversNames = qw(server1 sales staff_vpn );
  my %serversParams = (
			 server1 => [service => 1, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3000, proto => 'tcp',  certificate => 'serverCertificate',  masquerade => 0],
			 sales => [service => 0, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3001, proto => 'tcp',  certificate => 'serverCertificate',  masquerade => 0],
			 staff_vpn => [service => 1, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3002, proto => 'tcp',  certificate => 'serverCertificate',  masquerade => 1],

			 );

    dies_ok {  $openVPN->newServer('incorrect-dot', @{ $serversParams{server1} })  } 
      'Testing addition of incorrect named server';

    foreach my $name (@serversNames) {
	my $server;
	my @params = @{ $serversParams{$name} };
	lives_ok { 
	  $server = $openVPN->newServer($name, @params)  
	} 'Testing addition of new server';
	isa_ok $server, 'EBox::OpenVPN::Server', 
	  'Checking that newServer has returned a server instance';
	ok $openVPN->serverExists($name), 'Checking server exists positive result';

	dies_ok { 
	  $openVPN->newServer($name, @params)  
	} 'Checking that the servers cannot be added a second time';
    }

    my @actualServersNames = $openVPN->serversNames();
    eq_or_diff [sort @actualServersNames], [sort @serversNames],
      "Checking returned test server names";

    # removal cases..
    foreach my $name (@serversNames) {
	lives_ok { 
	  my $server = $openVPN->server($name) ;
	  $server->delete();
	} 'Testing server removal';

	ok (not $openVPN->serverExists($name)), 'Checking server exists negative result'; 

	dies_ok  { $openVPN->server($name) } 'Testing that can not get the server object that represents the deleted server ';

	my @actualServersNames = $openVPN->serversNames();
	ok $name ne all(@actualServersNames), "Checking that deleted servers name does not appear longer in serves names list";

	
    }
}



sub notifyDaemonDeletionTest : Test(3)
{
  my ($self) = @_;

  my $openvpn = EBox::OpenVPN->_create();

  my $name    = 'macaco';
  my $class   ='EBox::OpenVPN::Daemon';
  my $type    = 'daemon';
  my @files   = (
		 '/etc/openvpn/macaco.conf',
		 '/etc/openvpn/macaco.conf.d',
	      );

  lives_ok {
    $openvpn->notifyDaemonDeletion(
				   $name,
				   class => $class,
				   type        => $type,
				   files => \@files

				  );
  } 'executing notifyDaemonDeletion' ;

  my $deletedDaemons;
  lives_ok { $deletedDaemons = $openvpn->_deletedDaemons  }
    'retrieving deleted daemon information';

  my $expectedDeletedDaemons = {
				$name => {
					  class => $class,
					  type => $type,
					  filesToDelete => \@files,
					 }
			       };


  is_deeply $deletedDaemons, $expectedDeletedDaemons, 'checking retrieved deleted daemons information';
}

sub usesPortTest : Test(14)
{
  my ($self) = @_;


  # add servers to openvpn (we add only the attr we care for in this testcase
  my $confDir = $self->_confDir();
  my @config = (
		  '/ebox/modules/openvpn/userActive'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $confDir,

		  '/ebox/modules/openvpn/server/macaco/active'    => 1,
		  '/ebox/modules/openvpn/server/macaco/port'    => 1194,
		  '/ebox/modules/openvpn/server/macaco/proto'   => 'tcp',

		  '/ebox/modules/openvpn/server/mandril/active'    => 1,
		  '/ebox/modules/openvpn/server/mandril/port'    => 1200,
		  '/ebox/modules/openvpn/server/mandril/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/mandril/local'   => 'ppp0',

		  '/ebox/modules/openvpn/server/gibon/active'    => 1,
		  '/ebox/modules/openvpn/server/gibon/port'   => 1294,
		  '/ebox/modules/openvpn/server/gibon/proto'  => 'udp',
		      );
  EBox::GConfModule::TestStub::setConfig(@config);
  
  my $openVPN = EBox::OpenVPN->_create();

  # regular cases
   ok $openVPN->usesPort('tcp', 1194), "Checking if a used port is correctly reported";
  ok $openVPN->usesPort('tcp', 1194, 'ppp0'), "Checking if a used port is correctly reported";
  ok $openVPN->usesPort('tcp', 1194, 'eth0'), "Checking if a used port is correctly reported";
  ok $openVPN->usesPort('tcp', 1194, 'eth1'), "Checking if a used port is correctly reported";

  # protocol awareness
  ok !$openVPN->usesPort('udp', 1194);
  ok $openVPN->usesPort('udp', 1294);
  ok !$openVPN->usesPort('tcp', 1294);

  # local address case
  ok $openVPN->usesPort('tcp', 1200, undef), "Checking if a used port in only one interface is correctly reported";
  ok $openVPN->usesPort('tcp', 1200, 'ppp0'), "Checking if a used port in only one interface is correctly reported";
  ok !$openVPN->usesPort('tcp', 1200, 'eth0'), "Checking if a used port in only one interface does not report as used in another interface";

   # unused ports case
  ok !$openVPN->usesPort('tcp', 1800), "Checking if a unused port is correctly reported";
  ok !$openVPN->usesPort('tcp', 1800, 'eth0'), "Checking if a unused port is correctly reported with a iface eth0";


  # server inactive case
  EBox::GConfModule::TestStub::setEntry( '/ebox/modules/openvpn/server/macaco/active'    => 0);
  ok $openVPN->usesPort('tcp', 1194), "Checking that usesPort does  report port usage for inactive servers";

  # openvpn inactive case
  EBox::GConfModule::TestStub::setEntry( '/ebox/modules/openvpn/userActive'    => 0);
  ok $openVPN->usesPort('tcp', 1194), "Checking that usesPort does report port usage for a inactive OpenVPN module";
}

sub setServiceTest  : Tests(34)
{

 SKIP:{
    skip 34, 'this test need to be reworked in responese to the changes in service method';

  }

    return;

  # CA setup
  my $ca = EBox::Global->modInstance('ca');
  $ca->destroyCA();

  my @fakeCertificates = (
			  {
			   dn => 'CN=monos',
			   isCACert => 1,
			  },
			 );
  $ca->setInitialState(\@fakeCertificates);

  # initial service values
  EBox::TestStubs::setConfigKey( '/ebox/modules/openvpn/userActive'  => 0,);
  EBox::TestStubs::setConfigKey( '/ebox/modules/openvpn/internalActive'  => 0,);

  my $openVPN = EBox::OpenVPN->_create();

  my @serviceStates =  (0, 1, 1, 0,);

  foreach my $serviceExpected (@serviceStates) {
    my $oldService = $openVPN->service();

    lives_ok { $openVPN->setUserService($serviceExpected) } 
      "Changing OpenVPN user service from $oldService to $serviceExpected";
    is $openVPN->userService, $serviceExpected, "Checking if user service has changed to $serviceExpected";
    is $openVPN->internalService, 0, 'Checkin wether internal service continues disabled'; 
    is $openVPN->service, $serviceExpected, "Checking if general service has changed to $serviceExpected";

  }

  foreach my $serviceExpected (@serviceStates) {
    my $oldService = $openVPN->service();
    diag "Checking if OpenVPN internal  service is correctly changed from $oldService to $serviceExpected";

    lives_ok { $openVPN->setInternalService($serviceExpected) } 
      "Changing OpenVPN internal service from $oldService to $serviceExpected";
    is $openVPN->userService, 0, 'Checkin wether user service continues disabled'; 
    is $openVPN->internalService, $serviceExpected, "Checking if internal service has changed to $serviceExpected";  
    is $openVPN->service, $serviceExpected, "Checking if general service has changed to $serviceExpected";
  }

  lives_ok { 
    $openVPN->setInternalService(1);
    $openVPN->setUserService(1);
  } 'Setting both services as active';  
  ok $openVPN->service and $openVPN->userService, "Checking service which both types of service are active";
}



sub fakeInterfaces
{
 # set fake interfaces
  EBox::NetWrappers::TestStub::fake();
  EBox::NetWrappers::TestStub::setFakeIfaces( {
					       eth0 => { up => 1, address => { '192.168.0.100' => '255.255.255.0' } },
					       ppp0 => { up => 1, address => { '192.168.45.233' => '255.255.255.0' } },
					       eth1 => {up  => 1, address => { '192.168.0.233' => '255.255.255.0' }},
					    } );

  # fake network module..
  my @externalIfaces = qw(eth0 ppp0 eth1);
  my @internalIfaces = ();

  my $anyExternalIfaces = any(@externalIfaces);
  my $anyInternalIfaces = any(@internalIfaces);

  my $ifaceExistsSub_r = sub {
    my ($self, $iface) = @_;
    return ($iface eq $anyInternalIfaces) or ($iface eq $anyExternalIfaces);
  };

  my $ifaceIsExternalSub_r = sub {
    my ($self, $iface) = @_;
    return  ($iface eq $anyExternalIfaces);
  };


  fakeEBoxModule(
		 name => 'network',
		 package => 'EBox::Network',
		 subs => [
			  ifaceIsExternal => $ifaceIsExternalSub_r,
			  ifaceExists     => $ifaceExistsSub_r,
			  ExternalIfaces  => sub { return \@externalIfaces },
			  InternalIfaces  => sub { return \@internalIfaces },
			 ],
		);

}






1;
