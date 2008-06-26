package EBox::OpenVPN::Server::Test;

# Description:
use strict;
use warnings;

use base qw(EBox::Test::Class);

use EBox::Test;
use EBox::TestStubs qw(fakeEBoxModule);

use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::File;
use Test::Differences;
use Perl6::Junction qw(any);

use lib '../../../';
use EBox::OpenVPN::Test;
use EBox::OpenVPN;
use EBox::OpenVPN::Server;
use EBox::CA::TestStub;

use English qw(-no_match_vars);

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}

sub fakeCA : Test(startup)
{
    EBox::CA::TestStub::fake();
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

# XXX replace with #419 when it is done
sub ignoreChownRootCommand : Test(startup)
{
    my $root_r = EBox::Sudo->can('root');

    my $rootIgnoreChown_r = sub {
        my ($cmd) = @_;
        my ($cmdWithoutParams) = split '\s+', $cmd;
        if (   ($cmdWithoutParams eq 'chown')
            or ($cmdWithoutParams eq '/bin/chown'))
        {
            return [];
        }

        return $root_r->($cmd);
    };

    defined $root_r or die 'Can not get root sub from EBox::Sudo';

    Test::MockObject->fake_module(
                                  'EBox::Sudo',root => $rootIgnoreChown_r,
      );
}

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    $self->{openvpnModInstance} = EBox::OpenVPN->_create();

    fakeEBoxModule(
        name => 'openvpn',
        package => 'EBox::OpenVPN',
        subs => [
            confDir => sub {
                return $self->_confDir(
                  );
            },
        ],
    );

    EBox::OpenVPN::Test::fakeNetworkModule();

    fakeFirewall();
}

sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}

sub setUpCertificates : Test(setup)
{
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
                        {
                          dn => 'CN=monos',
                          isCACert => 1,
                        },
                        {
                          dn => 'CN=certificate1',
                          path => '/certificate1.crt',
                          keys => [qw(certificate1.pub certificate1.key)],
                        },
                        {
                          dn    => 'CN=certificate2',
                          path => '/certificate2.crt',
                        },
                        {
                          dn    => 'CN=expired',
                          state => 'E',
                          path => '/certificate2.crt',
                        },
                        {
                          dn    => 'CN=revoked',
                          state => 'R',
                          path => '/certificate2.crt',
                        },
    );
    $ca->setInitialState(\@certificates);
}

sub clearConfigurationAndCA : Test(teardown)
{
    my $ca    = EBox::Global->modInstance('ca');
    $ca->destroyCA();

    EBox::GConfModule::TestStub::setConfig();
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

sub _newServer
{
    my ($self, %conf) = @_;
    my %defaults = (
                    name               => 'macaco',
                    service            => 0,
                    certificate        => 'certificate1',
                    portAndProtocol    => '1000/tcp',
                    vpn                => '192.168.45.0/24',
    );

    while (my ($attr, $value) = each %defaults) {
        exists $conf{$attr}
          and next;
        $conf{$attr} = $value;
    }

    my $name    = delete $conf{name};
    my $service = delete $conf{service};
    my $ifaceNumber =  delete $conf{ifaceNumber};

    my $openvpnMod = $self->{openvpnModInstance};
    my $servers =  $openvpnMod->model('Servers');

    my @ifaceParams;
    if (defined $ifaceNumber) {
        @ifaceParams = (
                        interfaceNumber => $ifaceNumber,
                        interfaceType   => 'tap',
        );
    }

    $servers->addRow(
                     name => $name,
                     service =>  0,
                     @ifaceParams,
    );

    my $serverRow     = $servers->findRow(name => $name);
    my $serverConfRow = $serverRow->subModel('configuration')->row();
    while (my ($attr, $value) = each %conf) {
        $serverConfRow->elementByName($attr)->setValue($value);
    }
    $serverConfRow->store();

    if ($service) {
        $serverRow->elementByName('service')->setValue(1);
        $serverRow->store();
    }

    my $server = $servers->server($name);
    return $server;
}

sub keyTest : Test(2)
{
    my ($self) = @_;

    my $server = $self->_newServer( certificate => 'certificate1' );
    my $privateKey;
    lives_ok {
        $privateKey = $server->key(
          );
    }
    'getting private key';

    my $expecctedPrivateKey = 'certificate1.key';
    is $privateKey, $expecctedPrivateKey, 'Checking returned private key path';
}

sub writeConfFileTest : Test(2)
{
    my ($self) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');

    my $confDir =   $openvpn->confDir();
    my $stubDir  = $self->testDir() . '/stubs';

    foreach my $testSubdir ($confDir, $stubDir, "$stubDir/openvpn") {
        system("rm -rf $testSubdir");
        ($? == 0) or die "Error removing  temp test subdir $testSubdir: $!";
        system("mkdir -p $testSubdir");
        ($? == 0) or die "Error creating  temp test subdir $testSubdir: $!";
    }

    system "cp ../../../../stubs/openvpn.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";
    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir, tmp => '/tmp');

    my $server = $self->_newServer( service => 1, ifaceNumber => 0 );

    lives_ok { $server->writeConfFile($confDir)  }
    'Calling writeConfFile method in server instance';
    file_exists_ok("$confDir/macaco.conf",
                   "Checking if the new configuration file was written");
    diag
"TODO: try to validate automatically the generated conf file without ressorting a aspect-like thing. (You may validate manually with openvpn --config)";
}

