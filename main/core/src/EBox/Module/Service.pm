# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Module::Service;

use base qw(EBox::Module::Config);

use EBox::Global;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Global;
use EBox::Dashboard::ModuleStatus;
use EBox::Sudo;
use EBox::AuditLogging;
use EBox::Gettext;

use Perl6::Junction qw(any);
use TryCatch;

# Method: usedFiles
#
#   This method is mainly used to show information to the user
#   about the files which are going to be modified by the service
#   managed by Zentyal
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       file - file's path
#       reason - some info about why you need to modify the file
#       module - module's name
#
#   Example:
#
#       [
#           {
#             'file' => '/etc/samba/smb.conf',
#             'reason' =>  __('The file sharing module needs to modify it' .
#                           ' to configure samba properly')
#              'module' => samba
#           }
#       ]
#
#
sub usedFiles
{
    return [];
}

# Method: actions
#
#   This method is mainly used to show information to the user
#   about the actions that need to be carried out by the service
#   to configure the system
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       action - action to carry out
#       reason - some info about why you need to modify the file
#       module - module's name
#
#   Example:
#
#       [
#           {
#             'action' => 'remove samba init script"
#             'reason' =>
#                   __('Zentyal will take care of start and stop the service')
#             'module' => samba
#           }
#       ]
#
#
sub actions
{
    return [];
}

# Method: enableActions
#
#   This method is run to carry out the actions that are needed to
#   enable a module. It usually executes those which are returned
#   by actions.
#
#   For example: it could remove the samba init script
#
#   The default implementation is to call the following
#   script if exists and has execution rights:
#      /usr/share/zentyal-$module/enable-module
#
#   But this method can be overriden by any module.
#
sub enableActions
{
    my ($self) = @_;

    my $path = EBox::Config::share();
    my $modname = $self->{'name'};

    my $command = "$path/zentyal-$modname/enable-module";
    if (-x $command) {
        EBox::Sudo::root($command);
    }
}

# Method: disableActions
#
#   This method is run to rollbackthe actions that have been carried out
#   to enable a module.
#
#   For example: it could restore the samba init script
#
#
sub disableActions
{

}

# Method: disableModDepends
#
#   This method is used to get the list of modules to be disabled when this
#   module is disabled (they depend on us).
#
#   It doesn't state a configuration dependency, it states a working
#   dependency.
#
#   For example: the firewall module has to be disabled together with the
#                network module.
#
# Returns:
#
#    array ref containing the  modules names
#
sub disableModDepends
{
    my ($self) = @_;
    my $name = $self->name();
    my $global = $self->global;

    my @deps = ();
    foreach my $mod (@{$global->modInstancesOfType('EBox::Module::Service')}) {
        if ($name eq any @{$mod->enableModDepends()}) {
            push @deps, $mod;
        }
    }
    my @names = map { $_->name } @deps;
    return \@names;
}

# Method: enableModDepends
#
#   This method is used to declare which modules need to be enabled
#   to use this module.
#
#   It doesn't state a configuration dependency, it states a working
#   dependency.
#
#   For example: the firewall module needs the network module.
#
#   By default it returns the modules established in the enabledepends list
#   in the module YAML file. Override the method if you need something more
#   specific, e.g., having a dynamic list.
#
# Returns:
#
#    - array ref containing the dependencies names.
#
#    Example:
#
#       [ 'firewall', 'samba' ]
#
sub enableModDepends
{
    my ($self) = @_;
    my $depends = $self->info()->{'enabledepends'};
    if(not defined($depends)) {
        return [];
    } else {
        return $depends;
    }
}

# Method: enableModDependsRecursive
#
#   This method works like enableModDepends but its recurse in all module dependencies
#
# Returns:
#
#    - list reference with the dependencies names
sub enableModDependsRecursive
{
    my ($self) = @_;
    my $global = $self->global();
    my %depends;
    my @toCheck = @{ $self->enableModDepends() };
    for (my $i=0; $i < @toCheck; $i++) {
        my $modName = $toCheck[$i];
        if (exists $depends{$modName}) {
            next;
        }
        my $mod = $global->modInstance($modName);
        $mod->isa('EBox::Module::Service') or next;
        $depends{$modName}  = $mod;
        push @toCheck, @{ $mod->enableModDepends() };
    }

    my $name = $self->name();
    my @depNames = map {
        my $modName = $_->name();
        ($modName ne $name) ? ($modName) : ();
    } @{ $global->sortModulesEnableModDepends([$self, values %depends]) };

    return \@depNames;
}


