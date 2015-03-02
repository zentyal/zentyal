# Copyright (C) 2009-2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::AntiVirus;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::LogObserver);

use Perl6::Junction qw(any);
use File::Slurp qw(read_file write_file);
use File::ReadBackwards;

use EBox::AntiVirus::FirewallHelper;
use EBox::AntiVirus::LogHelper;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Service;
use EBox::Exceptions::Internal;

use constant CLAMAV_PID_DIR => '/var/run/clamav/';

use constant {
  CLAMAVPIDFILE                 => CLAMAV_PID_DIR . 'clamd.pid',
  CLAMD_INIT                    => 'clamav-daemon',
  CLAMD_CONF_FILE               => '/etc/clamav/clamd.conf',
  CLAMD_SOCKET                  => CLAMAV_PID_DIR . 'clamd.ctl',

  FRESHCLAM_CONF_FILE           => '/etc/clamav/freshclam.conf',
  FRESHCLAM_OBSERVER_SCRIPT     => 'freshclam-observer',
  FRESHCLAM_CRON_FILE           => '/etc/cron.d/clamav-freshclam',
  FRESHCLAM_DIR                 => '/var/lib/clamav/',
  FRESHCLAM_LOG_FILE            => '/var/log/clamav/freshclam.log',
  FRESHCLAM_USER                => 'clamav',
};

use constant APPARMOR_D => '/etc/apparmor.d/';
use constant {
    APPARMOR_FRESHCLAM => APPARMOR_D . 'local/usr.bin.freshclam',
    APPARMOR_CLAMD     => APPARMOR_D . 'usr.sbin.clamd',
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
                                      printableName => __('Antivirus'),
                                      @_);
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

# TODO: replace model with dashboard widget?
#    my $item = new EBox::Menu::Item('name' => 'AntiVirus',
#                                    'icon' => 'antivirus',
#                                    'text' => $self->printableName(),
#                                    'separator' => 'Office',
#                                    'order' => 580,
#                                    'url' => 'AntiVirus/View/FreshclamStatus',
#                                   );
#
#    $root->add($item);
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

# Method: appArmorProfiles
#
#   Overrides to set the local AppArmor profile to allow freshclam
#   notification to Antivirus package
#
# Overrides:
#
#    <EBox::Module::Base::appArmorProfiles>
#
sub appArmorProfiles
{
    my ($self) = @_;

    my $observerScript = EBox::Config::share() . 'zentyal-antivirus/' . FRESHCLAM_OBSERVER_SCRIPT;

    my @params = ( 'observerScript' => $observerScript);

    return [
        { 'binary' => 'usr.bin.freshclam',
          'local'  => 1,
          'file'   => 'antivirus/freshclam.profile.mas',
          'params' => \@params },
       ];
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
            reason => __('To schedule the launch of the updater'),
            module => 'antivirus',
        },
        {
            file   => APPARMOR_FRESHCLAM,
            reason => __x('Custom {app} profile configuration '
                          . 'for {bin} binary',
                          app => 'AppArmor', bin => 'freshclam'),
            module => 'antivirus',
        },
        {
            file   => APPARMOR_CLAMD,
            reason => __x('Disable {app} profile for {bin} binary',
                          app => 'AppArmor', bin => 'clamd'),
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

# Method: _daemonsToDisable
#
# Overrides:
#
#   <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [ { 'name' => 'clamav-freshclam', 'type' => 'init.d' } ];
}


sub localSocket
{
    return CLAMD_SOCKET;
}

# Method: _postSetConfHook
#
# Overrides:
#
#      <EBox::Module::Base::_postSetConfHook>
#
sub _postSetConfHook
{
    my ($self) = @_;

    # Run Freshclam first time so it works right away
    EBox::Sudo::silentRoot("/usr/bin/freshclam --quiet");

    $self->SUPER::_postSetConfHook();
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $localSocket = $self->localSocket();

    my @clamdParams = (
            localSocket => $localSocket,
            );

    $self->writeConfFile(CLAMD_CONF_FILE, "antivirus/clamd.conf.mas", \@clamdParams);

    $self->disableApparmorProfile('usr.sbin.clamd');

    my $observerScript = EBox::Config::share() . 'zentyal-antivirus/' . FRESHCLAM_OBSERVER_SCRIPT;

    my $network = EBox::Global->modInstance('network');
    my $proxy = $network->model('Proxy');
    my @freshclamParams = (
            clamdConfFile   => CLAMD_CONF_FILE,
            observerScript  => $observerScript,
            proxyServer => $proxy->serverValue(),
            proxyPort => $proxy->portValue(),
            proxyUser => $proxy->usernameValue(),
            proxyPasswd => $proxy->passwordValue(),
            );

    $self->writeConfFile(FRESHCLAM_CONF_FILE,
            "antivirus/freshclam.conf.mas", \@freshclamParams);

    # Regenerate freshclam cron hourly script
    $self->writeConfFile(FRESHCLAM_CRON_FILE,
                         'antivirus/clamav-freshclam.cron.mas',
                         [ enabled => $self->isEnabled() ]);
}

