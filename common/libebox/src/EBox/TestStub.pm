package EBox::TestStub;
# Description: Test stub for EBox package. It change the log process to use stdout instead a file only writable by ebox
# 
use strict;
use warnings;

use EBox;
use Test::MockObject;
use Log::Log4perl qw(:easy);


my $logLevel;

sub fake
{
    my ($minLogLevel) = @_;
    (defined $minLogLevel) or $minLogLevel = 'debug';

    my %logLevelsByName = (
		     'debug' => $DEBUG,
		     'info'  => $INFO,
		     'warn'  => $WARN,
		     'error'  => $ERROR,
		     'fatal'  => $FATAL,
		     );

    (exists $logLevelsByName{$minLogLevel}) or die "Incorrect log level: $minLogLevel";    
    $logLevel = $logLevelsByName{$minLogLevel};


    Test::MockObject->fake_module('EBox',
				  logger => \&_mockedLogger,
				 );

}



sub unfake
{
  delete $INC{'EBox.pm'};
  eval 'use EBox';
  ($@) and die "Error unfacking EBox: $@";
}


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