# Method: bootDepends
#
#   This method is used to declare which modules need to have its
#   daemons started before this module ones.
#
#   It doesn't state a configuration dependency, it states a boot
#   dependency.
#
#   For example: the samba module needs the printer daemon started before.
#
#   By default it returns the modules established in the bootdepends list
#   in the module YAML file. Override the method if you need something more
#   specific, e.g., having a dynamic list. If nothing is specified in the
#   YAML file nor the method is overriden, the enabledepends value is
#   returned to provide compatibility with the previous behavior.
#
# Returns:
#
#    array ref containing the dependencies.
#
#    Example:
#
#       [ 'firewall', 'samba' ]
#
sub bootDepends
{
    my ($self) = @_;
    my $depends = $self->info()->{'bootdepends'};
    if(not defined($depends)) {
        return $self->enableModDepends();
    } else {
        return $depends;
    }
}

# Method: configured
#
#   This method is used to check if the module has been configured.
#   Configuration is done one time per service package version.
#
#   If this method returns true it means that the user has accepted
#   to carry out the actions and file modifications that enabling a
#   service implies.
#
#   If you must store this value in the status branch of conf in case
#   you decide to override it.
#
# Returns:
#
#   boolean
#
sub configured
{
    my ($self) = @_;

    if ((@{$self->usedFiles()} + @{$self->actions()}) == 0) {
        return 1;
    }

    if (-d EBox::Config::conf() . "configured/") {
        return -f (EBox::Config::conf() . "configured/" . $self->name());
    }

    return $self->st_get_bool('_serviceConfigured');
}

# Method: setConfigured
#
#   This method is used to set if the module has been configured.
#   Configuration is done once per service package version.
#
#   If it's set to true it means that the user has accepted
#   to carry out the actions and file modifications that enabling a
#   service implies.
#
#   If you must store this value in the status branch of conf in case
#   you decide to override it.
#
# Parameters:
#
#   boolean - true if configured, false otherwise
#
sub setConfigured
{
    my ($self, $status) = @_;
    defined $status or
        $status = 0;

    return unless ($self->configured() xor $status);

    if (-d EBox::Config::conf() . "configured/") {
        if ($status) {
            EBox::Sudo::command('touch ' . EBox::Config::conf() . "configured/" . $self->name());
        } else {
            EBox::Sudo::command('rm -f ' . EBox::Config::conf() . "configured/" . $self->name());
            $self->setNeedsSaveAfterConfig(undef);
        }
    }

    # clear log cache info because tables could have been added or removed
    my $logs = $self->global()->modInstance('logs');
    if ($logs) {
        $logs->clearTableInfoCache();
    }

    return $self->st_set_bool('_serviceConfigured', $status);
}

# Method: firstInstall
#
#   This method is used to check if the module has been recently installed
#   and has not saved changes yet. This is useful to control which modules
#   have been configured through wizards.
#
# Returns:
#
#   boolean
#
sub firstInstall
{
    my ($self) = @_;

    if ($self->st_get_bool('_serviceInstalled')) {
        return 0;
    }

    return 1;
}

sub configureModule
{
    my ($self) = @_;
    my $needsSaveAfterConfig = $self->needsSaveAfterConfig();
    try {
        $self->setConfigured(1);
        #$self->updateModuleDigests($modName);
        $self->_overrideDaemons();
        $self->enableActions();
        $self->enableService(1);
        $self->setNeedsSaveAfterConfig(1) if not defined $needsSaveAfterConfig;
    } catch ($e) {
        $self->setConfigured(0);
        $self->enableService(0);
        $self->setNeedsSaveAfterConfig(undef);
        $e->throw();
    }
}

sub setNeedsSaveAfterConfig
{
    my ($self, $needsSave) = @_;
    my $state = $self->get_state();
    $state->{_needsSaveAfterConfig} = $needsSave;
    $self->set_state($state);
}

sub needsSaveAfterConfig
{
    my ($self) = @_;
    if (not $self->configured()) {
        return undef;
    }

    my $state = $self->get_state();
    return  $state->{_needsSaveAfterConfig};
}

# Method: setInstalled
#
#   This method is used to set if the module has been installed
#
#   If it's set to true it means that the module has been installed
#   Call this method is only necessary on first install of the module.
#
sub setInstalled
{
    my ($self) = @_;

    return $self->st_set_bool('_serviceInstalled', 1);
}

