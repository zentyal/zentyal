# Copyright (C) 2009 Warp Networks S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


package EBox::AntiVirus;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::FirewallObserver
           );

use EBox::Gettext;
use EBox::Service;
#use EBox::Dashboard::Module;

use Perl6::Junction qw(any);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Global;
use EBox::AntiVirus::FirewallHelper;

use constant {
  CLAMAVPIDFILE                 => '/var/run/clamav/clamd.pid',
  CLAMD_INIT                    => 'clamav-daemon',
  CLAMD_CONF_FILE               => '/etc/clamav/clamd.conf',

  CLAMD_SOCKET                  => '/var/run/clamav/clamd.ctl',

  FRESHCLAM_CONF_FILE           => '/etc/clamav/freshclam.conf',
  FRESHCLAM_OBSERVER_SCRIPT     => 'freshclam-observer',
  FRESHCLAM_CRON_SCRIPT         => '/etc/cron.hourly/freshclam',
};


# Group: Protected methods

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::AntiVirus> - the recently created module
#
sub _create
{
        my $class = shift;
        my $self = $class->SUPER::_create(name => 'antivirus',
                                          printableName => __n('Antivirus')
                                         );
        bless($self, $class);
        return $self;
}



# Group: Public methods

# Method: menu
#
#       Add an entry to the menu with this module
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item('name' => 'AntiVirus',
                                    'text' => $self->printableName(),
                                    'separator' => 'UTM',
                                    'order' => 340,
                                    'url' => 'AntiVirus/View/FreshclamStatus',
                                   );

    $root->add($item);
}

# Method: modelClasses
#
#       Return the model classes used by the module.
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
            'EBox::AntiVirus::Model::FreshclamStatus',
           ];
}

# Method: compositeClasses
#
#       Return the composite classes used by the module
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [];
}



# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [];
}


# Method: enableService
#
#   Used to enable a service We have to verride this because squid needs a
#   notification of when the antivirus is enabled
#
# Parameters:
#
#   boolean - true to enable, false to disable
#
#  Overrides:
#      <EBox::Module::Service::enableService>
sub enableService
{
    my ($self, $status) = @_;
    defined $status or
        $status = 0;

    return unless ($self->isEnabled() xor $status);

    $self->SUPER::enableService($status);


    # notify squid of changes..
    #  this must be after status has chenged..
    my $global = EBox::Global->instance();
    if ($global->modExists('squid')) {
        my $squid = $global->modInstance('squid');
        $squid->notifyAntivirusEnabled();
    }



}

# Method: enableActions
#
#        Run those actions explain by <actions> to enable the module
#
# Overrides:
#
#        <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;
#     EBox::Sudo::root(EBox::Config::share() .
#                      '/ebox-antivirus/ebox-antivirus-enable');
}

# Method: disableActions
#
#        Rollback those actions performed by <enableActions> to
#        disable the module
#
# Overrides:
#
#        <EBox::Module::Service::disableActions>
#
sub disableActions
{

}

sub usedFiles
{
  return [
        {
         file => CLAMD_CONF_FILE,
         reason => __(' To configure clamd daemon'),
         module => 'antivirus',
        },
        {
           file => FRESHCLAM_CONF_FILE,
           reason => __('To configure freshclam updater'),
           module => 'antivirus',
       },
       {
           file => FRESHCLAM_CRON_SCRIPT,
           reason => __('To schedule the launch of the updater'),
           module => 'antivirus',
          },
         ];
}



sub _daemons
{
    return [
        {
            name => CLAMD_INIT,
            type => 'init.d',
            pidfiles => [CLAMAVPIDFILE],
        },
           ];

}

sub localSocket
{
  return CLAMD_SOCKET;
}



sub _setConf
{
  my ($self) = @_;

  my $localSocket = $self->localSocket();

  my @clamdParams = (
                localSocket => $localSocket,
               );

  $self->writeConfFile(CLAMD_CONF_FILE, "antivirus/clamd.conf.mas", \@clamdParams);

  $self->disableApparmorProfile('usr.sbin.clamd');


  my $observerScript = EBox::Config::share() . '/ebox-antivirus/' .  FRESHCLAM_OBSERVER_SCRIPT;

  my @freshclamParams = (
                         clamdConfFile   => CLAMD_CONF_FILE,
                         observerScript  => $observerScript,
                        );


  $self->writeConfFile(FRESHCLAM_CONF_FILE, "antivirus/freshclam.conf.mas", \@freshclamParams);

  if ($self->isEnabled()) {
    # regenerate freshclam cron hourly script
    EBox::Module::Base::writeConfFileNoCheck(FRESHCLAM_CRON_SCRIPT, "antivirus/freshclam-cron.mas", []);
    EBox::Sudo::root('chmod a+x ' . FRESHCLAM_CRON_SCRIPT);
    
  }
  else {
    # remove freshclam cron hourly entry
    my $rmCmd = 'rm -f ' . FRESHCLAM_CRON_SCRIPT;
    EBox::Sudo::root($rmCmd);
  }
}





