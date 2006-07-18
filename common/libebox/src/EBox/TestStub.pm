package EBox::TestStub;
# Description:
# 
use strict;
use warnings;
#use Smart::Comments; # turn on for debug purposes
use Test::MockModule;
use Log::Log4perl qw(:easy);

my $mockedEBoxModule;
my $logLevel;


sub fake
{
    my ($minLogLevel) = @_;
    (defined $minLogLevel) or $minLogLevel = 'debug';

    if (defined $mockedEBoxModule) {
	return;
    }


    $mockedEBoxModule = new Test::MockModule('EBox');
    $mockedEBoxModule->mock('logger', \&_mockedLogger);


    my %logLevelsByName = (
		     'debug' => $DEBUG,
		     'info'  => $INFO,
		     'warn'  => $WARN,
		     'error'  => $ERROR,
		     'fatal'  => $FATAL,
		     );

    (exists $logLevelsByName{$minLogLevel}) or die "Incorrect log level: $minLogLevel";    
    $logLevel = $logLevelsByName{$minLogLevel};
}

sub unfake
{
    if (!defined $mockedEBoxModule) {
	die "EBox module not mocked";
    }

    $mockedEBoxModule->unmock_all();
    $mockedEBoxModule = undef;
}


my $loginit;

sub _mockedLogger
{
    my ($cat) = @_;

    defined($cat) or $cat = caller;
    unless ($loginit) {
	Log::Log4perl->easy_init($logLevel);
	$loginit = 1;
      }

    return Log::Log4perl->get_logger($cat);
}




1;