# Method: isEnabled
#
#   Used to tell if a module is enabled or not
#
# Returns:
#
#   boolean
sub isEnabled
{
    my ($self) = @_;

    return 0 if ($self->{name} ne 'network') and (EBox::Global->edition() eq 'trial-expired');

    my $enabled = $self->get_bool('_serviceModuleStatus');
    if (not defined($enabled)) {
        return $self->defaultStatus();
    }

    return $enabled;
}

sub disabledModuleWarning
{
    my ($self) = @_;
    if ($self->isEnabled()) {
        return '';
    } else {
        # TODO: If someday we implement the auto-enable for dependencies with one single click
        # we could replace the Module Status link with a "Click here to enable it" one
        return __x("{mod} module is disabled. Don't forget to enable it on the {oh}Module Status{ch} section, otherwise your changes won't have any effect.",
                   mod => $self->printableName(), oh => '<a href="/ServiceModule/StatusView">', ch => '</a>');
    }
}

# Method: _isDaemonRunning
#
#   Used to tell if a daemon is running or not
#
# Returns:
#
#   boolean - true if it's running otherwise false
sub _isDaemonRunning
{
    my ($self, $dname) = @_;

    my $daemons = $self->_daemons();
    my ($daemon) = grep { $_->{'name'} eq $dname } @{$daemons};
    unless (defined $daemon) {
        my $modname = $self->name();
        throw EBox::Exceptions::Internal("Daemon $dname is not defined in $modname module");
    }

    if ($daemon->{'pidfiles'}) {
        foreach my $pidfile (@{$daemon->{'pidfiles'}}) {
            unless ($self->pidFileRunning($pidfile)) {
                return 0;
            }
        }
        return 1;
    }

    if ($daemon->{'status'}) {
        $dname = $daemon->{'status'};
    }

    if (daemon_type($daemon) eq 'systemd') {
        try {
            return EBox::Service::running($dname);
        } catch (EBox::Exceptions::Internal $e) {
            return 0;
        }
    } elsif (daemon_type($daemon) eq 'init.d') {
        my $output = EBox::Sudo::silentRoot("service $dname status");
        if ($? != 0) {
            return 0;
        }
        my $status = join ("\n", @{$output});
        if ($status =~ m{$dname .* running}) {
            return 1;
        } elsif ($status =~ m{$dname .* \[ RUNNING \]}) {
            return 1;
        } elsif ($status =~ m{ is running}) {
            return 1;
        } elsif ($status =~ m{$dname .* \[ OK \]}) {
            return 1;
        } elsif ($status =~ m{$dname .*done}s) {
            return 1;
        } else {
            return 0;
        }
    } else {
        throw EBox::Exceptions::Internal("Service type must be either 'systemd' or 'init.d'");
    }
}

# Method: isRunning
#
#   Used to tell if a service is running or not.
#
#   Modules with complex service management must
#   override this method to carry out their custom checks which can
#   involve checking an systemd script, an existing PID...
#
#   By default it returns true if all the system services specified in
#   daemons are running
#
# Returns:
#
#   boolean - true if it's running otherwise false
sub isRunning
{
    my ($self) = @_;

    my $activeDaemons = 0;
    my $daemons = $self->_daemons();
    for my $daemon (@{$daemons}) {
        my $pre = $daemon->{'precondition'};
        if (defined ($pre)) {
            # don't check if daemon should not be running
            next unless $pre->($self);
        }

        $activeDaemons = 1;
        unless ($self->_isDaemonRunning($daemon->{'name'})) {
            return 0;
        }
    }

    if ($activeDaemons) {
        return 1;
    } else {
        return $self->isEnabled();
    }
}

# Method: addModuleStatus
#
#   Called by the sysinfo module status widget to give the desired information
#   about the current module status. This default implementation should be ok
#   for most modules but it can be overriden to provide a custom one (or none).
#
# Parameters:
#
#   section - the section the information is added to
#
sub addModuleStatus
{
    my ($self, $section) = @_;

    my $enabled = $self->isEnabled();
    my $running = $self->isRunning();
    my $name = $self->name();
    my $modPrintName = ucfirst($self->printableName());
    my $nobutton;
    if ($self->_supportActions()) {
        $nobutton = 0;
    } else {
        $nobutton = 1;
    }
    $section->add(new EBox::Dashboard::ModuleStatus(
        module        => $name,
        printableName => $modPrintName,
        enabled       => $enabled,
        running       => $running,
        nobutton      => $nobutton,
       ));
}

