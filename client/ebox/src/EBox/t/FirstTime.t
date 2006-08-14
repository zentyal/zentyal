package main;
# Description:
use strict;
use warnings;

use Test::MockObject;
use EBox::Auth;
use Test::More qw(no_plan);
use Test::Exception;

use EBox::TestStub;
use EBox::Gettext;

use lib '../..';

my $FIRST_TIME_KEY = '/ebox/firsttime';
my $firstTimeValue;
my $defaultPasswdChanged;

globalSetUp();
use_ok('EBox::FirstTime');
removeFirstTimeMarkTest();
tasksTest();

sub removeFirstTimeMarkTest
{
  $firstTimeValue = 1;
  ok EBox::FirstTime::isFirstTime(), "Checking isFirstTime";
  
  EBox::FirstTime::removeFirstTimeMark();
  ok !EBox::FirstTime::isFirstTime(), "Checking isFirstTime after removeFirstTimeMark";
}

sub tasksTest
{
  my @tasks;
  my @expectedTasks;

  @expectedTasks = ( 	      { completedCheck => \&EBox::Auth::defaultPasswdChanged, url => '/ebox/FirstTime/Passwd', desc => __('EAA'), completed => undef   } );
  $defaultPasswdChanged = 0; #  this make the change password task uncompleted
  @tasks = EBox::FirstTime::tasks();
  is_deeply \@tasks, \@expectedTasks, 'Checking tasks with change default password task incomplete';
			      
			      
  @expectedTasks = ( 	      { completedCheck => \&EBox::Auth::defaultPasswdChanged, url => '/ebox/FirstTime/Passwd', desc => __('EAA'), completed => 1  } );
  $defaultPasswdChanged = 1; # complete the changed password task
  @tasks = EBox::FirstTime::tasks();
  is_deeply \@tasks, \@expectedTasks, 'Checking tasks with change default password task done';
}

sub globalSetUp
{
  EBox::TestStub::fake();

  Test::MockObject->fake_module('EBox::Auth',
				'defaultPasswdChanged' => sub { return $defaultPasswdChanged  }
			       );

  # needed for Gnome2::GConf::Client
  Test::MockObject->fake_module('Gnome2::GConf::Client',
			      get_default => sub {
				my $client = Test::MockObject->new();
				$client->mock('get_bool' => sub {
					my ($self, $key) = @_;
					die "Bad key $key used" if $key ne $FIRST_TIME_KEY; 
					return $firstTimeValue;
					      });
				$client->mock('set_bool' => sub {
					my ($self, $key, $value) = @_;
					die "Bad key $key used" if $key ne $FIRST_TIME_KEY; 
					$firstTimeValue = $value;
					      });
				return $client;
			      }
			       );

}




1;
