#!/usr/bin/perl -w
#
# Copyright (C) 2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::CloudSync::Slave::Test;

use base 'EBox::Test::Class';

use EBox::CloudSync::Slave;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;

use Net::LDAP::Entry;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub cloudsync_slave_use_ok : Test(startup => 1)
{
    use_ok('EBox::CloudSync::Slave') or die;
}

sub _mockRESTClient
{
    my $mockClient = new Test::MockObject();

    $mockClient->{result} = {};
    $mockClient->mock('POST', sub {
        my ($self, $path, %params) = @_;
        unless (exists $self->{result}->{POST}) {
            $self->{result}->{POST} = [];
        }
        my $submitted = {
            path   => $path,
            params => \%params,
        };
        push (@{$self->{result}->{POST}}, $submitted);
    });
    $mockClient->mock('PUT', sub {
        my ($self, $path, %params) = @_;
        unless (exists $self->{result}->{PUT}) {
            $self->{result}->{PUT} = [];
        }
        my $submitted = {
            path   => $path,
            params => \%params,
        };
        my @result = @{$self->{result}->{PUT}};
        push (@result, $submitted);
    });
    $mockClient->mock('DELETE', sub {
        my ($self, $path, %params) = @_;
        unless (exists $self->{result}->{DELETE}) {
            $self->{result}->{DELETE} = [];
        }
        my $submitted = {
            path   => $path,
            params => \%params,
        };
        my @result = @{$self->{result}->{DELETE}};
        push (@result, $submitted);
    });

    return $mockClient;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;

    $self->{slave} = new EBox::CloudSync::Slave();
    $self->{slave} = new Test::MockObject::Extends($self->{slave});
    $self->{slave}->mock('get_ou', sub { return 'ou=Users' });
}

sub test_add_user :  Test(6)
{
    my ($self) = @_;

    my $slave = $self->{slave};
    my $newUserEntry = new Net::LDAP::Entry(
        'uid=newUser,dc=foo,dc=bar',
        objectClass => [qw(posixAccount passwordHolder systemQuotas krb5Principal krb5KDCEntry shadowAccount)],
        uid         => 'newUser'
    );

    eval 'use EBox::Users::User';
    my $newUser = new EBox::Users::User(entry => $newUserEntry);
    my $mockedRESTClient = $self->_mockRESTClient();
    $self->{slave}->mock('RESTClient', sub { return $mockedRESTClient });
    Test::MockObject->fake_module(
        'EBox::Users',
        userByUID => sub { return $newUser });

    lives_ok {
        $slave->_addUser($newUser, "foobarpass");
    } 'No problem calling _addUser';

    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{POST}, "POST result exists");

    my @postResults = @{$mockedRESTClient->{result}->{POST}};
    cmp_ok(scalar @postResults, '==', 1, "Number of POST is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/users/newUser', "The end point is correct");

}

1;

END {
    EBox::CloudSync::Slave::Test->runtests();
}