# Method: enableService
#
#   Used to enable a service
#
# Parameters:
#
#   boolean - true to enable, false to disable
#
sub enableService
{
    my ($self, $status) = @_;

    defined $status or
        $status = 0;

    return unless ($self->isEnabled() xor $status);

    # If enabling the module check our dependences are also enabled
    # Otherwise, we have to disable ourself and all modules depending on us
    if ($status) {
        foreach my $mod (@{$self->enableModDepends()}) {
            my $instance = $self->global()->modInstance($mod);
            $status = ($status and $instance->isEnabled());
        }
    }

    unless ($status) {
        # Disable all modules that depends on us
        my $global = $self->global();
        my $revDepends = $self->disableModDepends();
        foreach my $depName (@{$revDepends}) {
            my $instance = $global->modInstance($depName);
            $instance->enableService(0);
        }
    }

    $self->set_bool('_serviceModuleStatus', $status);

    # FIXME: Move this to an observer pattern
    my $audit = EBox::Global->modInstance('audit');
    if (defined ($audit)) {
        my $action = $status ? 'enableService' : 'disableService';
        $audit->logAction('global', 'Module Status', $action, $self->{name});
    }
    my $ha = $self->global()->modInstance('ha');
    if (defined($ha)) {
        $ha->setIfSingleInstanceModule($self->name());
    }

}

# Method: defaultStatus
#
#   This method must be overriden if you want to enable the service by default
#
# Returns:
#
#   boolean
sub defaultStatus
{
    return 0;
}

sub daemon_type
{
    my ($daemon) = @_;
    if($daemon->{'type'}) {
        return $daemon->{'type'};
    } else {
        return 'systemd';
    }
}

# Method: showModuleStatus
#
#   Indicate to ServiceManager if the module must be shown in Module
#   status configuration.
#
#   It must be overridden in rare cases such as the module is not
#   enabled manually.
#
# Returns:
#
#   true
#
sub showModuleStatus
{
    return 1;
}

# Method: _daemons
#
#   This method must be overriden to return the services required by this
#   module.
#
# Returns:
#
#   An array of hashes containing keys 'name' and 'type', 'name' being the
#   name of the service and 'type' either 'systemd' or 'init.d', depending
#   on how the module should be managed.
#
#   If the type is 'init.d' an extra 'pidfiles' key is needed with the paths
#   to the pid files the daemon uses. This will be used to check the status.
#
#   It can optionally contain a key 'precondition', which should be a reference
#   to a class method which will be checked to determine if the given daemon
#   should be run (if it returns true) or not (otherwise).
#
#   Example:
#
#   sub externalConnection
#   {
#     my ($self) = @_;
#     return $self->isExternal;
#   }
#
#   sub _daemons
#   {
#    return [
#        {
#            'name' => 'ebox.jabber.jabber-router',
#            'type' => 'systemd'
#        },
#        {
#            'name' => 'ebox.jabber.jabber-resolver',
#            'type' => 'systemd',
#            'precondition' => \&externalConnection
#        }
#    ];
#   }
sub _daemons
{
    return [];
}

sub _startDaemon
{
    my ($self, $daemon, %params) = @_;

    my $action = 'start';
    if ($self->_isDaemonRunning($daemon->{name})) {
        $action = $params{reload} ? 'reload' : 'restart';
    }

    $self->_manageDaemon($daemon, $action);
}

sub _stopDaemon
{
    my ($self, $daemon) = @_;

    $self->_manageDaemon($daemon, 'stop');
}

sub _manageDaemon
{
    my ($self, $daemon, $action) = @_;

    my $dname = $daemon->{name};
    my $type = daemon_type($daemon);

    if ($type eq 'systemd') {
        EBox::Service::manage($dname, $action);
    } elsif ($type eq 'init.d') {
        EBox::Sudo::root("service $dname $action");
    } else {
        throw EBox::Exceptions::Internal("Service type must be either 'systemd' or 'init.d'");
    }
}

# Method: _manageService
#
#   This method will try to perform the action passed as first argument on
#   all the daemons return by the module's daemons method.
#
sub _manageService
{
    my ($self, $action, %params) = @_;

    my $daemons = $self->_daemons();
    for my $daemon (@{$daemons}) {
        my $run = 1;
        my $pre = $daemon->{'precondition'};
        if(defined($pre)) {
            $run = &$pre($self);
        }
        #even if parameter is 'start' we might have to stop some daemons
        #if they are no longer needed
        if(($action eq 'start') and $run) {
            $self->_startDaemon($daemon, %params);
        } else {
            $self->_stopDaemon($daemon, %params);
        }
    }
}