# Method: freshclamState
#
#   get the last freshclam event
#
#  Returns:
#     hash ref with the following fields
#       update - true if the last event was a succesful update
#       error  - true if the last event was a error
#       outdated  - contains a version number if the last event was an update
#                   that recommends an updated version of engine. (in this case
#                   update field is not set to true)
#       date     - date of the last event
#
#    If there is not last recorded event it returns a empty hash.
#
sub freshclamState
{
    my ($self) = @_;

    my @stateAttrs = qw(update error outdated date);

    my $emptyRes = { map {  ( $_ => undef )  } @stateAttrs  };
    my $freshclamStateFile = $self->freshclamStateFile();
    if (not -e $freshclamStateFile) {
        return $emptyRes; # freshclam has never updated before
    }

    my $file = new File::ReadBackwards($freshclamStateFile);
    my $lastLine = $file->readline();
    if ($lastLine eq "") {
        # Empty file
        return $emptyRes;
    }
    my %state = split(',', $lastLine, (@stateAttrs * 2));

    # checking state file coherence
    foreach my $attr (@stateAttrs) {
        exists $state{$attr} or throw EBox::Exceptions::Internal("Invalid freshclam state file. Missing attribute: $attr");
    }
    if ( scalar @stateAttrs != scalar keys %state) {
        throw EBox::Exceptions::Internal("Invalid fresclam state file: invalid attributes found. (valid attributes are @stateAttrs)");
    }

    return \%state;
}

sub freshclamEBoxDir
{
    return FRESHCLAM_DIR;
}

# Class method: freshclamStateFile
#
# Returns:
#
#      String - the path to freshclam state file path
#
sub freshclamStateFile
{
    return EBox::AntiVirus::LogHelper::FRESHCLAM_STATE_FILE;
}

# Class Method: notifyFreshclamEvent
#
#     Got notified from a freshclam event and store the state in
#     /var/lib/clamav/freshclam.state file. This is called by
#     freshclam-observer script which is called by freshclam after an
#     attempt of updating the AV Data Base
#
# Parameters:
#
#     event - String the freshclam event. Valid ones are: update, error, outdated
#
#     extraParam - String extra parameters (only expected last version
#                  for outdated event)
#
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
    } elsif ($event eq 'error') {
        $error = 1;
    } elsif ($event eq 'outdated') {
        $outdated = $extraParam; # $extraParam = last version
    }

    my $statePairs = "date,$date,update,$update,error,$error,outdated,$outdated\n";
    my $stateFile = $class->freshclamStateFile();
    write_file($stateFile, { append => 1 }, $statePairs);
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

# Implement LogObserver interface

# Method: logHelper
#
# Overrides:
#
#     <EBox::LogObserver::logHelper>
#
sub logHelper
{
    return (new EBox::AntiVirus::LogHelper());
}

# Method: tableInfo
#
# Overrides:
#
#     <EBox::LogObserver::tableInfo>
#
sub tableInfo
{
    my $titles = {
        'timestamp' => __('Date'),
        'source'    => __('Source'),
        'event'     => __('Event')
       };
    my @order  = ('timestamp', 'source', 'event' );
    my @filter = ('source');
    my $events = { 'success' => __('Success'), 'failure' => __('Failure') };

    return [{
        'name'      => __('Antivirus DB updates'),
        'tablename' => 'av_db_updates',
        'titles'    => $titles,
        'order'     => \@order,
        'timecol'   => 'timestamp',
        'filter'    => \@filter,
        'events'    => $events,
        'eventcol'  => 'event',
    }];
}

1;
