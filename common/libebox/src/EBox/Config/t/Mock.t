use strict;
use warnings;

use Test::More tests => 80;
use Test::Exception;

use lib '../../..';


BEGIN { use_ok 'EBox::Config::Mock' }


my @configKeys = qw(prefix    etc var user group share libexec locale conf tmp passwd sessionid log logfile stubs cgi templates schemas www css images package version lang );

mockBadParametersTest();
mockTest();
setConfigKeysBadParametersTest();
setConfigKeysTest();

sub mockBadParametersTest 
{
    dies_ok { EBox::Config::Mock::mock(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } ' Incorrect parameters call';
}


sub setConfigKeysBadParametersTest
{
    dies_ok { EBox::Config::Mock::setConfigKeys()  } 'No parameters call';
    dies_ok { EBox::Config::Mock::setConfigKeys(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } 'Incorrect parameters call';
}




sub mockTest
{
    # data case preparation
     my %beforeMock = _getConfigKeysAndValues();
    my %afterMock = %beforeMock;

    $afterMock{prefix}  = '/macaco';
    $afterMock{user}    = 'rhesus';
    $afterMock{logfile} = '/egypt/baboon.log';
    $afterMock{version} = '-0.4'; 

    dies_ok {EBox::Config::Mock::unmock()} 'Unmocking before the module was mocked';


    lives_ok { EBox::Config::Mock::mock(prefix => $afterMock{prefix}, user => $afterMock{user}, logfile => $afterMock{logfile}, version => $afterMock{version}) };
   can_ok('EBox::Config', @configKeys), 'Checking that the accessor subs are in the mesocked module';

    _checkConfigSubs(\%afterMock);

    lives_ok {EBox::Config::Mock::unmock()};
     can_ok('EBox::Config', @configKeys), 'Checking that after the unmock the config keys accessors are still here';

    diag "Checking results after umocking EBox::Config";

    _checkConfigSubs(\%beforeMock);
    
}

sub setConfigKeysTest
{
    can_ok('EBox::Config', @configKeys);
    my %before = _getConfigKeysAndValues();
    my %after = %before;

    $after{locale} = 'de';
    $after{group}  = 'macacos';
    $after{css}    = '/home/dessign/css';
    $after{lang}   = 'de';

    dies_ok {  EBox::Config::Mock::setConfigKeys(locale => $after{locale}, group => $after{group}, css => $after{css}, lang => $after{lang}) } 'Calling setConfigKeys without mocking first';
    
    EBox::Config::Mock::mock();
    lives_ok { EBox::Config::Mock::setConfigKeys(locale => $after{locale}, group => $after{group}, css => $after{css}, lang => $after{lang}) };

    diag "Checking results after setConfigKeys call";
    _checkConfigSubs(\%after);
}


sub _checkConfigSubs
{
    my ($expectedResultsBySub_r) = @_;

    while (my ($subName, $expectedResult) = each %{$expectedResultsBySub_r}) {
#	my $sub_r = EBox::Config::can($subName);
	my $sub_r = UNIVERSAL::can('EBox::Config', $subName);
	defined $sub_r or next;# die 'Sub not found';

	my $actualResult =  $sub_r->();
	is $actualResult, $expectedResult, "Checking result of $subName (was: $actualResult expected: $expectedResult)";
    }
}

sub _getConfigKeysAndValues
{
    my @keyNames = @configKeys;
    return map { $_ => (EBox::Config->can($_))->() }  @keyNames;
}


1;