# Method: _startService
#
#   This method will try to start or restart all the daemons associated to
#   the module
#
#   If the module was temporary stopped and restartModules parameter
#   is true, then it is removed and restart firewall module if the
#   module is a firewall observer analogously to <stopService>. This
#   is done *after* the module is stopped.
#
# Named parameters:
#
#   restartModules - Boolean indicating we can restart modules if required
#
sub _startService
{
    my ($self, %params) = @_;
    $self->_manageService('start', %params);

    # Firewall observer restart, if necessary
    my $temporaryStopped = $self->temporaryStopped();
    $self->setTemporaryStopped(0); # Do it here to make Firewall helper to work
    my $global   = $self->global();
    if ($self->isa('EBox::FirewallObserver')) {
        my $fwHelper = $self->firewallHelper();
        if ($params{restartModules} and $temporaryStopped
            and $global->modExists('firewall')
            and $global->modInstance('firewall')->isEnabled()
            and $fwHelper->can('restartOnTemporaryStop')
            and $fwHelper->restartOnTemporaryStop()) {
            my $fw = $global->modInstance('firewall');
            $fw->restartService();
        }
    }

    # Notify observers
    my @observers = @{$global->modInstancesOfType('EBox::Module::Service::Observer')};
    foreach my $obs (@observers) {
        $obs->serviceStarted($self);
    }
}

# Method: stopService
#
#   This is the external interface to call the implementation which lies in
#   _stopService in subclassess
#
#   If restoreModules parameter is true, the module is a firewall
#   observer and firewall module is enabled, then firewall module is
#   restarted. This is done *before* the module is stopped.
#
# Named parameters:
#
#   restartModules - Boolean indicating if the module is a firewall
#                    observer, then it performs the firewall restart
#                    after stopping the module.
#
#   temporaryStopped - *optional* mark as stopped from commandline
#
sub stopService
{
    my ($self, %params) = @_;

    $self->setTemporaryStopped(1) if $params{temporaryStopped};
    my $global   = $self->global();
    if ($self->isa('EBox::FirewallObserver')) {
        my $fwHelper = $self->firewallHelper();
        if ($params{restartModules}
            and $global->modExists('firewall')
            and $global->modInstance('firewall')->isEnabled()
            and defined ($fwHelper)
            and $fwHelper->can('restartOnTemporaryStop')
            and $fwHelper->restartOnTemporaryStop()) {
            my $fw = $global->modInstance('firewall');
            $fw->restartService();
        }
    }

    $self->_lock();
    try {
        $self->_stopService(%params);
    } catch ($e) {
        $self->_unlock();
        $e->throw();
    }
    $self->_unlock();
}


# Method: setTemporaryStopped
#
#   The goal for the module is to be stopped or not. This is different
#   from enabled as the module is enabled but momently stopped.
#
# Parameters:
#
#   stopped - Boolean the goal is to be stopped or not
#
sub setTemporaryStopped
{
    my ($self, $stopped) = @_;

    my $state = $self->get_state();
    $state->{_temporary_stopped} = $stopped;
    $self->set_state($state);
}


# Method: temporaryStopped
#
#   Get if the goal for the module is to be stopped or not. This is
#   different from enabled as the module is enabled but temporary
#   stopped.
#
#   The module must be enabled to be temporary stopped.
#
# Returns:
#
#   Boolean - the goal is to be stopped or not
#
sub temporaryStopped
{
    my ($self) = @_;

    return ($self->isEnabled() and $self->get_state()->{_temporary_stopped});
}


# Method: _stopService
#
#   This method will try to stop all the daemons associated to the module
#
sub _stopService
{
    my ($self) = @_;
    $self->_manageService('stop');
}

sub _preServiceHook
{
    my ($self, $enabled) = @_;
    $self->_hook('preservice', $enabled);
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;
    $self->_hook('postservice', $enabled);
}

# Method: _regenConfig
#
#       Base method to regenerate configuration. It should NOT be overriden
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    $self->SUPER::_regenConfig(@_);
    my $enabled = ($self->isEnabled() or 0);
    if ($enabled) {
        $self->setNeedsSaveAfterConfig(0);
    }

    $self->_preServiceHook($enabled);
    $self->_enforceServiceState(@_);
    $self->_postServiceHook($enabled);
}

