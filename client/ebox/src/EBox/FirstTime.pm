package EBox::FirstTime;
# Description:
use strict;
use warnings;
use Gnome2::GConf;
use EBox::Auth;
use EBox::Gettext;

#
# Function:  isFirstTime
#
# Returns: wether we have to do the firstime tasks or not
#	
sub isFirstTime
{
  my $client = Gnome2::GConf::Client->get_default;
  my $ft =    $client->get_bool('/ebox/firsttime/todo');
  return $ft;
}

#
# Function:  removeFirstTimeMark
#
#  Mark the firsttime tasks as all done
sub removeFirstTimeMark
{
    my $client = Gnome2::GConf::Client->get_default;
    $client->set_bool('/ebox/firsttime/todo', 0);
}


#
# Function: tasks
#
# Returns: 
#     a list with the first time tasks. Each task is reprented as a anonymous hash with the following keys
#	 completed - wethet the task is aready done or not
#        url       - url to the page wher will can complete the task
#        desc      - user friendly task description
#       completedCheck - (for internal usage)
# 
sub tasks
{
  my @tasks = modulesTasks();
  push @tasks, baseTasks();


  return map {
    my $checkCompletedSub = $_->{completedCheck};
    my $completedStatus = $checkCompletedSub->();
    $_->{completed} = $completedStatus ? 1 : undef;
    $_;
  } @tasks;
}



#
# Function: baseTasks
#
# Returns:
#	a list of base eboxs tasks with the same format used in modulesTasks
#
# 
sub baseTasks
{
  return ( { completedCheck => \&EBox::Auth::defaultPasswdChanged, url => '/ebox/FirstTime/Passwd', desc => __('Change default password')   }, );
}

#
# Function: modulesTasks
#
#
# Returns: a list with the first time tasks required by each installed modules. Each task is represented as an anonymous hash with the following keys and values
#        url       - url to the page wher will can complete the task
#        desc      - user friendly task description
#        completedCheck - sub reference to the function we can use to find out if a task is completed or not
#	
sub modulesTasks
{
  my @tasks;

  my $client = Gnome2::GConf::Client->get_default;
  my @keys = $client->all_entries('/ebox/firsttime/modules');

  foreach my $key (@keys) {
    my $classname = $client->get_string($key);
    eval "use $classname";
    if ($@) {
      throw EBox::Exceptions::Internal "Error loading class $classname: $@";
    }

    push @tasks, $classname->tasks();
  }

  return @tasks;
}



1;
