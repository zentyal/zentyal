package main;
# Description:
use strict;
use warnings;

use Test::More qw(no_plan);
use Test::MockObject;
use EBox::Test::CGI;

use lib '../../../..';


# test stub control variables
my @firstTimeTasks;
my $firstTimeState;


fakeModules();
use_ok ('EBox::CGI::FirstTime::Index');


sub fakeModules
{
  Test::MockObject->fake_module('EBox::FirstTime',
			       isFirstTime => sub { return $firstTimeState  },
			       removeFirstTimeMark => sub { $firstTimeState = 0 },
				tasks => sub { return @firstTimeTasks },
			       );

}



1;
