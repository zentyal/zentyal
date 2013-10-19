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

package EBox::OpenVPN::Model::ServerConfiguration::Test;

use base 'EBox::Test::Class';

use EBox::Test;
use EBox::TestStubs qw(fakeModule);

use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::File;
use Test::Differences;
use Perl6::Junction qw(any);
use TryCatch;

use lib '../../../..';
use  EBox::OpenVPN::Model::ServerConfiguration;
use EBox::OpenVPN::Test;
use EBox::OpenVPN;
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
  fakeModule(
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

sub setupCertificates : Test(setup)
{
    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
                        {
                         dn => 'CN=monos',
                         isCACert => 1,
                        },
                        {
                         dn => 'CN=certificate1',
                         path => '/certificate1.crt',
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

sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    $self->{openvpnModInstance} = EBox::OpenVPN->_create();

    fakeModule(
                   name => 'openvpn',
                   package => 'EBox::OpenVPN',
                   subs => [
                            confDir => sub {
                                return $self->_confDir()
                            },
                           ],
                  );
    EBox::Global::TestStub::setModule('ca' => 'EBox::CA');

    EBox::OpenVPN::Test::fakeNetworkModule();

    fakeFirewall();
}

sub clearConfiguration : Test(teardown)
{
    EBox::Module::Service::TestStub::setConfig();
}

sub clearCertificates : Test(teardown)
{
    my $ca    = EBox::Global->modInstance('ca');
    $ca->destroyCA();
}

sub _confDir
{
    my ($self) = @_;
    return $self->testDir() . "/config";
}

sub _newServerConfiguration
{
    my ($self) = @_;

    return EBox::OpenVPN::Model::ServerConfiguration->new(
                      confmodule => $self->{openvpnModInstance},
                      directory   => 'ServerConfiguration'
                                                         );

}

sub _serverConfigurationValues
{
    my ($self) = @_;
    return {
            portAndProtocol => '1000/tcp',
            certificate     => 'certificate1',
           }

}

# XXX this must be tested at type level!
sub certificateTest : Test(1)
{
  my ($self) = @_;

    my $ca    = EBox::Global->modInstance('ca');
    my @certificates = (
                        {
                         dn => 'CN=monos',
                         isCACert => 1,
                        },
                        {
                         dn => 'CN=certificate1',
                         path => '/certificate1.crt',
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

  my $serverConfiguration = $self->_newServerConfiguration;

  my @expectedOptionsValues = sort qw(certificate1 certificate2);

  my $row = $serverConfiguration->row();
  my $certificate = $row->elementByName('certificate');
  my @optionsValues =  sort map {
      $_->{value}
  } @{ $certificate->options() };

  is_deeply \@optionsValues, \@expectedOptionsValues,
            'Checking values of the certificate control';

}

# XXX this must be tested at type level!
sub tlsRemoteTest : Test(1)
{
  my ($self) = @_;

    my $serverConfiguration   = $self->_newServerConfiguration;
    my $correctCertificates   = ['certificate1', 'certificate2'];
    my $incorrectCertificates = ['inexistentCertificate', 'expired', 'revoked'];

  my @expectedOptionsValues = sort qw(certificate1 certificate2 0);

  my $row = $serverConfiguration->row();
  my $tls = $row->elementByName('tlsRemote');
  my @optionsValues =  sort map {
      $_->{value}
  } @{ $tls->options() };

  is_deeply \@optionsValues, \@expectedOptionsValues,
            'Checking values of the TlsRemote control';
}

sub pullRoutesAndRipPasswdTest : Test(6)
{
  my ($self) = @_;

  my $serverConfiguration = $self->_newServerConfiguration();

  my @correctCases = (
                      [undef, '6charPass'],
                      [0, undef],
                      [0, '6charPass'],
                      [1, '6charPass'],
                     );

  foreach my $case (@correctCases) {
      my ($pull, $passwd) = @{ $case };
      my %values = %{ $self->_serverConfigurationValues  };
      $values{pullRoutes} = $pull if defined $pull;
      $values{ripPasswd} = $passwd if defined $passwd;

      setOk(
            dataTable => $serverConfiguration,
            values => \%values,
            name =>
            "Checking correct combination of pullRoutes and ripPasswd: ($pull, $passwd)"
           )

  }

  my %values = $self->_serverConfigurationValues();
  $values{pullRoutes} = 1;

  setNotOk(
           dataTable => $serverConfiguration,
           values    => \%values,
           name      => 'Trying to set pullRoutes witohut password must fail'
          );

  my $row = $serverConfiguration->row();
  $row->elementByName('pullRoutes')->setValue(1);
  $row->elementByName('ripPasswd')->setValue('6charPass');
  $row->store();

  delete $values{ripPasswd};
  setNotOk(
           dataTable => $serverConfiguration,
           values    => \%values,
           name      => 'Trying to usnet password when pullRoutes is active must fail'
          );

}

sub ifaceAndMasqueradeTest : Test(6)
{
    my ($self) = @_;

    my $serverConfiguration = $self->_newServerConfiguration();

    my @extIfaces = qw(eth0 eth1);
    my @intIfaces = qw(eth2 eth3);
    EBox::OpenVPN::Test::fakeNetworkModule(\@extIfaces, \@intIfaces);

    my @cases = (
                 {
                  name  =>  'Setting masquerade off and listening on all interfaces',
                  values => {
                             local => '_ALL',
                             masquerade => 0,
                            },
                 },
                 {
                  name  =>  'Setting masquerade on and listening on all interfaces',
                  values => {
                             local => '_ALL',
                             masquerade => 1,
                            },
                 },

                 {
                  name  =>  'Setting masquerade off and listening on external interface',
                  values => {
                             local => $extIfaces[0],
                             masquerade => 0,
                            },
                 },
                 {
                  name  =>  'Setting masquerade on and listening on external interface',
                  values => {
                             local => $extIfaces[0],
                             masquerade => 1,
                            },
                 },

                 {
                  name  =>  'Setting masquerade on and listening on internal interface',
                  values => {
                             local => $intIfaces[0],
                             masquerade => 1,
                            },
                 },
                 {
                  name  =>  'Setting masquerade off and listening on internal interface must fail',
                  values => {
                             local => $intIfaces[0],
                             masquerade => 0,
                            },
                  deviant => 1,
                 },
                );

    foreach my $case (@cases) {
        my $name = $case->{name};
        my $deviant = $case->{deviant};

        my %values = %{ $self->_serverConfigurationValues };
        while (my($at, $vl) = each %{ $case->{values} }) {
            $values{$at} = $vl;
        }

        my @params = (
                      dataTable => $serverConfiguration,
                      values => \%values,
                      name => $name
                     );

        if (not $deviant) {
            setOk(@params);
        }
        else {
            setNotOk(@params);
        }

    }

}

sub setOk
{
    _setTest(1, @_);
}

sub setNotOk
{
    _setTest(0, @_);
}

sub _setTest
{
    my ($successExpected, %params) = @_;
    my $dataTable = $params{dataTable};
    my %values        = %{ $params{values} };

    my $name      = $params{name};
    defined $name or
        $name = '';

    my $error = 0;

    my $row;

    $row = $dataTable->row();

    try {
        while (my ($attr, $value) = each %values) {
            my $element = $row->elementByName($attr);
            $element->setValue($value);
        }

        $row->store();

        if ($successExpected) {
            pass($name);
        }
        else {
            fail($name);
        }
    } catch {
        if (not $successExpected) {
            pass($name);
        }
        else {
            fail($name);
        }
    }
}

1;
__DATA__

1;
