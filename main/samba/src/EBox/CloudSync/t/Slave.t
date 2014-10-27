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

use base 'EBox::Test::LDAPClass';

use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;

use Net::LDAP::Entry;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::MockModule;
use Test::More;

sub class
{
    return 'EBox::CloudSync::Slave';
}

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

sub mock_ldap_dn : Test(setup)
{
    my ($self) = @_;

    $self->{ldapObj} = new Test::MockObject();
    $self->{ldapObj}->set_always('dn', 'dc=example,dc=com');
    # Mock LDAP dn
    $self->{mock_ldap} = new Test::MockModule('EBox::Samba::LdapObject');
    $self->{mock_ldap}->mock('_ldap', sub { $self->{ldapObj} });
}

sub mock_samba_user : Test(setup)
{
    my ($self) = @_;

    $self->{sambaUserMod} = new Test::MockModule('EBox::Samba::User');
    $self->{sambaUserMod}->mock('passwordHashes', sub { return ['a', 'b', 'c'] });
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;

    $self->{slave} = new EBox::CloudSync::Slave();
    $self->{slave} = new Test::MockObject::Extends($self->{slave});
    $self->{slave}->{usersMod} = new Test::MockObject();
    $self->{slave}->{usersMod}->mock('ldap', sub { return $self->{ldapObj}});
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
        push (@{$self->{result}->{PUT}}, $submitted);
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
        push (@{$self->{result}->{DELETE}}, $submitted);
    });

    return $mockClient;
}

sub _getTestUser
{
    my ($self, $name, %params) = @_;

    my $dn = 'uid=' . $name . ',' . $params{ou} . ',' . 'dc=example,dc=com';
    my @args = ();
    push (@args, objectClass => [qw(posixAccount passwordHolder systemQuotas krb5Principal krb5KDCEntry shadowAccount)]);
    push (@args, uid         => $name);
    push (@args, samAccountName => $name);
    push (@args, givenName   => $params{firstname}) if (exists $params{firstname});
    push (@args, sn          => $params{lastname}) if (exists $params{lastname});
    push (@args, description => $params{description}) if (exists $params{description});
    push (@args, uidNumber   => $params{uid}) if (exists $params{uid});
    push (@args, gidNumber   => $params{gid}) if (exists $params{gid});
    my $newUserEntry = new Net::LDAP::Entry($dn, @args);

    eval 'use EBox::Samba::User';
    return new EBox::Samba::User(entry => $newUserEntry);
}

# FIXME: Password export and encoding is not being tested...
sub test_add_user :  Test(11)
{
    my ($self) = @_;

    my %expectedOutput = (
        name        => 'newUser',
        firstname   => 'newUserGivenName',
        lastname    => 'newUserSN',
        description => 'newUserDescription',
        uid         => '1234',
        gid         => '5678',
        passwords   => ["YQ==\n", "Yg==\n", "Yw==\n"],  # Base 64 Encoding of a b and c
        ou          => 'ou=Users,',
    );

    my $newUser = $self->_getTestUser($expectedOutput{name}, %expectedOutput);
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });
    $slave->{usersMod}->set_always('userByUID', $newUser);

    lives_ok {
        $slave->_addUser($newUser);
    } 'No problem calling _addUser';

    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{POST}, "POST result exists");

    my @postResults = @{$mockedRESTClient->{result}->{POST}};
    cmp_ok(scalar @postResults, '==', 1, "Number of POST is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/users/' . $expectedOutput{name}, "The end point is correct");
    is_deeply($postResults[0]->{params}->{query}, \%expectedOutput, "Creation user is correct");

    # Tag user as internal
    $newUser->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{POST};

    lives_ok {
        $slave->_addUser($newUser);
    } 'No problem calling _addUser with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist because it's internal");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
}