sub certificateRevokedTest : Test(4)
{
    my ($self) = @_;

    my $server = $self->_newServer();
    my $serverCertificate = $server->certificate();
    my $otherCertificate  = 'no-' . $serverCertificate;

    my @trueCases =
      ([$otherCertificate, 1],[$serverCertificate, 1],[$serverCertificate, 0],);

    my @falseCases = ([$otherCertificate, 0],);

    foreach my $case_r (@trueCases) {
        ok $server->certificateRevoked(@{$case_r}),
          'Checking wether certificateRevoked returns true';
    }
    foreach my $case_r (@falseCases) {
        ok !$server->certificateRevoked(@{$case_r}),
          'Checking wether certificateRevoked returs false';
    }
}

sub certificateExpiredTest : Test(8)
{
    my ($self) = @_;

    my $server = $self->_newServer(service => 1);

    my $serverCertificate = $server->certificate();
    my $otherCertificate  = 'no-' . $serverCertificate;

    my @innocuousCases = ([$otherCertificate, 0],);

    my @invalidateCertificateCases =
      ([$otherCertificate, 1],[$serverCertificate, 1],[$serverCertificate, 0],);

    foreach my $case_r (@innocuousCases) {
        lives_ok { $server->certificateExpired( @{$case_r} ) }
        'Notifying server of innocuous certificate expiration';

        ok $server->service(),
          'Checking wether service status of the server was left untouched';
    }

    foreach my $case_r (@invalidateCertificateCases) {
        lives_ok { $server->certificateExpired( @{$case_r} ) }
        'Notifying server of  certificate expiration';

        ok !$server->service(),
'Checking wether the server was disabled after certification expiration';

        # restoring server state
        $self->clearConfigurationAndCA();
        $self->setUpConfiguration();
        $self->setUpCertificates();
        $server = $self->_newServer(service => 1);
    }
}

sub freeCertificateTest : Test(5)
{
    my ($self) = @_;

    my $server = $self->_newServer(service => 1);

    my $serverCertificate = $server->certificate();
    my $otherCertificate  = 'no-' . $serverCertificate;

    lives_ok {  $server->freeCertificate($otherCertificate) }
    'Forcing server to free a certificate which does not uses';
    is $server->certificate(), $serverCertificate,
      'Checking wether server certificate was left unchanged';
    ok $server->service(),
      'Checking wether service status of the server was left untouched';

    lives_ok { $server->freeCertificate($serverCertificate) }
    'Forcing serve to release his certificate';
    ok !$server->service(), 'Checking wether the server was disabled';

}

