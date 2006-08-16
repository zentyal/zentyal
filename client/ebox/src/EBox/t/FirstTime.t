package main;
# Description:
use strict;
use warnings;

use Test::MockObject;
use EBox::Auth;
use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use EBox::TestStub;
use EBox::Gettext;

use lib '../..';



my $defaultPasswdChanged;

globalSetUp();
use_ok('EBox::FirstTime');
removeFirstTimeMarkTest();
tasksTest();

sub removeFirstTimeMarkTest
{
  my $FIRST_TIME_KEY = '/ebox/firsttime/todo';
  setFakeEntry(undef, $FIRST_TIME_KEY, 1);
  ok EBox::FirstTime::isFirstTime(), "Checking isFirstTime";
  
  EBox::FirstTime::removeFirstTimeMark();
  ok !EBox::FirstTime::isFirstTime(), "Checking isFirstTime after removeFirstTimeMark";
}

sub tasksTest
{
  setFakeEntry(undef, '/ebox/firsttime/modules/macaco', 'Macaco::FirstTime');
  setFakeEntry(undef, '/ebox/firsttime/modules/gorilla', 'Simio::Gorilla::FirstTime');
  $INC{'Simio/Gorilla/FirstTime.pm'} = 1;
  $INC{'Macaco/FirstTime.pm'} = 1;

  my @tasks;
  my @expectedTasks =  (
		       Simio::Gorilla::FirstTime::tasks(),
		       Macaco::FirstTime::tasks(),
		       EBox::FirstTime::baseTasks(),
		       );
  $_->{completed} = undef foreach @expectedTasks;


  $defaultPasswdChanged = 0; #  this make the change password task uncompleted
  @tasks =  EBox::FirstTime::tasks();
  cmp_bag \@tasks, \@expectedTasks, 'Checking tasks with change default password task incomplete';
			      

  @expectedTasks =  (
		       Simio::Gorilla::FirstTime::tasks(),
		       Macaco::FirstTime::tasks(),
		       EBox::FirstTime::baseTasks(),
		       );
  foreach my $task (@expectedTasks) {
    if ($task->{url} eq '/ebox/FirstTime/Passwd') {
      $task->{completed} = 1;
    }
    else {
      $task->{completed} = undef;
    }
  }

  $defaultPasswdChanged = 1; # complete the changed password task
  @tasks = EBox::FirstTime::tasks();
  cmp_bag \@tasks, \@expectedTasks, 'Checking tasks with change default password task done';
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
				$client->mock('all_entries' => sub {
						return allFakeEntries(@_);
					      });
				$client->mock('get_string' => sub {
					return getFakeEntry(@_);
					      });
				$client->mock('get_bool' => sub {
					return getFakeEntry(@_);
					      });
				$client->mock('set_bool' => sub {
						return setFakeEntry(@_);
					      });

				return $client;
			      }
			       );

}


my %fakeGconf;

sub setFakeEntry
{
  my ($self, $entry, $value) = @_;
  $fakeGconf{$entry} = $value;
}

sub getFakeEntry
{
  my ($self, $entry) = @_;
  if (exists  $fakeGconf{$entry}) {
    return  $fakeGconf{$entry};
  } 
  else {
    die "trying to read uninitialized entry: $entry fake gconf: " . %fakeGconf;
  }
}

sub allFakeEntries
{
  my ($self, $dir) = @_;

  
  my @keys = grep {
    $_ =~ m{^$dir/\w+$};
  } keys %fakeGconf;
  

  return @keys;
}


package Macaco::FirstTime;

my $completed1;
sub completed1 {  return $completed1; }
sub setCompleted1 { my ($v) = @_; $completed1 = $v;  }

my $completed2;
sub completed2 {  return $completed2; }
sub setCompleted2 { my ($v) = @_; $completed2 = $v;  }

sub tasks {
  return (
	  { completedCheck => \&Macaco::FirstTime::completed1, url => '/ebox/macaco/firsttime/1', desc => 'ea'},
	  { completedCheck => \&Macaco::FirstTime::completed2, url => '/ebox/macaco/firsttime/2', desc => 'ea'},
	 );
}

package Simio::Gorilla::FirstTime;

my $completed;
sub completed {  return $completed; }
sub setCompleted { my ($v) = @_; $completed = $v;  }
sub tasks {
  return (
	  { completedCheck => \&Simio::Gorilla::FirstTime::completed, url => '/ebox/simio/gorilla/firsttime/', desc => 'ea'},
	 );
}



1;