# FIXME: Password export and encoding is not being tested...
sub test_modify_user :  Test(11)
{
    my ($self) = @_;

    my $name = 'newUser';
    my %expectedOutput = (
        firstname   => 'newUserGivenName',
        lastname    => 'newUserSN',
        description => 'newUserDescription',
        uid         => '1234',
        gid         => '5678',
        passwords   => ["YQ==\n", "Yg==\n", "Yw==\n"],  # Base 64 Encoding of a b and c
        ou          => 'ou=Users,',
    );
    my $newUser = $self->_getTestUser($name, %expectedOutput);
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });
    $slave->{usersMod}->set_always('userByUID', $newUser);

    lives_ok {
        $slave->_modifyUser($newUser);
    } 'No problem calling _modifyUser';

    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{PUT}, "PUT result exists");

    my @postResults = @{$mockedRESTClient->{result}->{PUT}};
    cmp_ok(scalar @postResults, '==', 1, "Number of PUT is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/users/' . $name, "The end point is correct");
    is_deeply($postResults[0]->{params}->{query}, \%expectedOutput, "Modification of user is correct");

    # Tag user as internal
    $newUser->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{PUT};

    lives_ok {
        $slave->_modifyUser($newUser);
    } 'No problem calling _modifyUser with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist because it's internal");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
}

sub test_del_user :  Test(10)
{
    my ($self) = @_;

    my $name = 'newUser';
    my $newUser = $self->_getTestUser($name, ou => 'ou=Users');
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });

    lives_ok {
        $slave->_delUser($newUser);
    } 'No problem calling _delUser';

    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{DELETE}, "DELETE result exists");

    my @postResults = @{$mockedRESTClient->{result}->{DELETE}};
    cmp_ok(scalar @postResults, '==', 1, "Number of DELETE is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/users/' . $name, "The end point is correct");

    # Tag user as internal
    $newUser->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{DELETE};

    lives_ok {
        $slave->_delUser($newUser);
    } 'No problem calling _delUser with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist because it's internal");
}

sub _getTestGroup
{
    my ($self, $name, %params) = @_;

    my $dn = 'cn=' . $name . ',' . $params{ou} . ',' . 'dc=example,dc=com';
    my @args = ();
    push (@args, objectClass => [qw(zentyalDistributionGroup posixGroup)]);
    push (@args, cn          => $name);
    push (@args, description => $params{description}) if (exists $params{description});
    push (@args, gidNumber   => $params{gid}) if (exists $params{gid});
    my $newGroupEntry = new Net::LDAP::Entry($dn, @args);

    eval 'use EBox::Samba::Group';
    my @members = ();
    if (exists $params{members}) {
        foreach my $userName (@{$params{members}}) {
            push (@members, $self->_getTestUser($userName, ou => 'ou=Users'));
        }
    }
    my $group = new EBox::Samba::Group(entry => $newGroupEntry);
    $group = new Test::MockObject::Extends($group);
    $group->mock('users', sub { return \@members; });
    return $group;
}

sub test_add_group :  Test(15)
{
    my ($self) = @_;

    my %expectedOutput = (
        name        => 'newGroup',
        description => 'newGroupDescription',
        gid         => '5678',
        ou          => 'ou=Groups',
    );

    my $newGroup = $self->_getTestGroup($expectedOutput{name}, %expectedOutput);
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });

    $newGroup->mock('isSecurityGroup', sub { return 1; });
    lives_ok {
        $slave->_addGroup($newGroup);
    } 'No problem calling _addGroup';

    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{POST}, "POST result exists");

    my @postResults = @{$mockedRESTClient->{result}->{POST}};
    cmp_ok(scalar @postResults, '==', 1, "Number of POST is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/groups/' . $expectedOutput{name}, "The end point is correct");
    is_deeply($postResults[0]->{params}->{query}, \%expectedOutput, "Creation group is correct");

    # Tag user as internal
    $newGroup->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{POST};

    lives_ok {
        $slave->_addGroup($newGroup);
    } 'No problem calling _addGroup with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist because it's internal");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");

    # Tag group as non internal
    $newGroup->setInternal(0, 1);
    # Tag group as not being a security group
    $newGroup->mock('isSecurityGroup', sub { return 0; });
    # Reset previous results
    delete $mockedRESTClient->{result}->{POST};

    lives_ok {
        $slave->_addGroup($newGroup);
    } 'No problem calling _addGroup with a non security group';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist because it's not a security group");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
}

