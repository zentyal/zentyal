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

package EBox::OpenVPN::Model::Servers::Test;

use base 'EBox::Test::Class';

use EBox::Test;
use EBox::TestStubs qw(fakeModule);
use EBox::Network;

use Test::More;
use Test::Exception;
use Test::MockObject;
use TryCatch;

use lib '../../../..';

use EBox::OpenVPN;
use EBox::CA::TestStub;

use EBox::OpenVPN::Model::Servers;

sub testDir
{
    return  '/tmp/ebox.openvpn.test';
}

sub fakeCA : Test(startup)
{
  EBox::CA::TestStub::fake();
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
    fakeModule(
                   name => 'network',
                   package => 'EBox::Network',
                   subs => [
                            ifaceMethod => sub {
                                return 'static'
                            },
                           ],
                  );

     EBox::Global::TestStub::setModule('ca' => 'EBox::CA');

}

sub clearConfiguration : Test(teardown)
{
    EBox::TestStubs::setConfig();
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

sub _newServers
{
    my ($self) = @_;

    return EBox::OpenVPN::Model::Servers->new(
                      confmodule => $self->{openvpnModInstance},
                      directory   => 'Servers'
                                                         );

}

sub ifaceNumbersTest : Test(2)
{
    my ($self) = @_;

    my $servers = $self->_newServers();

    foreach my $id (0 .. 12) {
        my $name = 'server' . $id;
        $servers->add(
                      name => $name,
                     );
    }

    lives_ok {
        $servers->initializeInterfaces
    } 'calling method for initializing interface numbers';

    my $numbersOk = 1;
    my %numbers;
    foreach my $id (@{ $servers->ids()  }) {
        my $row  = $servers->row($id);
        my $name = $row->elementByName('name')->value();
        my $number = $row->elementByName('interfaceNumber')->value();
        if ($number < 0) {
            $numbersOk = 0;
            diag "Server $name has not a interface number assigned";
        }

        if (exists $numbers{$number}) {
            $numbersOk = 0;
            my $other = $numbers{$number};
            diag "Number $number repeated in servers $name and $other";
            my @allNumbers = keys %numbers;
            diag "All numbers in list: @allNumbers";
        }

        $numbers{$number} = $name;
    }

    ok $numbersOk,  "All server have unique interface numbers assigned";

}

1;