# Method: freshclamState
#
#   get the last freshclam event
#  
#  Returns:
#     hash ref with the following fields
#       update - true if the last event was a succesful update
#       error  - true if the last event was a error
#       outdated  - contains a version number if the last event was a updte
#                   that recommend a updated version of engine. (in this case
#                   update field is not set to true)
#       date     - date of the last event
#
#    If there is not last recorded event it returns a empty hash
sub freshclamState
{
  my ($self) = @_;
  my @stateAttrs = qw(update error outdated date);

  my $freshclamStateFile = $self->freshclamStateFile();
  if (not -e $freshclamStateFile) {
    return { map {  ( $_ => undef )  } @stateAttrs  }; # freshclam has never updated before
  }

  my $fileContents  =  read_file($freshclamStateFile);
  my %state =  split ',', $fileContents, (@stateAttrs * 2);

  # checking state file coherence
  foreach my $attr (@stateAttrs) {
    exists $state{$attr} or throw EBox::Exceptions::Internal("Invalid freshclam state file. Missing attribute: $attr");
  }
  if ( scalar @stateAttrs !=  scalar keys %state) {
    throw EBox::Exceptions::Internal("Invalid fresclam state file: invalid attributes found. (valid attributes are @stateAttrs)");
  }


  return \%state;
}



sub freshclamEBoxDir
{
#    EBox::Config::conf() . 'freshclam';
    return '/var/lib/clamav';
}

sub freshclamStateFile
{
    return freshclamEBoxDir() . '/freshclam.state';
}



sub notifyFreshclamEvent
{
  my ($class, $event, $extraParam) = @_;

  my @validEvents = qw(update error outdated);
  if (not ($event eq any( @validEvents))) {
    $extraParam = defined $extraParam ? "with parameter $extraParam" : "";
    die ("Invalid freshclam event: $event $extraParam");
  }


  my $date = time();
  my $update   = 0;
  my $outdated = 0;
  my $error    = 0;


  if ($event eq 'update') {
    $update = 1;
  }
  elsif ($event eq  'error') {
    $error = 1;
  }
  elsif ($event eq 'outdated') {
    $outdated = $extraParam; # $extraPAram = last version

  }


  my $statePairs = "date,$date,update,$update,error,$error,outdated,$outdated";
  my $stateFile = $class->freshclamStateFile();
  write_file($stateFile, $statePairs);
}


sub firewallHelper
{
    my ($self) = @_;
    if ($self->isEnabled()) {
        return EBox::AntiVirus::FirewallHelper->new();
    }

    return undef;
}


sub summary
{
    my ($self, $summary) = @_;

    my $section = new EBox::Dashboard::Section(__("Antivirus"));
    $summary->add($section);

    my $antivirus = new EBox::Dashboard::ModuleStatus(
        module        => 'antivirus',
        printableName => __('Antivirus'),
        enabled       => $self->isEnabled(),
        running       => $self->isRunning(),
        nobutton      => 0);
    $section->add($antivirus);
}


# Method: report
#
#  Returns:
#    hash ref with the keys:
#      freshclamEvent - one of 'update', 'outdated', 'error' or 'uninitialized'
#      clamVersionRequested - new clam version requested by the 'outdated'
#                             event. This key does not exist in other events
#      freshclamEventTimestamp - timestamp of the last event. Undef if there was not last event
#
# Overrides: 
#   <EBox::Module::Base::report>
sub report
{    
    my ($self) = @_;
    my $state = $self->freshclamState();

    my $timeStamp = delete $state->{date};

    my $event = 'uninitialized';
    my $eventInfo;
    # select which event is active if a event has happened
    while (($event, $eventInfo) = each %{ $state } ) {
        if ($eventInfo) {
            last;
        }
    }

    my $report = {
       freshclamEvent => $event,
       freshclamEventTimestamp => $timeStamp,
    };

    if ($event eq 'outdated') {
        $report->{clamVersionRequested} = $eventInfo,
    }
    

    return $report;
}

1;