sub _setLocal
{
    my ($server, $iface) = @_;
    if (not $iface) {
        $iface = '_ALL';
    }

    return __PACKAGE__->_newServer(local => $iface);

    my $name = $server->name();

    my $op = EBox::Global->getInstance('openvpn');
    my $ss = $op->model('Servers');

    $server = $ss->server($name);
    my $serverRow = $server->{row};
    my $confRow   = $serverRow->subModel('configuration')->row;
    $confRow->elementByName('local')->setValue($iface);
    $confRow->store();

}

sub ifaceMethodChangedTest : Test(6)
{
    my ($self) = @_;

    my $serverOnEth0 = $self->_newServer(
                                         name => 'onEth0',
                                         local => 'eth0',
                                         portAndProtocol => '666/tcp',
    );
    my $serverOnAll  = $self->_newServer(
                                         name => 'onAll',
                                         local => '_ALL',
                                         portAndProtocol => '777/tcp',
    );

    ok !$serverOnEth0->ifaceMethodChanged('eth0', 'whatever', 'whateverMethod'),
"Checking wether changing the iface method to a non-'nonset' method is not considered disruptive even where done in the local inerface";

    ok !$serverOnAll->ifaceMethodChanged('eth0', 'whatever', 'nonset'),
"Checking wether changing the iface method to 'nonset' is not considered disruptive where are ifaces left and the interface is not the local interface";

    ok !$serverOnEth0->ifaceMethodChanged('eth0', 'whatever', 'nonset'),
"Checking wether changing the iface method to 'nonset' is considered disruptive if the interface is the local interface";

    EBox::OpenVPN::Test::fakeNetworkModule(['eth0'], []);
    ok !$serverOnAll->ifaceMethodChanged('eth0', 'whatever', 'nonset'),
"Checking wether changing the iface method to 'nonset' is  considered disruptive where are only one interface left";

    ok !$serverOnEth0->ifaceMethodChanged('eth0', 'whatever', 'nonset'),
"Checking wether changing the iface method to 'nonset' is  considered disruptive where are only one interface lef0 and adittionally the change is in the local interface";
    ok !$serverOnEth0->ifaceMethodChanged('eth0', 'whatever', 'whateverMethod'),
"Checking wether changing the iface method to a non-'nonset' method is not considered disruptive even where done in the local inerface and with only one interface left";
}

sub vifaceDeleteTest : Test(4)
{
    my ($self) = @_;

    my $serverOnEth2 = $self->_newServer(
                                         name => 'onEth2',
                                         local => 'eth2',
                                         portAndProtocol => '666/tcp',
    );
    my $serverOnAll  = $self->_newServer(
                                         name => 'onAll',
                                         local => '_ALL',
                                         portAndProtocol => '777/tcp',
    );

    ok !$serverOnAll->vifaceDelete('eth0', 'eth2'),
'Checking wether deleting a virtual interface is not reported as disruptive if the interface is not the local interface and there are interfaces left';

    ok $serverOnEth2->vifaceDelete('eth0', 'eth2'),
'Checking wether deleting a virtual interface is reported as disruptive when the interface is the local interface';

    EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

    ok $serverOnAll->vifaceDelete('eth0', 'eth2'),
'Checking wether deleting a virtual interface is reported as disruptive when the interface is the only interfaces left';

    ok $serverOnEth2->vifaceDelete('eth0', 'eth2'),
'Checking wether deleting a virtual interface is reported as disruptive when the interface is the local interface and there is no interfaces left';
}

