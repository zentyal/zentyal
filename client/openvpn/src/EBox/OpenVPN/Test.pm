package EBox::OpenVPN::Test;
use base 'EBox::Test::Class';

# Description:
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Differences;
use Test::MockObject;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeEBoxModule);

use Perl6::Junction qw(all any);

use EBox::NetWrappers::TestStub;
use EBox::CA::TestStub;

use lib '../..';

use EBox::OpenVPN;

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir . '/conf';
}

sub EBox::OpenVPN::confDir
{
    return EBox::OpenVPN::Test->_confDir();
}

sub _moduleInstantiationTest : Test
{
    checkModuleInstantiation('openvpn', 'EBox::OpenVPN');
}

sub _setupDirs : Test(startup)
{
    my ($self) = @_;

    my $testDir = $self->testDir();
    my $confDir = $self->_confDir();

    foreach my $dir ($testDir, $confDir) {
        system "rm -rf $dir";
        ($? == 0) or die "$!";
        system "mkdir -p $dir";
        ($? == 0) or die "$!";
    }

}

sub useGlobalTmpDir : Test(startup)
{
    EBox::TestStubs::setEBoxConfigKeys(tmp => '/tmp/');
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

sub fakeNetworkModule
{
    my ($externalIfaces_r, $internalIfaces_r) = @_;

    my @externalIfaces =
      defined $externalIfaces_r ? @{$externalIfaces_r} :  qw(eth0 eth2);
    my @internalIfaces =
      defined $internalIfaces_r ? @{$internalIfaces_r} : ('eth1', 'eth3');

    my $anyExternalIfaces = any(@externalIfaces);
    my $anyInternalIfaces = any(@internalIfaces);

    my $ifaceExistsSub_r = sub {
        my ($self, $iface) = @_;

        return 1 if grep { $iface eq $_ } @externalIfaces;
        return 1 if grep { $iface eq $_ } @internalIfaces;

        return 0;
    };

    my $ifaceIsExternalSub_r = sub {
        my ($self, $iface) = @_;
        return  ($iface eq $anyExternalIfaces);
    };

    my $ifacesSub_r = sub {
        my ($self) = @_;
        my @ifaces = (@externalIfaces, @internalIfaces);
        return \@ifaces;
    };

    fakeEBoxModule(
        name => 'network',
        package => 'EBox::Network',
        subs => [
            ifaceIsExternal => $ifaceIsExternalSub_r,
            ifaceExists     => $ifaceExistsSub_r,
            ExternalIfaces  => sub { return \@externalIfaces },
            InternalIfaces  => sub { return \@internalIfaces },
            ifaces          => $ifacesSub_r,
            ifaceMethod     => sub { return 'anythingButNonSet' }
            ,# this if for bug #395

        ],
    );
    
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

sub fakeCA : Test(startup)
{
    EBox::CA::TestStub::fake();
}

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    my $confDir = $self->_confDir();
    if (!-d $confDir) {
        system "mkdir -p $confDir" or die "$!";
    }

    EBox::Global::TestStub::setEBoxModule('openvpn' => 'EBox::OpenVPN');
    EBox::Global::TestStub::setEBoxModule('ca' => 'EBox::CA');

    fakeInterfaces();
    fakeFirewall();
    fakeNetworkModule();
}

sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}

sub newAndDeleteClientTest : Test(12)
{

    my ($self) = @_;

    my $openVPN = EBox::OpenVPN->_create();

    my $prefix =          EBox::OpenVPN->reservedPrefix();
    my $reservedClient    =   $prefix. 'test';
    my @clientsNames      = ($reservedClient);
    my @userClientsNames = ();

    my @clientCerts = $self->_clientCertificates();

    my %clientsParams = (

        $reservedClient =>  [
                       proto => 'tcp',
                       @clientCerts,
                       servers           =>
                         [['192.168.55.21' => 1040],['192.168.55.23' => 1041],],
                       service           => 1,
                       internal            => 1,
                       ripPasswd         => 'passwd',
        ],
    );

    foreach my $name (@clientsNames) {

        my @params = @{ $clientsParams{$name} };
        $self->_createClientCertificates();

        my $instance;
        lives_ok { $instance = $openVPN->newClient($reservedClient, @params)  }
        "Testing addition of new client: $name";
        isa_ok $instance, 'EBox::OpenVPN::Client',
          'Checking that newClient has returned a client instance';
        ok $openVPN->clientExists($name);
        dies_ok { $instance  = $openVPN->newClient($reservedClient, @params)  }
        'Checking that the clients cannot be added a second time';
    }

    my @actualClientsNames = $openVPN->clientsNames();
    eq_or_diff [sort @actualClientsNames], [sort @clientsNames],
      "Checking returned test clients names";

    my @actualClientsNamesForUI = $openVPN->userClientsNames();
    eq_or_diff [sort @actualClientsNamesForUI], [sort @userClientsNames],
      "Checking returned test clients names for UI";


    # delete test

    my ($nameToDelete) = @clientsNames;
    _checkDeleteDaemon($openVPN, $nameToDelete, 'client');

}

# sub newClientFromBundleTest #: Test(7)
# {
#     my ($self) =@_;

