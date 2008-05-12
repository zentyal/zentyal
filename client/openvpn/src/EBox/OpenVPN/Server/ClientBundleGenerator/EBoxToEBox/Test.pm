# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox::Test;
use base 'EBox::Test::Class';

use strict;
use warnings;

use lib '../../../../..';

use Test::More;
use Test::Exception;
use Test::Differences;
use Test::MockObject;

use EBox::Global;
use EBox::OpenVPN;

use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeEBoxModule);


use File::Basename;
use File::Slurp qw(read_file write_file);
use Perl6::Junction qw(all any);

use EBox::NetWrappers::TestStub;
use EBox::CA::TestStub;

use EBox::OpenVPN::Test;

sub testDir
{
  return "/tmp/ebox$$.test";
}


sub createTestDir : Test(setup)
{
  my ($self) = @_;
  my $d = $self->testDir();
  mkdir $d;  
}

sub removeTestDir #: Test(teardown)
{
  my ($self) = @_;
  my $d = $self->testDir();
  system "rm -rf $d";
}


sub fakeTmpDir : Test(setup)
{
  my ($self) = @_;
  EBox::TestStubs::setEBoxConfigKeys(tmp =>  $self->testDir());
}

sub fakeCA : Test(startup)
{
  my ($self) = @_;

  EBox::CA::TestStub::fake();

  my $dir = $self->testDir();
  $self->createTestDir() if not -d $dir;

  diag "DIR $dir";

  my $caPath =  "$dir/caCert.crt";
  my $serverCertPath   = "$dir/serverCert.crt";
  my $clientCertPath = "$dir/clientCert.crt";
  my $clientCertKeyPath = "$dir/clientCert.key";

  EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

  my $ca = EBox::Global->modInstance('ca');
  my @fakeCertificates = (
			  {
			   dn => 'CN=monos',
			   isCACert => 1,
			   path =>$caPath,
			  },
			  {
			   dn => "CN=serverCertificate",
			   path => $serverCertPath,
			   keys => [qw(serverCert.pub serverCert.key)],
			  },
			  {
			   dn => "CN=clientCertificate",
			   path => $clientCertPath,
			   keys => ["clientCert.pub", $clientCertKeyPath],
			  },
			 );
  $ca->setInitialState(\@fakeCertificates);


  write_file($caPath, 'caCertificate');
  write_file($clientCertPath, 'certificate');
  write_file($clientCertKeyPath, 'certificateKey');
}

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
   
    # openvpn module basic configuration
    my @config = (
		  '/ebox/modules/openvpn/userActive'  => 1,
		  '/ebox/modules/openvpn/internalActive'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $self->testDir(),
		  '/ebox/modules/openvpn/interface_count' => 0,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);

    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    EBox::OpenVPN::Test::fakeInterfaces();
    EBox::OpenVPN::Test::fakeFirewall();
    EBox::OpenVPN::Test::fakeNetworkModule();


    my $openvpn = EBox::Global->modInstance('openvpn');

    my $server = $openvpn->newServer(
					 'serverName',
					 service => 1, 
					 subnet => '10.8.0.0', 
					 subnetNetmask => '255.255.255.0', 
					 port => 3000, 
					 proto => 'tcp',  
					 certificate => 'serverCertificate',
				         masquerade => 0,
					);

    $self->{server} = $server;
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}


sub createBundleTest : Test(11)
{
  my ($self) = @_;
  my $server = $self->{server};

  my $cert      = 'clientCertificate';
  my $addresses = [
		   '192.168.9.2',
		  ];

  my $bundle;
  lives_ok {
    
    $bundle = EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox->clientBundle(
       server => $server,
       clientCertificate => $cert,
       addresses         => $addresses,
										    );
  } 'checking bundle creation';


  my %paramsFromBundle;
  lives_ok {
    %paramsFromBundle = EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox->initParamsFromBundle($bundle->{file});
  } 'getting config parameters from bundle';
  
  is $paramsFromBundle{proto}, $server->proto(), 'Checking protocol parameter extracted from bundle';
  is $paramsFromBundle{ripPasswd}, $server->ripPasswd(), 'Checking RIP password parameter extracted from bundle';

  my @expectedServers = map {
    [$_ =>  $server->port() ]
  } @{ $addresses };

  is_deeply \@expectedServers, $paramsFromBundle{servers}, 'Checking server parameters from bundle';

  my @certificateParams = qw(caCertificate certificate certificateKey);
  foreach my $certParam (@certificateParams) {
    my $path = $paramsFromBundle{$certParam};
    ok ( -r $path), 'cjhecking existance of certificate file in the bundle';
    
    is read_file($path), $certParam, 'checking contents of file in the bundle';
  }
}




1;
