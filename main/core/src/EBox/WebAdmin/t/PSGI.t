#!/usr/bin/perl -w

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

# A module to test EBox::WebAdmin::PSGI

use warnings;
use strict;

package EBox::WebAdmin::PSGI::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::Module::Config::TestStub;

use Test::Exception;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Config::TestStub::fake('conf' => '/tmp/');
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub test_use_ok : Test(startup => 1)
{
    my ($self) = @_;

    use_ok('EBox::WebAdmin::PSGI') or die;
}

sub teardown_sub_app_file : Test(teardown)
{
    system('rm -rf /tmp/webadmin');
}

sub test_add : Test(13)
{
    my ($self) = @_;

    lives_ok {
        EBox::WebAdmin::PSGI::addSubApp(url => '/foo', appName => 'EBox::WebAdmin::_setConf');
        EBox::WebAdmin::PSGI::addSubApp(url => '/bar', appName => 'EBox::WebAdmin::_create');
    } 'Adding two sub apps';
    throws_ok {
        EBox::WebAdmin::PSGI::addSubApp(url => '/foo', appName => 'EBox::WebAdmin::_daemons');
    } 'EBox::Exceptions::DataExists', 'Throw exception if the same URL is used twice';
    my $subApps = EBox::WebAdmin::PSGI::subApps();
    cmp_ok(@{$subApps}, '==', 2, 'Added two subapps');
    foreach my $subApp (@{$subApps}) {
        like($subApp->{url}, qr{^/.*}, 'First URL');
        cmp_ok(ref($subApp->{app}), 'eq', 'CODE', 'Second is a code ref');
        cmp_ok($subApp->{validation}, '==', 0, 'Not SSL validated');
        is($subApp->{validate}, undef, 'Not Code ref for that validation');
        is($subApp->{userId}, undef, 'Not user id when no validation is required');
    }
}

sub test_add_ssl_validate : Test(7)
{
    my ($self) = @_;

    lives_ok {
        EBox::WebAdmin::PSGI::addSubApp(url => '/foo', appName => 'EBox::WebAdmin::_setConf',
                                        validation => 1, validateFunc => 'EBox::WebAdmin::_create',
                                        userId => 'test');
    } 'Adding a sub app with SSL validation';
    my $subApps = EBox::WebAdmin::PSGI::subApps();
    cmp_ok(@{$subApps}, '==', 1, 'Added a subapp');
    foreach my $subApp (@{$subApps}) {
        like($subApp->{url}, qr{^/.*}, 'First URL');
        cmp_ok(ref($subApp->{app}), 'eq', 'CODE', 'Second is a code ref');
        ok($subApp->{validation}, 'SSL validated');
        cmp_ok(ref($subApp->{validate}), 'eq', 'CODE',
               'Code ref for that validation');
        cmp_ok($subApp->{userId}, 'eq', 'test', 'User id set');
    }
}

sub test_ssl_validate : Test(2)
{
    my ($self) = @_;

    EBox::WebAdmin::PSGI::addSubApp(url => '/foo', appName => 'EBox::WebAdmin::_setConf',
                                    validation => 1, validateFunc => 'EBox::WebAdmin::_create');
    is(EBox::WebAdmin::PSGI::subApp(url => '/foo/bar', validation => 0), undef,
       'Do not return the app if SSL validation mismatches');
    isnt(EBox::WebAdmin::PSGI::subApp(url => '/foo/bar', validation => 1), undef,
         'Return the app if the SSL validation matches and the path matches with the start of the url');

}

sub test_remove : Test(4)
{
    my ($self) = @_;

    throws_ok {
        EBox::WebAdmin::PSGI::removeSubApp('/foo');
    } 'EBox::Exceptions::DataNotFound', 'Throw exception if the URL does not exist';

    EBox::WebAdmin::PSGI::addSubApp(url => '/bar', appName => 'EBox::WebAdmin::_create');
    my $subApps = EBox::WebAdmin::PSGI::subApps();
    cmp_ok(@{$subApps}, '==', 1, 'Added sub-app');
    lives_ok {
        EBox::WebAdmin::PSGI::removeSubApp('/bar');
    } 'Removing a sub app';
    $subApps = EBox::WebAdmin::PSGI::subApps();
    cmp_ok(@{$subApps}, '==', 0, 'Empty subApps');
}

1;

END {
    EBox::WebAdmin::PSGI::Test->runtests();
}