#     my $bundlePath = 'testdata/bundle-EBoxToEBox.tar.gz';

#     my $name = 'clientFromBundle';

#     my $openVPN = EBox::OpenVPN->_create();

#     lives_ok {
#         $openVPN->newClient($name, bundle => $bundlePath, internal => 0);
#     }
#     'creating client form bundle file';

#     my %expectedAttrs = (
#                          proto => 'tcp',
#                          ripPasswd => 'aaaaa',
#                          servers   =>  [ [ '192.168.45.4' => 10008 ] ],
#     );

#     my $client = $openVPN->client($name);

#     while (my ($attr, $expectedValue) = each %expectedAttrs) {
#         if (ref $expectedValue) {
#             is_deeply $client->$attr(), $expectedValue,
#               "checking server created from bundle for poperty $attr";
#         }else {
#             is $client->$attr(), $expectedValue,
#               "checking server created from bundle for popierty $attr";
#         }

#     }

#     my @certGetters = qw(caCertificate certificate certificateKey);
#     foreach my $certGetter (@certGetters) {
#         my $certPath = $client->$certGetter();
#         diag "path $certPath";
#         my $fileExists =  (-r $certPath);
#         ok $fileExists , 'checking that certificate file $certGetter exists';
#     }

# }

sub _checkDeleteDaemon
{
    my ($openVPN, $name, $type) = @_;

    my $deleteMethod = 'delete' . ucfirst $type;
    my $existsMethod = $type . 'Exists';
    my $listMethod = $type . 'sNames';


    my $daemon = $openVPN->$type($name);
    my $expectedDeletedData = _expectedDeletedDaemonData($daemon);

    

    lives_ok {
        $openVPN->$deleteMethod($name);
    }
    "Testing client removal $name";

    dies_ok  {
        $openVPN->$type($name);
    }
'Testing that can not get the $type object that represents the deleted daemon ';

    dies_ok {
        $openVPN->$deleteMethod($name);
    } 'wether you cannot delete the same daemon twice';



    my @actualDaemonsNames = $openVPN->$listMethod();
    ok $name ne all(@actualDaemonsNames),
"Checking that deleted $type 's name does not appear longer in $type names list";
    ok(not $openVPN->$existsMethod($name)),
      "Checking negative result of $existsMethod";

    _checkDeletedDaemonData($openVPN, $name, $expectedDeletedData);
}

sub _expectedDeletedDaemonData
{
    my ($daemon) = @_;
    my %deletedData;
    $deletedData{name} =  $daemon->name;
    $deletedData{type} =  $daemon->type;


    return \%deletedData;
}

sub _checkDeletedDaemonData
{
    my ($openVPN, $daemonName, $expectedDeleted) = @_;

    my $deletedDaemons = $openVPN->model('DeletedDaemons');
    my ($deletedData) = grep {
        $_->{name} eq $daemonName;
    } @{  $deletedDaemons->daemons() };

    is_deeply $deletedData, $expectedDeleted, 
        'checking wether deleted data is correct';



}

sub _createClientCertificates
{
    my ($self) = @_;

    my %certs = $self->_clientCertificates;

    system 'cp ../OpenVPN/Client/t/testdata/cacert.pem '
      . $certs{caCertificate};
    system 'cp ../OpenVPN/Client/t/testdata/cert.pem ' . $certs{certificate};
    system 'cp ../OpenVPN/Client/t/testdata/pkey.pem ' . $certs{certificateKey};

}

sub _clientCertificates
{
    my ($self) = @_;

    my $dir = $self->testDir;
    return (
            caCertificate =>  "$dir/ca",
            certificate   =>   "$dir/cert",
            certificateKey    => "$dir/key",
    );
}

sub fakeInterfaces
{

    # set fake interfaces
    EBox::NetWrappers::TestStub::fake();
    EBox::NetWrappers::TestStub::setFakeIfaces(
          {
            eth0 =>
              { up => 1, address => { '192.168.0.100' => '255.255.255.0' } },
            ppp0 =>
              { up => 1, address => { '192.168.45.233' => '255.255.255.0' } },
            eth1 =>
              {up  => 1, address => { '192.168.0.233' => '255.255.255.0' }},
          }
    );

    # fake network module..
    my @externalIfaces = qw(eth0 ppp0 eth1);
    my @internalIfaces = ();

    my $anyExternalIfaces = any(@externalIfaces);
    my $anyInternalIfaces = any(@internalIfaces);

    my $ifaceExistsSub_r = sub {
        my ($self, $iface) = @_;
        return ($iface eq $anyInternalIfaces) or ($iface eq $anyExternalIfaces);
    };

    my $ifaceIsExternalSub_r = sub {
        my ($self, $iface) = @_;
        return  ($iface eq $anyExternalIfaces);
    };

    fakeEBoxModule(
                   name => 'network',
                   package => 'EBox::Network',
                   subs => [
                            ifaceIsExternal => $ifaceIsExternalSub_r,
                            ifaceExists     => $ifaceExistsSub_r,
                            ExternalIfaces  => sub { return \@externalIfaces },
                            InternalIfaces  => sub { return \@internalIfaces },
                   ],
    );

}

1;
