use strict;
use warnings;

use Test::More tests => 19;
use Test::Exception;

use lib '../../..';

use EBox::TestStub;
use Error qw(:try);

EBox::TestStub::fake();

BEGIN { use_ok 'EBox::Config::TestStub' }

badParametersTest();
mockTest();

sub badParametersTest
{
    dies_ok { EBox::Config::TestStub::mock(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } ' Incorrect parameters call';
    dies_ok { EBox::Config::TestStub::setConfigKeys(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } 'Incorrect parameters call';
}

sub mockTest
{
    # data case preparation
    my %noMockedKeys = map {
        my $key = $_;
        my $getter = EBox::Config->can($key);
        ($key => $getter->())
    } qw(var etc);


    my %mockedKeys = (
        prefix =>   '/macaco',
        logfile => '/egypt/baboon.log',
        version => '-0.4',
        home => '/home/faked',
       );


    lives_ok { EBox::Config::TestStub::fake(%mockedKeys) } 'mocking EBox::Config';
    while (my ($key, $expected) = each %mockedKeys) {
        my $sub = EBox::Config->can($key);
        is ($sub->(), $expected, "Check mocked key $key");
    }
    while (my ($key, $expected) = each %noMockedKeys) {
        my $sub = EBox::Config->can($key);
        is ($sub->(), $expected, "Check that unmocked key $key preserves its value");
    }

    is EBox::Config::user(), 'ebox', 'Checking default mocked method user';
    is EBox::Config::group(), 'ebox', 'Checking default mocked method group';


    my %newMocked = (
        user => 'fakeUser',
        etc => '/tmp/etc',
       );

    lives_ok { EBox::Config::TestStub::setConfigKeys(%newMocked) } 'setting mocked keys via  EBox::Config::TestStub::setConfigKeys';
    while (my ($key, $expected) = each %mockedKeys) {
        my $sub = EBox::Config->can($key);
        is ($sub->(), $expected, "Check new mocked key $key");
    }

    lives_ok  { EBox::Config::TestStub::unfake() } 'Unfake module';
    is EBox::Config::etc(), $noMockedKeys{etc}, 'Checking that nomocked behaviour has been restored';
}

1;
