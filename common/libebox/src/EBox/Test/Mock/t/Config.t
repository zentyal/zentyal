use strict;
use warnings;

use Test::More tests => 51;
use Test::Exception;

use lib '../../../..';


BEGIN { use_ok 'EBox::Test::Mock::Config' }
badParametersTest();
mockTest();

sub badParametersTest 
{
    dies_ok { EBox::Test::Mock::Config::mock()  } 'No parameters call';
    dies_ok { EBox::Test::Mock::Config::mock(cgi => '/tmp/cgi', monkeyFightDir => '/usr/zoo')  } 'Incorrect parameters call';
}



sub mockTest
{
    # data case preparation
    my @configKeys = qw(prefix    etc var user group share libexec locale conf tmp passwd sessionid log logfile stubs cgi templates schemas www css images package version lang ); 
    my %beforeMock = map { $_ => (EBox::Config->can($_))->() }  @configKeys;
    my %afterMock = %beforeMock;

    $afterMock{prefix}  = '/macaco';
    $afterMock{user}    = 'rhesus';
    $afterMock{logfile} = '/egypt/baboon.log';
    $afterMock{version} = '-0.4'; 

    dies_ok {EBox::Test::Mock::Config::unmock()} 'Unmocking before the module was mocked';
    lives_ok { EBox::Test::Mock::Config::mock(prefix => $afterMock{prefix}, user => $afterMock{user}, logfile => $afterMock{logfile}, version => $afterMock{version}) };

    diag "Checking results after mocking EBox::Config";
    _checkConfigSubs(\%afterMock);

    lives_ok {EBox::Test::Mock::Config::unmock()};

    diag "Checking results after umocking EBox::Config";
    _checkConfigSubs(\%beforeMock);
    
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

1;
