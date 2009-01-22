package EBox::OpenVPN::Client::Test;
# Description:
use strict;
use warnings;

use base qw(EBox::Test::Class);

use EBox::Test;
use EBox::TestStubs;
use EBox::Types::File;
use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::File;
use Test::Differences;

use lib '../../../';
use EBox::OpenVPN;
use EBox::OpenVPN::Client;
use EBox::CA::TestStub;
use EBox::TestStubs qw(fakeEBoxModule);
use EBox::OpenVPN::Client::ValidateCertificate;

use English qw(-no_match_vars);

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

# we dont want to test certificate validation here
sub EBox::OpenVPN::Client::ValidateCertificate::check
{
    return 1 
}




sub mockNetworkModule 
{
  my ($self, $ifaces_r) = @_;
  my @ifaces = defined $ifaces_r ? @{ $ifaces_r } : ('eth1', 'eth2') ;

  EBox::TestStubs::fakeEBoxModule(
                                  name => 'network',
                                  module => 'EBox::Network',
                                  subs => [
                                           ExternalIfaces => sub { return \@ifaces },
                                           InternalIfaces => sub { return [] },
                                          ],
                                 );
}


# XXX replace with #419 when it is done
sub ignoreChownRootCommand : Test(startup)
{
  my $root_r = EBox::Sudo->can('root');

  my $rootIgnoreChown_r = sub {
    my ($cmd) = @_;
    my ($cmdWithoutParams) = split '\s+', $cmd;
    if (($cmdWithoutParams eq 'chown') or ($cmdWithoutParams eq '/bin/chown')) {
      return [];  
    }

    return $root_r->($cmd);
  };


  defined $root_r or die 'Can not get root sub from EBox::Sudo';

  Test::MockObject->fake_module(
                                'EBox::Sudo',
                                root => $rootIgnoreChown_r,
                               )
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
                                                        return $self->_confDir()
                                                    },
                                                   ],
                                          );


    mockNetworkModule();

    EBox::Config::TestStub::setConfigKeys(tmp => '/tmp/');
}




sub clearConfiguration : Test(teardown)
{
    EBox::Module::Service::TestStub::setConfig();


}







sub _newClient
{
    my ($self, %conf) = @_;
    my %defaults = (
                    name               => 'macaco',
                    service            => 0,
                    server                   => 'server.monos.org',
                    serverPortAndProtocol    => '1000/tcp',
                    ripPasswd                => '123456',
                   );

    while (my ($attr, $value) = each %defaults) {
        exists $conf{$attr} and 
            next;
        $conf{$attr} = $value;
    }

    my $name    = delete $conf{name};
    my $service = delete $conf{service};
    my $ifaceNumber =  delete $conf{ifaceNumber};

    my $openvpnMod = $self->{openvpnModInstance};
    my $clients =  $openvpnMod->model('Clients');

    my @ifaceParams; 
    if (defined $ifaceNumber) {
        @ifaceParams = (
                        interfaceNumber => $ifaceNumber,
                        interfaceType   => 'tap',
                       );
    }


    $clients->addRow(
                     name => $name,
                     service =>  0,
                     @ifaceParams,
                    );


    # put mock certificate files
    my $tmpDir = EBox::Config::tmp();
    my $dir = EBox::OpenVPN::Client->privateDirForName($name);
    foreach my $f (qw(caCertificate certificate certificateKey)) {
        system "touch $dir/$f" ;
        ($? == 0) or die "$!";
        system "touch $tmpDir/$f" . "_path";
       ($? == 0) or die "$!";
    }


    my $clientRow     = $clients->findRow(name => $name);
    my $clientConfRow = $clientRow->subModel('configuration')->row();
    while (my ($attr, $value) = each %conf) {
        $clientConfRow->elementByName($attr)->setValue($value);
    }
    $clientConfRow->store();


    
    if ($service) {
        $clientRow->elementByName('service')->setValue(1);
        $clientRow->store();
    }


    my $client = $clients->client($name);
    return $client;
}





# XXX this two very ugly and fragile fudge must be removed when we make the
# parent() method to work with the mocked framework
sub EBox::Types::File::exist
{
    return 1;
}