# FIXME: We are not handling the case when someone adds a non security group but later converts it into a security group.
sub test_modify_group :  Test(15)
{
    my ($self) = @_;

    my $name = 'newGroup';
    my %expectedOutput = (
        name        => $name,
        description => 'newUserDescription',
        gid         => '5678',
        members     => ['one', 'two', 'three'],
        ou          => 'ou=Groups',
    );
    my $newGroup = $self->_getTestGroup($name, %expectedOutput);
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });

    $newGroup->mock('isSecurityGroup', sub { return 1; });
    lives_ok {
        $slave->_modifyGroup($newGroup);
    } 'No problem calling _modifyGroup';

    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{PUT}, "PUT result exists");

    my @postResults = @{$mockedRESTClient->{result}->{PUT}};
    cmp_ok(scalar @postResults, '==', 1, "Number of PUT is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/groups/' . $name, "The end point is correct");
    is_deeply($postResults[0]->{params}->{query}, \%expectedOutput, "Group modification is correct");

    # Tag group as internal
    $newGroup->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{PUT};

    lives_ok {
        $slave->_modifyGroup($newGroup);
    } 'No problem calling _modifyGroup with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist because it's internal");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");

    # Tag group as non internal
    $newGroup->setInternal(0, 1);
    # Tag group as not being a security group
    $newGroup->mock('isSecurityGroup', sub { return 0; });

    lives_ok {
        $slave->_modifyGroup($newGroup);
    } 'No problem calling _modifyGroup with a non security group';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist because it's not a security group");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
}

sub test_del_group :  Test(14)
{
    my ($self) = @_;

    my $name = 'newGroup';
    my $newGroup = $self->_getTestGroup($name, ou => 'ou=Groups');
    my $mockedRESTClient = $self->_mockRESTClient();
    my $slave = $self->{slave};
    $slave->mock('RESTClient', sub { return $mockedRESTClient });

    $newGroup->mock('isSecurityGroup', sub { return 1; });
    lives_ok {
        $slave->_delGroup($newGroup);
    } 'No problem calling _delGroup';

    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    ok(defined $mockedRESTClient->{result}->{DELETE}, "DELETE result exists");

    my @postResults = @{$mockedRESTClient->{result}->{DELETE}};
    cmp_ok(scalar @postResults, '==', 1, "Number of DELETE is correct");
    cmp_ok($postResults[0]->{path}, 'eq', '/v1/users/groups/' . $name, "The end point is correct");

    # Tag user as internal
    $newGroup->setInternal(1, 1);
    # Reset previous results
    delete $mockedRESTClient->{result}->{DELETE};

    lives_ok {
        $slave->_delGroup($newGroup);
    } 'No problem calling _delGroup with internal flag set';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist because it's internal");

    # Tag group as non internal
    $newGroup->setInternal(0, 1);
    # Tag group as not being a security group
    $newGroup->mock('isSecurityGroup', sub { return 0; });

    lives_ok {
        $slave->_delGroup($newGroup);
    } 'No problem calling _delGroup with a non security group';
    is($mockedRESTClient->{result}->{POST}, undef, "POST result doesn't exist because it's not a security group");
    is($mockedRESTClient->{result}->{PUT}, undef, "PUT result doesn't exist");
    is($mockedRESTClient->{result}->{DELETE}, undef, "DELETE result doesn't exist");
}
1;

END {
    EBox::CloudSync::Slave::Test->runtests();
}
