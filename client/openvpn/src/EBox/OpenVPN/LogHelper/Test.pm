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

		  '/ebox/modules/openvpn/server/baboon/active'    => 1,
		  '/ebox/modules/openvpn/server/baboon/port'    => 1200,
		  '/ebox/modules/openvpn/server/baboon/proto'   => 'tcp',
		  '/ebox/modules/openvpn/server/baboon/local'   => 'ppp0',

		  '/ebox/modules/openvpn/client/gibon/active'    => 1,
		  '/ebox/modules/openvpn/client/gibon/port'   => 1294,
		  '/ebox/modules/openvpn/client/gibon/proto'  => 'udp',

		  '/ebox/modules/openvpn/client/titi/active'    => 0,
		  '/ebox/modules/openvpn/client/titi/port'   => 1394,
		  '/ebox/modules/openvpn/client/titi/proto'  => 'udp',
		      );
  EBox::Module::Service::TestStub::setConfig(@config);
}

# XXX this  must be deleted if #848 is fixed 
sub fakePopulateConfFiles : Test(startup)
{
  Test::MockObject->fake_module('EBox::OpenVPN::LogHelper',
				_populateLogFiles => sub {
				  my ($self) = @_;
				   $self->{logFiles} = $self->_logFilesFromDaemons;
				},
			       );

}


sub tearDownConfig: Test(teardown)
{
  EBox::Module::Service::TestStub::setConfig();
}

sub _confDir
{
  return 'testdatas';
}



