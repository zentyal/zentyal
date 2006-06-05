package DaemonTest;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;
use Test::More;
use Test::Exception;
use EBox::Global::Mock;
use EBox::GConfModule::Mock;
use EBox::Config::Mock;

use EBox::OpenVPN;


sub notice : Test(startup)
{
    diag "This test is designed to be run as root. That is neccesary for try the openvpn daemon execution but it may be a security risk";
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

sub setupEBoxConf : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();

    my @config = (
		  '/ebox/modules/openvpn/active'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $confDir,
		  '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",

		  '/ebox/modules/openvpn/server/macaco/port'    => 1194,
		  '/ebox/modules/openvpn/server/macaco/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/macaco/ca_certificate'   => "$confDir/tmp-ca.crt",
		  '/ebox/modules/openvpn/server/macaco/server_certificate'   => "$confDir/server.crt",
		  '/ebox/modules/openvpn/server/macaco/server_key'   => "$confDir/server.key",
		  '/ebox/modules/openvpn/server/macaco/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/macaco/vpn_netmask' => '255.255.255.0',

		  );

    EBox::GConfModule::Mock::setConfig(@config);
    EBox::Global::Mock::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Config::Mock::setConfigKeys(tmp => $self->testDir);
}


sub setupFiles : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();
   
    system "mkdir -p $confDir";
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

    system ("mkdir -p $stubDir/openvpn");
    ($? == 0) or die "Error creating  temp test subdir $stubDir: $!";
    
    system "cp ../../../stubs/openvpn.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";

    EBox::Config::Mock::setConfigKeys('stubs' => $stubDir);
}


sub killDaemons : Test(setup)
{
    system "pkill openvpn";
}

sub clearStubDir : Test(teardown)
{
    my ($self) = @_;
    my $stubDir  = $self->testDir() . '/stubs';
    system ("rm -rf $stubDir");
    ($? == 0) or die "Error removing  temp test subdir $stubDir: $!";
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::Mock::setConfig();
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

sub daemonTest : Test(35)
{
     _regenConfigTest(serversNames => [qw(macaco )]);
}

sub _addServerToConfig
{
    my ($self) = @_;
    my $confDir = $self->_confDir();

    my %extraConfig = (
		  '/ebox/modules/openvpn/server/gibon/port'    => 1196,
		  '/ebox/modules/openvpn/server/gibon/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/gibon/ca_certificate'   => "$confDir/tmp-ca.crt",
		  '/ebox/modules/openvpn/server/gibon/server_certificate'   => "$confDir/server.crt",
		  '/ebox/modules/openvpn/server/gibon/server_key'   => "$confDir/server.key",
		  '/ebox/modules/openvpn/server/gibon/vpn_net'     => '10.0.8.0',
		  '/ebox/modules/openvpn/server/gibon/vpn_netmask' => '255.255.255.0',

		  );

    while ( my ($key, $value) = each %extraConfig) {
	EBox::GConfModule::Mock::setEntry($key, $value);
    }

}

sub multipleDaemonTest : Test(50)
{
    my ($self) = @_;
    $self->_addServerToConfig();
    _regenConfigTest(serversNames => [qw(macaco gibon)])
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
    is $foundProcess, $service, "Checking pgrep output when querying for openvpn";
    is $running, $foundProcess, "Checking if running output is coherent with pgrep output";
}


sub _checkDaemon
{
    my ($openVPN, $service, $daemonName) = @_;
    my $bin = $openVPN->openvpnBin;
    my $server = $openVPN->server($daemonName);

    system "pgrep -f $bin.*$daemonName";
    my $foundDaemonProccess      = ($?==0) ? 1 : 0;
    my $running = $server->running ? 1 : 0;

    is $foundDaemonProccess, $running, "Checking if pgrep and running method of  server $daemonName  results are coherent";
    is $foundDaemonProccess, $service, "Checking pgrep output when querying for openvpn server $daemonName";
    is $running, $foundDaemonProccess, "Checking if daemon\'s running output is coherent with pgrep output";

}

1;