# XXX this two very ugly and fragile fudge must be removed when we make the
# parent() method to work with the mocked framework
sub EBox::OpenVPN::Client::_filePath
{
    my ($self, $f) = @_;;

    my $confDir = $self->privateDir();
    return "$confDir/$f";

}

sub writeConfFileTest : Test(2)
{
    my ($self) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');

    my $confDir =   $openvpn->confDir();
    my $stubDir  = $self->testDir() . '/stubs';
    foreach my $testSubdir ($confDir, $stubDir, "$stubDir/openvpn") {
        system ("rm -rf $testSubdir");
        ($? == 0) or die "Error removing  temp test subdir $testSubdir: $!";
        system ("mkdir -p $testSubdir");
        ($? == 0) or die "Error creating  temp test subdir $testSubdir: $!";
    }
    
    
    system "cp ../../../../stubs/openvpn-client.conf.mas $stubDir/openvpn";
    ($? ==0 ) or die "Can not copy templates to stub mock dir";
    EBox::Config::TestStub::setConfigKeys('stubs' => $stubDir, tmp => '/tmp/');

  
    my $client = $self->_newClient(
                                   name => 'client1' , 
                                   service => 1,
                                   ifaceNumber => 0,
                                  );
    lives_ok { $client->writeConfFile($confDir)  } 'Calling writeConfFile method in client instance';
    file_exists_ok($client->confFile($confDir), "Checking if the new configuration file was written");
    diag "TODO: try to validate automatically the generated conf file without ressorting a aspect-like thing. (You may validate manually with openvpn --config)";
}

sub ifaceMethodChangedTest : Test(3)
{
  my ($self) = @_;
  my $client = $self->_newClient();

  ok !$client->ifaceMethodChanged('eth0', 'anyPreviousState', 'anyMethod'), "checking wether changes which state is not setted to 'nonset' are considered non-disruptive";

  ok !$client->ifaceMethodChanged('eth0', 'anyPreviousState', 'nonset'), "Checking wether a change to 'non-set is not considered disruptive if there is more than one interface left" ;

  $self->mockNetworkModule(['eth0']);
  ok $client->ifaceMethodChanged('eth0', 'anyPreviousState', 'nonset'), "Checking wether a change to 'non-set is considered disruptive if there is only one interface left ";
}


sub vifaceDeleteTest : Test(2)
{
  my ($self) = @_;
  my $client = $self->_newClient();

  ok !$client->vifaceDelete('wathever', 'eth0'), "Checking wether deleting a viface is not considered disruptive if there are interfaces left";


  $self->mockNetworkModule(['eth0']);
  ok $client->vifaceDelete('wathever', 'eth0'), "Checking wether deleting a viface is considered disruptive if this is the only interface elft";
}


sub freeIfaceAndFreeVifaceTest : Test(4)
{
  my ($self) = @_;

  my $client = $self->_newClient(service => 1);


  $client->freeIface('eth3');
  ok $client->service(), 'Checking wether client is active after deleteing a iface';

  $client->freeViface('eth4', 'eth5');
  ok $client->service(), 'Checking wether client is active after deleteing a viface';

  $self->mockNetworkModule(['eth0']);
  $client->freeIface('eth0');
  ok !$client->service(), 'Checking wether client was disabled after removing the last interface';

  my $client2 = $self->_newClient(name => 'c2', service => 1);
  $client2->freeViface('eth0', 'eth1');
  ok !$client2->service(), 'Checking wether client was disabled after removing the last interface (the last interface happened to be a virtual interface)';
}



sub otherNetworkObserverMethodsTest : Test(2)
{
  my ($self) = @_;
  my $client = $self->_newClient();

  ok !$client->staticIfaceAddressChanged('eth0', '192.168.45.4', '255.255.255.0', '10.0.0.1', '255.0.0.0'), 'Checking wether client notifies that is not disrupted after staticIfaceAddressChanged invokation';

  ok !$client->vifaceAdded('eth0', 'eth0:1', '10.0.0.1', '255.0.0.0'), 'Checking wether client notifies that is not disrupted after staticIfaceAddressChanged invokation';
}

1;