sub processLineTest : Test(24)
{

  my $openvpn   = EBox::OpenVPN->_create();
  my $logHelper = new EBox::OpenVPN::LogHelper($openvpn);
  my $dbEngine  = new FakeDBEngine;

  my $macacoServer = $openvpn->server('macaco');
  my $baboonServer = $openvpn->server('baboon');
  my $gibonClient  = $openvpn->client('gibon');

  # 2 tests for each case
  my @cases = (
	       {
		line => 'Tue Aug 21 09:32:09 2007 Diffie-Hellman initialized with 1024 bit key',
		file => $macacoServer->logFile(),
		expected => undef,
	       
	       },

	       # server initialized
	       {
		line => 'Tue Aug 21 09:23:15 2007 Initialization Sequence Completed',
		file => $macacoServer->logFile(),
		expected => {
			     timestamp => 'Tue Aug 21 09:23:15 2007',
			     daemon_name => 'macaco',
			     daemon_type => 'server',
			     event      => 'initialized',
			    },
	       },

	       # client initialized
	       {
		line => 'Mon Aug 27 06:51:48 2007 Initialization Sequence Completed',
		file => $gibonClient->logFile(),
		expected => {
			     timestamp => 'Mon Aug 27 06:51:48 2007',
			     daemon_name => 'gibon',
			     daemon_type => 'client',
			     event      => 'initialized',
			    },
	       },

	       # verificationOk events
	       {
		line => 'Tue Aug 21 08:51:45 2007 192.168.45.184:54817 VERIFY OK: depth=1, /C=ES/ST=Nation/L=Nowhere/O=monos/CN=Certification_Authority_Certificate',
		file => $baboonServer->logFile(),
		expected => undef,
	       },
	       {
		line => 'Tue Aug 21 08:51:45 2007 192.168.45.184:54817 VERIFY OK: depth=0, /C=ES/ST=Nation/L=Nowhere/O=monos/CN=mandril',
		file => $baboonServer->logFile(),
		expected => undef,
	       },

	       
	       # verification error: unknown ca
	       {
		line => 'Tue Aug 21 11:52:03 2007 192.168.45.184:60488 VERIFY ERROR: depth=0, error=unable to get local issuer certificate: /C=ES/ST=Nation/L=Nowhere/O=pajaros/CN=golondrina',
		file => $macacoServer->logFile(),
		expected => {
			     event      => 'verificationIssuerError',
			     timestamp => 'Tue Aug 21 11:52:03 2007',

			     daemon_name => 'macaco',
			     daemon_type => 'server',

			     from_ip => '192.168.45.184',
			     from_cert => '/C=ES/ST=Nation/L=Nowhere/O=pajaros/CN=golondrina',
			    },
	       },
	       # verification error: incorrect common name
	       {
		line => 'Tue Aug 21 11:47:58 2007 192.168.45.184:52283 VERIFY X509NAME ERROR: /C=ES/ST=Nation/L=Nowhere/O=monos/CN=mandrill, must be gibbon',
		file => $baboonServer->logFile(),
		expected => {
			     event      => 'verificationNameError',
			     timestamp => 'Tue Aug 21 11:47:58 2007',

			     daemon_name => 'baboon',
			     daemon_type => 'server',

			     from_ip => '192.168.45.184',
			     from_cert => '/C=ES/ST=Nation/L=Nowhere/O=monos/CN=mandrill',
			    },
	       },
	       # verification error: forged error to check non-defined error
	       # behaviour 
	       {
		line => 'Tue Aug 21 11:47:58 2007 192.168.45.184:52283 VERIFY UNKNOWN ERROR: the certificate was /C=ES/ST=Nation/L=Nowhere/O=monos/CN=mandrill, this a forged error to test default behaviour',
		file => $baboonServer->logFile(),
		expected => {
			     event      => 'verificationError',
			     timestamp => 'Tue Aug 21 11:47:58 2007',

			     daemon_name => 'baboon',
			     daemon_type => 'server',

			     from_ip => '192.168.45.184',
			     from_cert => '/C=ES/ST=Nation/L=Nowhere/O=monos/CN=mandrill',
			    },
	       },

	       # client connection initialized
	       {
		line => 'Tue Aug 21 08:51:46 2007 192.168.45.184:54817 [mandrill] Peer Connection Initiated with 192.168.45.184:54817',
		file => $macacoServer->logFile(),
		expected => {
			     event      => 'connectionInitiated',
			     timestamp => 'Tue Aug 21 08:51:46 2007',

			     daemon_name => 'macaco',
			     daemon_type => 'server',

			     from_ip => '192.168.45.184',
			     from_cert => 'mandrill',
			    },		
	       },

	       #  connection to server initialized
	       {
		line => 'Mon Aug 27 06:51:47 2007 [server] Peer Connection Initiated with 192.168.45.126:10000',
		file => $gibonClient->logFile(),
		expected => {
			     event      => 'serverConnectionInitiated',
			     timestamp => 'Mon Aug 27 06:51:47 2007',

			     daemon_name => 'gibon',
			     daemon_type => 'client',

			     from_ip => '192.168.45.126',
			     from_cert => 'server',
			    },		
	       },

	       # client connection terminated
	       {
		line => 'Tue Aug 21 08:51:49 2007 mandrill/192.168.45.184:54817 Connection reset, restarting [0]',
		file => $macacoServer->logFile(),
		expected => {
			     event      => 'connectionReset',
			     timestamp => 'Tue Aug 21 08:51:49 2007',

			     daemon_name => 'macaco',
			     daemon_type => 'server',

			     from_ip => '192.168.45.184',
			     from_cert => 'mandrill',
			    },		
	       },

	       # server connection terminated
	       {
		line => 'Mon Aug 27 06:52:25 2007 Connection reset, restarting [0]',
		file => $gibonClient->logFile(),
		expected => {
			     event      => 'connectionResetByServer',
			     timestamp => 'Mon Aug 27 06:52:25 2007',

			     daemon_name => 'gibon',
			     daemon_type => 'client',
			    },		
	       },


	      );

  foreach my $case (@cases) {
    $dbEngine->clearLastInsert();

    my $line = $case->{line};
    my $file = $case->{file};


    my $expected = $case->{expected};

    # normalize expected missing fields
    if (defined $expected) {
      foreach my $field (qw(timestamp daemon_name daemon_type from_ip from_cert)) {
	exists $expected->{$field} or
	  $expected->{$field} = undef;
      }
      
    }

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