sub freeIfaceTest : Test(4)
{
    my ($self) = @_;

    my $serverOnEth0 = $self->_newServer(
                                         name => 'onEth0',
                                         service => 1,
                                         local => 'eth0',
                                         portAndProtocol => '666/tcp',
    );
    my $serverOnEth2 = $self->_newServer(
                                         name => 'onEth2',
                                         service => 1,
                                         local => 'eth2',
                                         portAndProtocol => '888/tcp',
    );
    my $serverOnAll  = $self->_newServer(
                                         name => 'onAll',
                                         service => 1,
                                         local => '_ALL',
                                         portAndProtocol => '777/tcp',
    );

    ok $serverOnAll->service(),
'Checking wether freeing a interface which is not the local interface in a system which has more interfaces available does not deactivate the server';

    $serverOnEth0->freeIface('eth0');
    ok !$serverOnEth0->service(),
'Checking wether freeing a interface which is the local interface in a system which has more interfaces available  deactivates the server';

    EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

    $serverOnAll->freeIface('eth2');
    ok !$serverOnAll->service(),
'Checking wether freeing a interface which is not the local interface in a system which has only this  interface available  deactivates the server';

    $serverOnEth2->freeIface('eth2');
    ok !$serverOnEth2->service(),
'Checking wether freeing a interface which is the local interface in a system which has only this  interface available  deactivates the server';
}

sub freeVifaceTest : Test(4)
{
    my ($self) = @_;

    my $serverOnEth0 = $self->_newServer(
                                         name => 'onEth0',
                                         service => 1,
                                         local => 'eth0',
                                         portAndProtocol => '666/tcp',
    );
    my $serverOnEth2 = $self->_newServer(
                                         name => 'onEth2',
                                         service => 1,
                                         local => 'eth2',
                                         portAndProtocol => '888/tcp',
    );
    my $serverOnAll  = $self->_newServer(
                                         name => 'onAll',
                                         service => 1,
                                         local => '_ALL',
                                         portAndProtocol => '777/tcp',
    );

    $serverOnAll->freeViface('eth0', 'eth8');
    ok $serverOnAll->service(),
'Checking wether freeing a virtual interface which is not the local virtual interface in a system which has more virtual interfaces available does not deactivate the server';

    $serverOnEth0->freeViface('eth8', 'eth0');
    ok !$serverOnEth0->service(),
'Checking wether freeing a virtual interface which is the local virtual interface in a system which has more virtual interfaces available  deactivates the server';

    EBox::OpenVPN::Test::fakeNetworkModule(['eth2'], []);

    $serverOnAll->freeViface('eth0', 'eth2');
    ok !$serverOnAll->service(),
'Checking wether freeing a virtual interface which is not the local virtual interface in a system which has only this  virtual interface available  deactivates the server';

    $serverOnEth2->freeViface('eth0', 'eth2');
    ok !$serverOnEth2->service(),
'Checking wether freeing a virtual interface which is the local virtual interface in a system which has only this  virtual interface available  deactivates the server';
}

sub otherNetworkObserverMethodsTest : Test(2)
{
    my ($self) = @_;
    my $server = $self->_newServer();

    ok !$server->staticIfaceAddressChanged(
                'eth0', '192.168.45.4', '255.255.255.0', '10.0.0.1', '255.0.0.0'
      ),
'Checking wether server notifies that is not disrupted after staticIfaceAddressChanged invokation';

    ok !$server->vifaceAdded('eth0', 'eth0:1', '10.0.0.1', '255.0.0.0'),
'Checking wether server notifies that is not disrupted after staticIfaceAddressChanged invokation';
}

