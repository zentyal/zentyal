package EBox::OpenVPN::LogHelper::Test;
use base 'EBox::Test::Class';

use strict;
use warnings;

use EBox::OpenVPN;
use EBox::OpenVPN::LogHelper;

use Test::More;
use Test::Exception;

use lib '../../..';


sub fakeConfig : Test(setup)
{
  my ($self) = @_;

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

		  '/ebox/modules/openvpn/client/gibon/active'    => 1,
		  '/ebox/modules/openvpn/client/gibon/port'   => 1294,
		  '/ebox/modules/openvpn/client/gibon/proto'  => 'udp',

		  '/ebox/modules/openvpn/client/titi/active'    => 0,
		  '/ebox/modules/openvpn/client/titi/port'   => 1394,
		  '/ebox/modules/openvpn/client/titi/proto'  => 'udp',
		      );
  EBox::GConfModule::TestStub::setConfig(@config);
}


sub tearDownConfig: Test(teardown)
{
  EBox::GConfModule::TestStub::setConfig();
}

sub _confDir
{
  return 'testdatas';
}



sub processLineTest : Test(4)
{

  my $openvpn   = EBox::OpenVPN->_create();
  my $logHelper = new EBox::OpenVPN::LogHelper($openvpn);
  my $dbEngine  = new FakeDBEngine;

  my $macacoServer = $openvpn->server('macaco');

  my @cases = (
	       {
		line => 'Tue Aug 21 09:32:09 2007 Diffie-Hellman initialized with 1024 bit key',
		file => $macacoServer->logFile(),
		expected => undef,
	       
	       },

	       {
		line => 'Tue Aug 21 09:23:15 2007 Initialization Sequence Completed',
		file => $macacoServer->logFile(),
		expected => {
			     timestamp => 'Tue Aug 21 09:23:15 2007',
			     daemonName => 'macaco',
			     daemonType => 'server',
			     event      => 'started',
			    },
	       },



	      );

  foreach my $case (@cases) {
    $dbEngine->clearLastInsert();

    my $line = $case->{line};
    my $file = $case->{file};
    my $expected = $case->{expected};

    lives_ok {
      $logHelper->processLine($file, $line, $dbEngine);
    } 'processing line';
    
    is_deeply $dbEngine->lastInsert, $expected, 'checking wether inserted data was the expected';
  }

}








package FakeDBEngine;

sub new 
{
  my $class = shift;

  my $self = { data => undef };
  bless $self, $class;

  return $self;

}

sub insert
{
  my ($self, $table, $data) = @_;
  $self->{data} = $data;
}

sub lastInsert
{
  my ($self) = @_;
  return $self->{data}
}



sub clearLastInsert
{
  my ($self) = @_;
  $self->{data} = undef;
}

1;
