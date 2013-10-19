use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

use lib '../../..';

use EBox::TestStub;
use TryCatch;

EBox::TestStub::fake();

BEGIN { use_ok 'EBox::Config::TestStub' }

my @configKeys = qw(prefix etc var user group share libexec locale conf tmp passwd sessionid log logfile stubs cgi templates schemas www css images version lang );

mockBadParametersTest();
#mockTest();
setConfigKeysBadParametersTest();
#setConfigKeysTest();

sub mockBadParametersTest
{
    dies_ok { EBox::Config::TestStub::mock(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } ' Incorrect parameters call';
}

sub setConfigKeysBadParametersTest
{
    dies_ok { EBox::Config::TestStub::setConfigKeys()  } 'No parameters call';
    dies_ok { EBox::Config::TestStub::setConfigKeys(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } 'Incorrect parameters call';
}

sub mockTest
{
    # data case preparation
    my %beforeMock = _getConfigKeysAndValues();
    my %afterMock = %beforeMock;

    $afterMock{prefix}  = '/macaco';
    $afterMock{logfile} = '/egypt/baboon.log';
    $afterMock{version} = '-0.4';

    lives_ok { EBox::Config::TestStub::fake(prefix => $afterMock{prefix}, user => $afterMock{user}, logfile => $afterMock{logfile}, version => $afterMock{version}) } 'mocking EBox::Config';

    can_ok('EBox::Config', @configKeys);#, 'Checking that the accessor subs are in the mocked module';

    _checkConfigSubs(\%afterMock);

    lives_ok {EBox::Config::TestStub::unfake()};
    can_ok('EBox::Config', @configKeys);#, 'Checking that after the unmock the config keys accessors are still here';

    diag "Checking results after umocking EBox::Config";

    _checkConfigSubs(\%beforeMock);
}

sub setConfigKeysTest
{
    can_ok('EBox::Config', @configKeys);
    my %before = _getConfigKeysAndValues();
    my %after = %before;

    $after{locale} = 'de';
    $after{libexec}  = '/usr/bin/macacos';
    $after{css}    = '/home/dessign/css';
    $after{lang}   = 'de';

    EBox::Config::TestStub::fake();
    lives_ok { EBox::Config::TestStub::setConfigKeys(libexec => $after{libexec}, group => $after{group}, css => $after{css}, lang => $after{lang}, locale => $after{locale}) };

    diag "Checking results after setConfigKeys call";
    _checkConfigSubs(\%after);
}

sub _checkConfigSubs
{
    my ($expectedResultsBySub_r) = @_;

    while (my ($subName, $expectedResult) = each %{$expectedResultsBySub_r}) {
        my $sub_r = UNIVERSAL::can('EBox::Config', $subName);
        defined $sub_r or next;# die 'Sub not found';

        SKIP: {
            my $actualResult;
            try {
                $actualResult =  $sub_r->();
            } catch {
                skip 1, "To retrieve key $subName is needed a eBox full installation";
                next;
            }

            is $actualResult, $expectedResult, "Checking result of $subName (was: $actualResult expected: $expectedResult)";
        }
    }
}

sub _getConfigKeysAndValues
{
    my @keyNames = @configKeys;
    return map {
        my $getter = EBox::Config->can($_);
        my $value;
        try {
            $value = $getter->();
        } catch {
            diag "can not get the vaule of $_ because it needs a eBox's full installation";
            $value = undef;
        }

        ($_ => $value)
    } @keyNames;
}

1;
