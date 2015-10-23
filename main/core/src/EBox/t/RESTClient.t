#!/usr/bin/perl -w
#
# Copyright (C) 2014-2015 Zentyal S.L.
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

package EBox::RESTClient::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use HTTP::Response;
use JSON::XS;
use File::Slurp;
use Test::Deep;
use Test::Exception;
use Test::MockModule;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::More tests => 34;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
    EBox::Config::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub test_use_ok : Test(startup)
{
    my ($self) = @_;

    use_ok('EBox::RESTClient') or die;
}

sub setup_agent : Test(setup)
{
    my ($self) = @_;
    $self->{agent_class} = new Test::MockModule('LWP::UserAgent');
    $self->{agent} = new Test::MockObject();
    $self->{agent}->set_true('agent', 'ssl_opts', 'proxy', 'timeout');
    $self->{agent_class}->mock('new' => $self->{agent});
}

sub test_bad_construction : Test(3)
{
    my ($self) = @_;

    throws_ok {
        new EBox::RESTClient();
    } 'EBox::Exceptions::MissingArgument', 'Missing server argument on constructor';
    throws_ok {
        new EBox::RESTClient(server => '--.');
    } 'EBox::Exceptions::InvalidData', 'Invalid server argument on constructor';
    throws_ok {
        new EBox::RESTClient(server => 'zentyal.org', scheme => 'trala');
    } 'EBox::Exceptions::InvalidData', 'Invalid scheme argument on constructor';
}

sub test_verify_opts : Test(2)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'graham-coxon.co.uk',
                                  scheme => 'https',
                                  verifyHostname => 0);

    $self->{agent}->mock('request', sub { new HTTP::Response(200, 'OK', undef, 'foo') });

    $cl->GET('/ruin');
    $self->{agent}->called_args_pos_is(3, 2, 'verify_hostname');
    $self->{agent}->clear();

    $cl = new EBox::RESTClient(server => 'graham-coxon.co.uk',
                               scheme => 'https',
                               verifyPeer => 0);
    $cl->GET('/ruin');
    $self->{agent}->called_args_pos_is(4, 2, 'SSL_verify_mode');
    $self->{agent}->clear();

}

sub test_uri_construct : Test(3)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(uri => 'http://clan.es:4433');

    $self->{agent}->mock('request', sub { new HTTP::Response(200, 'OK', undef, 'foo') });

    my $res;
    lives_ok {
        $res = $cl->GET('/mission');
    } 'Check with no credentials using URI';
    isa_ok($res, 'EBox::RESTClient::Result');
    cmp_ok($res->as_string(), 'eq', 'foo');
}

sub test_isa_ok : Test(2)
{
    my ($self) = @_;

    my $cl;
    lives_ok {
        $cl = new EBox::RESTClient(server => 'zentyal.org');
    } 'Creating a client with a server';
    isa_ok($cl, 'EBox::RESTClient');
}

sub test_set_server : Test(2)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'api.cloud.zentyal.com');
    throws_ok {
        $cl->setServer('--');
    } 'EBox::Exceptions::InvalidData', 'Bad set server';
    lives_ok {
        $cl->setServer('zentyal.org');
    } 'Set a valid server';
}

sub test_set_port : Test(2)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'zentyal.org');
    throws_ok {
        $cl->setPort('ad');
    } 'EBox::Exceptions::InvalidData', 'Bad set port';
    lives_ok {
        $cl->setPort(80);
    } 'Set a valid port';
}

sub test_set_scheme : Test(3)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'zentyal.org');
    throws_ok {
        $cl->setScheme('ad');
    } 'EBox::Exceptions::InvalidData', 'Bad set scheme';
    foreach my $validScheme (qw(http https)) {
        lives_ok {
            $cl->setScheme($validScheme);
        } 'Valid scheme set';
    }
}

sub test_GET : Test(4)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'api.cloud.zentyal.com');
    throws_ok {
        $cl->GET();
    } 'EBox::Exceptions::MissingArgument', 'Missing path';

    $self->{agent}->mock('request', sub { new HTTP::Response(200, 'OK', undef, 'foo') });

    my $res;
    lives_ok {
        $res = $cl->GET('/check');
    } 'Check to API';
    isa_ok($res, 'EBox::RESTClient::Result');
    cmp_ok($res->as_string(), 'eq', 'foo');

}

sub test_POST_with_journal : Test(12)
{
    my ($self) = @_;

    my $cl = new EBox::RESTClient(server => 'api.cloud.zentyal.com',
                                  credentials => { username => 'user',
                                                   password => 'password' });

    $self->{agent}->mock('request', sub { new HTTP::Response(200, 'OK', undef, 'foo') });

    throws_ok {
        $cl->POST();
    } 'EBox::Exceptions::MissingArgument', 'Missing path';

    lives_ok {
        $cl->POST('/check');
    } 'Check to API using POST';

    $self->{agent}->mock('request', sub { new HTTP::Response(404, 'Not Found', undef, 'bar') });

    my $journalDir = '/tmp/test-ops-journal';
    mkdir($journalDir);
    $cl = new Test::MockObject::Extends($cl);
    $cl->set_always('JournalOpsDirPath', $journalDir);

    throws_ok {
        $cl->POST('/tralala');
    } 'EBox::Exceptions::RESTRequest', '404 Not found';

    $self->{agent}->mock('request', sub { new HTTP::Response(500, 'Internal Server Error', undef, 'bar') });

    throws_ok {
        $cl->POST('/internal-server-error', retry => 1);
    } 'EBox::Exceptions::RESTRequest', '500 Internal server error';

    opendir(my $dir, $journalDir);
    foreach my $file (readdir($dir)) {
        next if ($file =~ /\./);
        my $content = File::Slurp::read_file("$journalDir/$file");
        my $op;
        lives_ok {
            $op = JSON::XS::decode_json($content);
        } 'Decoding journaled op from JSON format';
        cmp_ok($op->{uri}, 'eq', 'https://api.cloud.zentyal.com', 'Right journaled URI');
        cmp_deeply($op->{credentials},
                   {username => 'user', password => 'password'},
                   'Journaled credentials');
        cmp_ok($op->{method}, 'eq', 'POST', 'Journaled method');
        cmp_ok($op->{path}, 'eq', '/internal-server-error', 'Journaled path');
        ok(exists($op->{query}), 'Journaled query');
        cmp_ok($op->{res_code}, '==', 500, 'Journaled previous result code');
        ok(exists($op->{res_content}), 'Journaled previous result content');
        unlink("$journalDir/$file");
    }
    closedir($dir);
    rmdir($journalDir);
}

1;

END {
    EBox::RESTClient::Test->runtests();
}