# Method: restartService
#
#        This method will try to restart the module's service by means of
#        calling _regenConfig. The method call has the named
#        parameter restart with true value
#
sub restartService
{
    my ($self, @params) = @_;

    $self->_lock();
    my $global = EBox::Global->getInstance();
    my $log = EBox::logger;

    $log->info("Restarting service for module: " . $self->name);
    try {
        $self->_regenConfig('restart' => 1, @params);
    } catch ($e) {
        $log->error("Error restarting service: $e");
        $self->_unlock();
        EBox::Exceptions::Internal->throw("$e");
    }
    $self->_unlock();
}

# Method: _supportActions
#
#   This method determines if the service will have a button to start/restart
#   it in the module status widget. By default services will have the button
#   unless this method is overriden to return undef
sub _supportActions
{
    return 1;
}

# Method: _enforceServiceState
#
#   This method will start, restart or stop the associated daemons to
#   bring them to their desired state. If you need specific behaviour
#   override this method in your module.
#
sub _enforceServiceState
{
    my ($self, @params) = @_;
    if($self->isEnabled()) {
        $self->_startService(@params);
    } else {
        $self->_stopService(@params);
    }
}

#
# Method: writeConfFile
#
#    It executes a given mason component with the passed parameters over
#    a file. It becomes handy to set configuration files for services.
#    Also, its file permissions will be kept.
#    It can be called as class method. (XXX: this design or is an implementation accident?)
#    XXX : the correct behaviour will be to throw exceptions if file will not be stated and no defaults are provided. It will provide hardcored defaults instead because we need to be backwards-compatible
#
#
# Parameters:
#
#    file      - file name which will be overwritten with the execution output
#    component - mason component
#    params    - parameters for the mason component. Optional. Defaults to no parameters
#    defaults  - a reference to hash with keys: mode, uid and gid. Those values will be used when creating a new file. (If the file already exists the existent values of these parameters will be left untouched)
#
sub writeConfFile # (file, component, params, defaults)
{
    my ($self, $file, $compname, $params, $defaults) = @_;
    EBox::Module::Base::writeConfFileNoCheck($file, $compname, $params, $defaults);
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issuefor this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       serviceId - name of the servicr
#       service - printable name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#       includeCA - whether needs CA to be included (default: false)
#
#   Example:
#
#       [
#           {
#             'serviceId' => 'jabberd2',
#             'service' => __('Jabber daemon)',
#             'path' => '/etc/jabberd2/ebox.pem',
#             'user' => 'jabber',
#             'group' => 'jabber',
#             'mode' => '0640'
#           }
#       ]
#
sub certificates
{
    return [];
}

# Method: disableApparmorProfile
#
#   This method is used to disable a given
#   apparmor profile.
#
#   It does nothing if apparmor or the profile
#   are not installed.
#
# Parameters:
#
#   string - apparmor profile
sub disableApparmorProfile
{
    my ($self, $profile) = @_;

    if (-f '/etc/init.d/apparmor') {
        my $profPath = "/etc/apparmor.d/$profile";
        my $disPath = "/etc/apparmor.d/disable/$profile";
        if (-f $profPath and not -f $disPath) {
            unless ( -d '/etc/apparmor.d/disable' ) {
                EBox::Sudo::root('mkdir /etc/apparmor.d/disable');
            }
            my $cmd = "ln -s $profPath $disPath";
            EBox::Sudo::root($cmd);
            EBox::Sudo::root('service apparmor restart');
        }
    }
}

# Method: _daemonsToDisable
#
#   This is like _daemons but only to specify those init scripts
#   that need to be stopped and disabled when enabling the module.
#
sub _daemonsToDisable
{
    return [];
}

sub _overrideDaemons
{
    my ($self) = @_;

    my @daemons = @{$self->_daemonsToDisable()};

    my @cmds;
    foreach my $daemon (@daemons) {
        push (@cmds, "systemctl stop $daemon->{name}");
    }
    EBox::Sudo::silentRoot(@cmds);

    @cmds = ();
    push (@daemons, @{$self->_daemons()});
    foreach my $daemon (@daemons) {
        push (@cmds, "systemctl disable $daemon->{name}");
    }
    EBox::Sudo::silentRoot(@cmds);
}

1;
