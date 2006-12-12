package  EBox::CGI::OpenVPN::Create::Test;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;
use Test::More;
use Test::Exception;
use EBox::Test::CGI qw(:all);
use EBox::Global;


use lib '../../../..';
use EBox::OpenVPN;
use EBox::CA::TestStub;

sub newCGI 
{
  return new EBox::CGI::OpenVPN::Create();
}


sub testDir
{
    return  '/tmp/ebox.cgi.openvpn.create.test';
}


sub _confDir
{
  my ($self) = @_;

  return testDir() . '/conf'
}

sub fakeCA : Test(startup)
{
  EBox::CA::TestStub::fake();
}

sub muteOutput : Test(startup)
{
  muteHtmlOutput('EBox::CGI::OpenVPN::Create');
}


sub eboxConfSetup : Test(setup)
{
  my ($self) = @_;

  my @config = (
		  '/ebox/modules/openvpn/active'  => 1,
		  '/ebox/modules/openvpn/openvpn_bin'  => '/usr/sbin/openvpn',
		  '/ebox/modules/openvpn/user'  => 'nobody',
		  '/ebox/modules/openvpn/group' => 'nobody',
		  '/ebox/modules/openvpn/conf_dir' => $self->_confDir(),
	       );

  EBox::GConfModule::TestStub::setConfig(@config);
  EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
  EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

     #setup certificates
    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
			{
			 dn => 'CN=monos',
			 isCACert => 1,
			},
			{
			 dn => "CN=serverCertificate",
			},
		       );

    $ca->setInitialState(\@certificates);
}

sub eboxConfTearDown : Test(teardown)
{
  EBox::GConfModule::TestStub::setConfig( () );
}


sub _useAndCreateTest : Test(2)
{
  use_ok 'EBox::CGI::OpenVPN::Create';
  lives_ok { new EBox::CGI::OpenVPN::Create()   } 'Testing creation of the CGI';
}



sub runWithoutParamTest :  Test(1)
{
  my $cgi = newCGI();
  runCgi($cgi, ());
  cgiErrorNotOk($cgi);
}

sub createTest : Test(9)
{
  my @straightCases = (
		       [ name => 'macaco', create => 1, service => 1, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3000, proto => 'tcp', certificate => 'serverCertificate', ],
			 [ name => 'gibon', create => 1, service => 0, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3001, proto => 'tcp', certificate => 'serverCertificate', ],
			 [ name => 'titi',  create => 1, service => 1, subnet => '10.8.0.0', subnetNetmask => '255.255.255.0', port => 3002, proto => 'tcp', certificate => 'serverCertificate', ],

		      );

  foreach my $case (@straightCases) {
    my @params = @{$case};
    my $cgi = newCGI();

    lives_ok { runCgi($cgi, @params) } "Running CGI with params @params";
    cgiErrorNotOk($cgi, 'Checking CGI for error');
    
    my %paramsByName = @params;
    my $nameParam = $paramsByName{'name'};
    


    my $openVPN = EBox::Global->modInstance('openvpn');
    my $server;
    lives_ok { $server =  $openVPN->server($nameParam) } 'Checking that server was correctly created';

  }
}



#package EBox::CGI::OpenVPN::Create;
#sub _print
#{}

1;
