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


package EBox::ModuleName;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
           );

use EBox::Gettext;
use EBox::Service;
#use EBox::Dashboard::Module;

use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Global;


use constant {
  CLAMAVPIDFILE                 => '/var/run/clamav/clamd.pid',
  CLAMD_INIT                    => '/etc/init.d/clamav-daemon',
  CLAMD_SERVICE                  => 'ebox.clamd',
  CLAMD_CONF_FILE               => '/etc/clamav/ebox.clamd.conf',

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
#        <EBox::ModuleName> - the recently created module
#
sub _create
{
        my $class = shift;
        my $self = $class->SUPER::_create(name => 'antivirus',
                                          printableName => __('antivirus')
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
    my $folder = new EBox::Menu::Folder('name' => 'AntiVirus',
                                        'text' => $self->printableName());

    $folder->add(new EBox::Menu::Item('url' => 'AntiVirus/View/FresclamStatus',
                                      'text' => __(q{Update status})));

    $root->add($folder);
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
    root(EBox::Config::share() . '/ebox-antivirus/ebox-antivirus-enable');
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
  return (
        {
         file => CLAMD_CONF_FILE,
         reason => __(' To configure clamd daemon'),
         module => 'antivirus',
        },
          {
           file => FRESHCLAM_CONF_FILE,
           reason => __('To configure freshclam updater daemon'),
           module => 'anitvirus',
          },
         );
}



sub _daemons
{
    return [
            {
             name => CLAMD_SERVICE
            },
           ];
}

sub localSocket
{
  return CLAMD_SOCKET;
}



sub _writeConf
{
  my ($self) = @_;

  my $localSocket = $self->localSocket();

  my @clamdParams = (
                localSocket => $localSocket,
               );

  $self->writeConfFile(CLAMD_CONF_FILE, "antivirus/clamd.conf.mas", \@clamdParams);



  my $observerScript = EBox::Config::share() . '/ebox-antivirus/' .  FRESHCLAM_OBSERVER_SCRIPT;

  my @freshclamParams = (
                         clamdConfFile   => CLAMD_CONF_FILE,
                         observerScript  => $observerScript,
                        );


  $self->writeConfFile(FRESHCLAM_CONF_FILE, "antivirus/freshclam.conf.mas", \@freshclamParams);

  my $antivirusService = $self->service;
  if ($antivirusService) {
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



#   
#
#
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


#XXX fix
sub freshclamStateFile
{
  '/var/run/clamav/freshclam.state';
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
  write_file($class->freshclamStateFile(), $statePairs);
}


1;