sub usesPortTest :  Test(11)
{
    my ($self) = @_;

    my $port     =  1194;
    my $distinctPort =  30000;
    my $proto = 'tcp';
    my $distinctProto = 'udp';

    my $oneIface  = 'eth0';
    my $noServerIface = 'wlan0';

    my $server = $self->_newServer(
                                   name            => 'macaco',
                                   portAndProtocol => "$port/$proto",
    );

    ok $server->usesPort($proto, $port, undef),
      'same port, same protocol, all ifaces';
    ok(not $server->usesPort($proto, $distinctPort, undef)),
      'same proto,distinct port, all ifaces';
    ok(not $server->usesPort($distinctProto, $port, undef)),
      'distinct proto, same port, all ifaces';
    ok(not $server->usesPort($distinctProto, $distinctPort, undef)),
      'distinct proto and port, all ifaces';
    ok $server->usesPort($proto, $port, $noServerIface),
      'same port, same protocol, specific iface';

    my $port2 = 1195;
    my $serverOnEth0 = $self->_newServer(
                                         name            => 'macaco2',
                                         portAndProtocol => "$port2/$proto",
                                         local => $oneIface,
    );

    ok $serverOnEth0->usesPort($proto, $port2, undef),
      'same port, same protocol, all ifaces';
    ok $serverOnEth0->usesPort($proto, $port2, $oneIface),
      'same port, same protocol, the iface upon server listens';
    ok(not $serverOnEth0->usesPort($proto, $distinctPort, undef)),
      'same proto,distinct port, all ifaces';
    ok(not $serverOnEth0->usesPort($distinctProto, $port2, undef)),
      'distinct proto, same port, all ifaces';
    ok(not $serverOnEth0->usesPort($distinctProto, $distinctPort, undef)),
      'distinct proto and port, all ifaces';
    ok(not $serverOnEth0->usesPort($proto, $port2, $noServerIface)),
      'same port, same protocol, a iface upon server do not listens';
}

1;

__DATA__

#ddeprecated test, should move it to the Servers::Test

sub setServiceTest : Test(56)
{
  my ($self) = @_;
  my $server = $self->_newServer();
  $server->setService(0);

  my @serviceStates = ('0', '1', '1', '0');
  
  diag 'Server in correct state';
  foreach my $newService (@serviceStates) {
    lives_ok { $server->setService($newService) } "Setting server service to $newService";
    is $server->service() ? 1 : 0, $newService, 'Checking wether service was correctly setted';
  }

  diag 'Setting local interface to listen on to a inexistent interface';
  $server->setConfString('local', 'fw5');
  $self->_checkSetServiceWithBadStatus($server, 'using a inexistent interface as local interface to listen on');

  diag 'Setting local interface to listen on to a internal interface';
  $server->setConfString('local', 'eth1');
  $self->_checkSetServiceWithBadStatus($server, 'using a internal interface as local interface to listen on');

  diag 'Setting server to listen in all interfaces but with no interfaces left';
  $server->unsetConf('local');
  EBox::OpenVPN::Test::fakeNetworkModule([], []);
  $self->_checkSetServiceWithBadStatus($server, 'no networks interfaces available');
  EBox::OpenVPN::Test::fakeNetworkModule();

  # certificates bad states
  my $ca    = EBox::Global->modInstance('ca');
  my @certificates = (
		      {
		       dn    => 'CN=expired',
		       state => 'E',
		       path => '/certificate2.crt',
		      },
		      {
		       dn    => 'CN=revoked',
		       state => 'R',
		       path => '/certificate2.crt',
		      },
		     );
  $ca->setInitialState(\@certificates);
  

  diag 'Setting server to use a inexistent certificate';
  $server->setConfString('inexistent');
  $self->_checkSetServiceWithBadStatus($server, 'using a inexistent certificate');

  diag 'Setting server to use a expired certificate';
  $server->setConfString('expired');
  $self->_checkSetServiceWithBadStatus($server, 'using a expired certificate');

  diag 'Setting server to use a revoked certificate';
  $server->setConfString('revoked');
  $self->_checkSetServiceWithBadStatus($server, 'using a revoked certificate');
}



sub _checkSetServiceWithBadStatus
{
  my ($self, $server, $badState) = @_;

  my @serviceStates = ('0', '1', '1', '0');
  foreach my $newService (@serviceStates) {
    if ($newService) {
      dies_ok { $server->setService($newService) } 'Changing wether activating service with bad state: $badState';
      ok !$server->service, 'Checking wether the client continues inactive';
    }
    else {
      lives_ok { $server->setService($newService) } 'Changing service status to inactive';
      is $server->service() ? 1 : 0, $newService, 'Checking wether the service change was done';
    }
  }
}



1;
