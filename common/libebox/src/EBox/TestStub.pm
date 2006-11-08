package EBox::TestStub;
# Description: Test stub for EBox package. It change the log process to use stdout instead a file only writable by ebox
# 
use strict;
use warnings;

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


# XX: fix this sub (see TestStub.t)
# sub unfake
# {
#     if (!defined $mockedEBoxModule) {
# 	die "EBox module not mocked";
#     }

#     $mockedEBoxModule->unmock_all();
#     $mockedEBoxModule = undef;
# }


my $loginit;

sub _mockedLogger
{
    my ($cat) = @_;

    defined($cat) or $cat = caller;
    unless ($loginit) {
	Log::Log4perl->easy_init( {
				   level  => $logLevel,
				   layout => '# [EBox log]%d %m%n',
				  } );
	$loginit = 1;
      }

    return Log::Log4perl->get_logger($cat);
}




1;
