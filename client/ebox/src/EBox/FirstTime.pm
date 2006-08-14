package EBox::FirstTime;
# Description:
use strict;
use warnings;
use Gnome2::GConf;
use EBox::Auth;
use EBox::Gettext;



my @firstTimeTasks = (
	      { completedCheck => \&EBox::Auth::defaultPasswdChanged, url => '/ebox/FirstTime/Passwd', desc => __('Change default password')   },
	    );

sub isFirstTime
{
  my $client = Gnome2::GConf::Client->get_default;
  my $ft =    $client->get_bool('/ebox/firsttime');
  return $ft;
}

sub removeFirstTimeMark
{
    my $client = Gnome2::GConf::Client->get_default;
    $client->set_bool('/ebox/firsttime', 0);
}


sub tasks
{
  return map {
    my $checkCompletedSub = $_->{completedCheck};
    my $completedStatus = $checkCompletedSub->();
    $_->{completed} = $completedStatus ? 1 : undef;
    $_;
  } @firstTimeTasks;
}







1;
