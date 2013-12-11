# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package DaemonTest;

use base 'EBox::Test::Class';

use Test::More;
use Test::Exception;
use Test::MockObject;

use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Config::TestStub;
use EBox::NetWrappers::TestStub;
use EBox::TestStubs ('fakeModule');

use EBox::Service;

use lib '../../..';
use EBox::DHCP;

my $TEST_IFACE = 'eth1';
my $TEST_ADDRESS = '192.168.32.1';
my $TEST_NETMASK = '255.255.255.0';

sub notice : Test(startup)
{
    diag "This test is designed to be run as root. That is neccesary for try the openvpn daemon execution but it may be a security risk";
    diag "We need a dhcp3 server installed with runsysv support for executing this test";
    diag "We need a network interface for the test. Now is $TEST_IFACE but it can changed giving another value to \$TEST_IFACE variable";
    diag "The given network interface will given a IP address of $TEST_ADDRESS/$TEST_NETMASK; please make sure that the ip and the subnet is available in your system";

    system "ifconfig $TEST_IFACE";
    die "No $TEST_IFACE interface found" if ($? != 0);
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

sub _setupEBoxConf : Test(setup)
{
    my ($self) = @_;
    my $confDir = $self->_confDir();

    my @config = (
		  '/ebox/modules/dhcp/active'  => 0,
		  );

    EBox::Module::Config::TestStub::setConfig(@config);
    EBox::Global::TestStub::setModule('dhcp' => 'EBox::DHCP');
    EBox::Global::TestStub::setModule('network' => 'EBox::Network');
    EBox::Config::TestStub::setConfigKeys(tmp => $self->testDir);

    Test::MockObject->fake_module('EBox::DHCP',
				_configureFirewall => sub {$TEST_IFACE => {  }},
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
    EBox::Module::Config::TestStub::setConfig();
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

sub setupNetwork : Test(setup)
{
  EBox::NetWrappers::TestStub::setFakeIfaces( { $TEST_IFACE => { up => 1, address => $TEST_ADDRESS, netmask => $TEST_NETMASK }  }  );

  EBox::Global::TestStub::setModule('network' => 'EBox::Network');
  my $net = EBox::Global->modInstance('network');
  $net->setIfaceStatic($TEST_IFACE, $TEST_ADDRESS, $TEST_NETMASK, 0, 0);
}

sub daemonTest : Test(10)
{
  diag "Testing dhcp server with simple configuration";
  my $dhcp = EBox::Global->modInstance('dhcp');
  _checkService($dhcp);
}

sub daemonTestWithStaticRoutes : Test(10)
{
  diag "Testing dhcp server with static routes";
  # setup static route provider modules..
  my @macacoStaticRoutes = (
			    '192.168.32.0/24' => { network => '192.168.4.0', netmask => '255.255.255.0', gateway => '192.168.32.4' },
			    '10.0.4.0/8'  => { network => '192.168.4.0', netmask => '255.0.0.0', gateway => '192.168.30.15' },
			   );

  my @gibonStaticRoutes = (
			    '192.168.32.0/24' => { network => '192.168.4.0', netmask => '255.255.255.0', gateway => '192.168.32.5' },
			   );

  fakeModule(name => 'macacoStaticRoutes', isa => ['EBox::DHCP::StaticRouteProvider'], subs => [ staticRoutes => sub { return [@macacoStaticRoutes]  }  ]);
  fakeModule(name => 'gibonStaticRoutes', isa => ['EBox::DHCP::StaticRouteProvider'], subs => [ staticRoutes => sub { return [@gibonStaticRoutes]  }  ]);
  fakeModule(name => 'titiNoStaticRoutes');
  fakeModule(name => 'mandrillNoStaticRoutes');

  # run the service test
  my $dhcp = EBox::Global->modInstance('dhcp');
  _checkService($dhcp);
}

sub _checkService
{
  my ($dhcp) = @_;

  my @serviceSequences = qw(0 0 1 1 0);
  foreach my $service (@serviceSequences) {
    $dhcp->setService($service);
    lives_ok { $dhcp->restartService()  } 'Regenerating configuration for dhcp server';
    sleep 1; # avoid race problems
    my $actualService = EBox::Service::running('dhcpd3') ? 1 : 0;
    is $actualService, $service, 'Checking if service is the expected';

  }
}

1;
