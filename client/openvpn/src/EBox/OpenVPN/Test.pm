package EBox::OpenVPN::Test;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Differences;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use Perl6::Junction qw(all);

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

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
   
    my @config = (
		  '/ebox/modules/openvpn/active'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $self->_confDir(),
		  );

    EBox::GConfModule::Mock::setConfig(@config);
    EBox::Global::Mock::setEBoxModule('openvpn' => 'EBox::OpenVPN');

}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::Mock::setConfig();
}


sub newAndRemoveServerTest : Test(24)
{
    my $openVPN = EBox::OpenVPN->_create();

    my @serversNames = qw(server1 sales staff_vpn );
    my %serversParams = (
			 server1 => [subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3000, proto => 'tcp', caCertificate => '/etc/cert/ca.cert', serverCertificate => '/etc/cert/server.cert', serverKey => '/etc/cert/server.key', type => 'one2many'],
			 sales => [subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3001, proto => 'tcp', caCertificate => '/etc/cert/ca.cert', serverCertificate => '/etc/cert/server.cert', serverKey => '/etc/cert/server.key', type => 'one2many'],
			 staff_vpn => [subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3002, proto => 'tcp', caCertificate => '/etc/cert/ca.cert', serverCertificate => '/etc/cert/server.cert', serverKey => '/etc/cert/server.key', type => 'one2many'],

			 );

    dies_ok { $openVPN->removeServer($serversNames[0]) } "Checking that removal of server when the server list is empty raises error";
    dies_ok {  $openVPN->newServer('incorrect-dot', $serversParams{server1})  } 'Testing addition of incorrect named server';

    foreach my $name (@serversNames) {
	my $instance;
	my @params = @{ $serversParams{$name} };
	lives_ok { $instance = $openVPN->newServer($name, @params)  } 'Testing addition of new server';
	isa_ok $instance, 'EBox::OpenVPN::Server', 'Checking that newServer has returned a server instance';
	dies_ok { $instance  = $openVPN->newServer($name, @params)  } 'Checking that the servers cannot be added a second time';
    }

    my @actualServersNames = $openVPN->serversNames();
    eq_or_diff [sort @actualServersNames], [sort @serversNames], "Checking returned test names";

    # removal cases..
 
	
    foreach my $name (@serversNames) {
	my $instance;
	lives_ok { $instance = $openVPN->removeServer($name)  } 'Testing server removal';
	dies_ok  { $openVPN->server($name) } 'Testing that can not get the server object that represents the deleted server ';

	my @actualServersNames = $openVPN->serversNames();
	ok $name ne all(@actualServersNames), "Checking that deleted servers name does not appear longer in serves names list";
    
	dies_ok { $instance = $openVPN->removeServer($name)  } 'Testing that a deleted server can not be deleted agian';
    }
}

1;
