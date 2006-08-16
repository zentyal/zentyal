package EBox::FirstTime;
# Description:
use strict;
use warnings;
use Gnome2::GConf;
use EBox::Auth;
use EBox::Global;
use EBox::Gettext;


sub isFirstTime
{
  my $client = Gnome2::GConf::Client->get_default;
  my $ft =    $client->get_bool('/ebox/firsttime/todo');
  return $ft;
}

sub removeFirstTimeMark
{
    my $client = Gnome2::GConf::Client->get_default;
    $client->set_bool('/ebox/firsttime/todo', 0);

    # commit changes...
    my $global = EBox::Global::getInstance();
    $global->restartAllMdoules();
}


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


# this add the base ebox tasks
sub baseTasks
{
  return ( { completedCheck => \&EBox::Auth::defaultPasswdChanged, url => '/ebox/FirstTime/Passwd', desc => __('Change default password')   }, );
}


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
