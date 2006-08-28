package DaemonTest;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockObject;

use EBox::Global::TestStub;
use EBox::GConfModule::TestStub;
use EBox::Config::TestStub;

use EBox::Service;
use EBox::DHCP;

my $TEST_IFACE = 'eth1';
my $TEST_ADDRESS = '192.168.32.1';
my $TEST_NETMASK = '255.255.255.0';

sub notice : Test(startup)
{
    diag "This test is designed to be run as root. That is neccesary for try the openvpn daemon execution but it may be a security risk";
    diag "We need a dhcp3 server installed with runsysv support for executing this test";
    diag "We need a network interface for the test. Now is $TEST_IFACE but it can changed giving another value to \$TEST_IFACE variable";
    diag "The given network interface will given a IP address of $TEST_ADDRESS/$TEST_NETMASK; you can modified this altering the variables \$TEST_ADDRESS and \$TEST_NETMASK";
}

sub testDir
{
    return  '/tmp/ebox.dhcp.daemon.test';
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
		  '/ebox/modules/dhcp/active'  => 0,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('dhcp' => 'EBox::DHCP'); 
    EBox::Global::TestStub::setEBoxModule('network' => 'EBox::Network');
    EBox::Config::TestStub::setConfigKeys(tmp => $self->testDir);

  Test::MockObject->fake_module('EBox::DHCP',
				_configureFirewall => sub {},
			       );
}


sub setupFiles : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();
   
    system "/bin/mkdir -p $confDir";
    ($? == 0) or  die "mkdir -p $confDir: $!";

}


sub setupStubDir : Test(setup)
{
    my ($self) = @_;
    my $stubDir  = $self->testDir() . '/stubs';

    system ("/bin/mkdir -p $stubDir/dhcp");
    ($? == 0) or die "Error creating  temp test subdir $stubDir: $!";
    
    system "/bin/cp ../../../stubs/*.mas $stubDir/dhcp";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";

    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir);
}


sub killDaemons : Test(setup)
{
  EBox::Service::manage('dhcpd3', 'stop');
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


sub daemonTest : Test(10)
{
  my $net = EBox::Global->modInstance('network');
  $net->setIfaceStatic($TEST_IFACE, $TEST_ADDRESS, $TEST_NETMASK, 0, 0);

  my $dhcp = EBox::Global->modInstance('dhcp');

  my @serviceSequences = qw(0 0 1 1 0);
  foreach my $service (@serviceSequences) {
    $dhcp->setService($service);
    lives_ok { $dhcp->_regenConfig()  } 'Regenerating configuration for dhcp server';
    sleep 1; # avoid race problems
    my $actualService = EBox::Service::running('dhcpd3') ? 1 : 0;
    is $actualService, $service, 'Checking if service is the expected';

  }

}


1;
