package DaemonTest;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;
use Test::More;
use Test::Exception;
use EBox::Global::TestStub;
use EBox::GConfModule::TestStub;
use EBox::Config::TestStub;
use EBox::CA::TestStub;

use EBox::OpenVPN;



sub notice : Test(startup)
{
  die "This test is broken, don't run it";

    diag "This test is designed to be run as root. That is neccesary for try the openvpn daemon execution but it may be a security risk";
    diag "Make sure that the tun device is created!.";
}

sub testDir
{
    return  '/tmp/ebox.openvpn.daemon.test';
}


sub _confDir
{
    my ($self) = @_;
    return $self->testDir . '/conf';
}


sub fakeCA : Test(startup)
{
  EBox::CA::TestStub::fake();
}

sub clearTestDir: Test(startup)
{
  my ($self) = @_;
  system "rm -rf " . $self->testDir();
}

sub setupEBoxConf : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();

    my @config = (
		  '/ebox/modules/openvpn/active'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nogroup',  # in non-Debian systems this will be posssibly 'nobody'
		  '/ebox/modules/openvpn/conf_dir' => $confDir,
		  '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",

		  '/ebox/modules/openvpn/server/macaco/active'    => 1,
		  '/ebox/modules/openvpn/server/macaco/port'    => 1194,
		  '/ebox/modules/openvpn/server/macaco/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/macaco/server_certificate'   => "serverCertificate",
		  '/ebox/modules/openvpn/server/macaco/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/macaco/vpn_netmask' => '255.255.255.0',

		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    EBox::Config::TestStub::setConfigKeys(tmp => $self->testDir);



     #setup certificates
    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
			{
			 dn => 'CN=monos',
			 isCACert => 1,
			 path => "$confDir/tmp-ca.crt",
			},
			{
			 dn => "CN=serverCertificate",
			 path => "$confDir/server.crt",
			 keys => ["$confDir/inexistent", "$confDir/server.key"],
			},
		       );

    $ca->setInitialState(\@certificates);
    
}


sub setupFiles : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();
   
    system "/bin/mkdir -p $confDir";
    ($? == 0) or  die "mkdir -p $confDir: $!";

    system "/bin/cp  testdata/*   $confDir/";
    if ($? != 0) {
	die "Can not copy certificates files in $confDir: $!";
    }
}


sub setupStubDir : Test(setup)
{
    my ($self) = @_;
    my $stubDir  = $self->testDir() . '/stubs';

    system ("/bin/mkdir -p $stubDir/openvpn");
    ($? == 0) or die "Error creating  temp test subdir $stubDir: $!";
    
    system "/bin/cp ../../../stubs/openvpn.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";

    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir);
}


sub killDaemons : Test(setup)  
{
    system "pkill openvpn";
}

sub clearStubDir : Test(teardown)
{
    my ($self) = @_;
    my $stubDir  = $self->testDir() . '/stubs';
    system ("/bin/rm -rf $stubDir");
    ($? == 0) or die "Error removing  temp test subdir $stubDir: $!";
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}


sub clearFiles : Test(teardown)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();
   
    system "/bin/rm -rf $confDir";
    if ($? != 0) {
	die "Can not clear test dir $confDir: $!";
    }
}

sub daemonTest : Test(25)
{
     _regenConfigTest(serversNames => [qw(macaco )]);
}

sub _addServerToConfig
{
    my ($self) = @_;
    my $confDir = $self->_confDir();

    my %extraConfig = (
		  '/ebox/modules/openvpn/server/gibon/active'    => 1,
		  '/ebox/modules/openvpn/server/gibon/port'    => 1196,
		  '/ebox/modules/openvpn/server/gibon/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/gibon/ca_certificate'   => "$confDir/tmp-ca.crt",
		  '/ebox/modules/openvpn/server/gibon/server_certificate'   => "$confDir/server.crt",
		  '/ebox/modules/openvpn/server/gibon/server_key'   => "$confDir/server.key",
		  '/ebox/modules/openvpn/server/gibon/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/gibon/vpn_netmask' => '255.255.255.0',

		  );

    while ( my ($key, $value) = each %extraConfig) {
	EBox::GConfModule::TestStub::setEntry($key, $value);
    }

}

sub multipleDaemonTest #: Test(50)
{
    my ($self) = @_;
    $self->_addServerToConfig();
    _regenConfigTest(serversNames => [qw(macaco gibon)])
}

sub daemonDisabledTest : Test(10)
{
    my ($self) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');
    defined $openvpn or die "Can not get OPenVPN instance";
    my $bin = $openvpn->openvpnBin;
    
    my $server = $openvpn->server('macaco');
    $server->setService(0);

    my @serviceSequence =  (0, 1, 1, 0, 0);
    foreach my $service (@serviceSequence) {
	$openvpn->setService($service);
	lives_ok { $openvpn->_regenConfig() } "Regenerating service configuration";
	sleep 1; # to avoid false results

	system "pgrep -f $bin";
	my $processNotFound      = ($? != 0) ? 1 : 0;
	ok $processNotFound, "Checking that a disabled server will not start";

    }

}


sub daemonsDisabledAndEnabledTest #: Test(35)
{
    my ($self) = @_;
    $self->_addServerToConfig();
    my $openvpn = EBox::Global->modInstance('openvpn');
    defined $openvpn or die "Can not get OPenVPN instance";
    my $bin = $openvpn->openvpnBin;
    
    my $server = $openvpn->server('macaco');
    $server->setService(0);

  
    _regenConfigTest(serversNames => [qw(gibon)]);
}


sub _regenConfigTest
{
    my %args = @_;
    my @serversNames = @{ $args{serversNames} };

   my $openVPN = EBox::Global->modInstance('openvpn');
    defined $openVPN or die "Can not get OPenVPN instance";


    my @serviceSequence =  (0, 1, 1, 0, 0);
    foreach my $service (@serviceSequence) {
	$openVPN->setService($service);
	lives_ok { $openVPN->_regenConfig() } "Regenerating service configuration";
	sleep 1; # to avoid false results

	_checkService($openVPN, $service);
	foreach my $name (@serversNames) {
	    _checkDaemon($openVPN, $service, $name);
	}
    }
}






sub _checkService
{
    my ($openVPN, $service) = @_;
    my $bin = $openVPN->openvpnBin;

    system "pgrep -f $bin";
    my $foundProcess      = ($?==0) ? 1 : 0;
    my $running = $openVPN->running ? 1 : 0;

    is $foundProcess, $running, "Checking if pgrep and  running method results are coherent";
    is $running, $service, "Checking if running and service status are in sync";
}


sub _checkDaemon
{
    my ($openVPN, $service, $daemonName) = @_;
    my $bin = $openVPN->openvpnBin;
    my $server = $openVPN->server($daemonName);

    system "pgrep -f $bin.*$daemonName";
    my $foundDaemonProccess      = ($?==0) ? 1 : 0;
    my $running = $server->running ? 1 : 0;

    is $foundDaemonProccess, $running, "Checking if pgrep output and running method of  server $daemonName  results are coherent";
    is $running, $service, "Checking if running and service statua are coherent";

}

1;
