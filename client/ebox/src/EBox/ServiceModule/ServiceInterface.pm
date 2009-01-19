# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::ConfigurationFile::ServiceInterface
#
#   This class is meant to be used by those modules which are going
#   to modify configuration files
#
#   FIXME:
#
#   Among others: provide a method to set a default status
package EBox::ServiceModule::ServiceInterface;

use EBox::Global;
use EBox::Sudo;

use Error qw(:try);

use strict;
use warnings;

use constant INITDPATH => '/etc/init.d/';

# Method: usedFiles 
#
#   This method is mainly used to show information to the user
#   about the files which are going to be modified by the service
#   managed  by eBox
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
#                   __('eBox will take care of start and stop the service')
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
#
sub enableActions
{

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
# Returns:
#
#    array ref containing the dependencies.
#
#    Example:
#
#       [ 'firewall', 'users' ]
#
sub enableModDepends
{
    return [];
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
#   If you must store this value in the status branch of gconf in case
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


    my $gconf = $self->_gconfModule();
    unless (defined($gconf)) {
        throw EBox::Exceptions::Internal(
            "EBox::ServiceModule::ServiceInterface:configured() must be " .
            " overriden or " .
            " EBox::Service::Module::ServiceInterface::serviceModuleName must " .
            " return a valid gconf module");
    }

    if ($gconf->st_get_bool('_serviceConfigured') eq '') {
        return undef; 
    }

    return $gconf->st_get_bool('_serviceConfigured');
}

# Method: setConfigured 
#
#   This method is used to set if the module has been configured.
#   Configuration is done one time per service package version.
#
#   If it's set to true it means that the user has accepted
#   to carry out the actions and file modifications that enabling a
#   service implies.
#
#   If you must store this value in the status branch of gconf in case
#   you decide to override it.
#
# Parameters:
#
#   boolean - true if configured, false otherwise
#
sub setConfigured 
{
    my ($self, $status) = @_;

    my $gconf = $self->_gconfModule();
    unless (defined($gconf)) {
        throw EBox::Exceptions::Internal(
            "EBox::ServiceModule::ServiceInterface:setConfigured() must be " .
            " overriden or " .
            " EBox::Serice::Module::ServiceInterface::serviceModuleName must " .
            " return a valid gconf module");
    }

    return unless ($self->configured() xor $status);


    return $gconf->st_set_bool('_serviceConfigured', $status);
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

    my $gconf = $self->_gconfModule();
    unless (defined($gconf)) {
        throw EBox::Exceptions::Internal(
            "EBox::ServiceModule::ServiceInterface::isEnabled() must be " .
            " overriden or " .
            " EBox::Serice::Module::ServiceInterface::serviceModuleName must " .
            " return a valid gconf module");
    }

    if ($gconf->get_bool('_serviceModuleStatus') eq '') {
        return $self->defaultStatus();
    }

    return $gconf->get_bool('_serviceModuleStatus');
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

    my $daemon;
    my @ds = grep { $_->{'name'} eq $dname } @{$daemons};
    if(@ds) {
        $daemon = $ds[0];
    }
    if(!defined($daemon)) { 
        throw EBox::Exceptions::Internal(
            "no such daemon defined in this module: " . $dname);
    }
    if(defined($daemon->{'pidfile'})) {
        my $pidfile = $daemon->{'pidfile'};
        return $self->pidFileRunning($pidfile);
    }
    if(daemon_type($daemon) eq 'upstart') {
        return EBox::Service::running($daemon->{'name'});
    } elsif(daemon_type($daemon) eq 'init.d') {
        my $output = EBox::Sudo::root(INITDPATH . $daemon->{'name'} . ' ' . 'status');
        my $status = @{$output}[0];
        if ($status =~ m{^$daemon .* running}) {
            return 1;
        } else {
            return 0;
        }
    } else {
        throw EBox::Exceptions::Internal(
            "Service type must be either 'upstart' or 'init.d'");
    }
}

# Method: isRunning
#
#   Used to tell if a service is running or not.
#
#   Modules with complex service management must
#   override this method to carry out their custom checks which can
#   involve checking an upstart script, an existing PID...
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

    my $daemons = $self->_daemons();
    for my $daemon (@{$daemons}) {
        my $check = 1;
        my $pre = $daemon->{'precondition'};
        if(defined($pre)) {
            $check = $pre->($self);
        }
        $check or next;
        unless($self->_isDaemonRunning($daemon->{'name'})) {
            return undef;
        }
    }
    return 1;
}

# Method: enableService
#
#   Used to enable a service
#
# Paramters:
#
#   boolean - true to enable, false to disable
#
sub enableService
{
    my ($self, $status) = @_;

    my $gconf = $self->_gconfModule();
    unless (defined($gconf)) {
        throw EBox::Exceptions::Internal(
            "EBox::ServiceModule::ServiceInterface::enableService() must be " .
            " overriden or " .
            " EBox::Serice::Module::ServiceInterface::serviceModuleName must " .
            " return a valid gconf module");
    }

    return unless ($self->isEnabled() xor $status);

    $gconf->set_bool('_serviceModuleStatus', $status);
}

# Method: serviceModuleName
#
#   This method must be overriden if you want to automatically use the methods
#   isEnabled and enableService.
#
# Returns:
#
#   The name of a valid gconf module
sub serviceModuleName
{
    return undef;
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
    return undef;
}

sub daemon_type
{
    my ($daemon) = @_;
    if($daemon->{'type'}) {
        return $daemon->{'type'};
    } else {
        return 'upstart';
    }
}

# Method: _daemons
#
#   This method must be overriden to return the services required by this
#   module.
#
# Returns:
#
#   An array of hashes containing keys 'name' and 'type', 'name' being
#   the name of the service and 'type' either 'upstart' or 'init.d',
#   depending on how the module should be managed. 'upstart' is
#   assumed if 'type' key is not present.
#
#   If the type is 'init.d' an extra 'pidfile' key is needed with the path
#   to the pidfile the daemon uses. This will be used to check the status.
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
#     return $self->isExternal();
#   }
#
#   sub _daemons
#   {
#    return [
#        {
#            'name' => 'ebox.jabber.jabber-router',
#            'type' => 'upstart'
#        },
#        {
#            'name' => 'ebox.jabber.jabber-resolver',
#            'type' => 'upstart',
#            'precondition' => \&externalConnection
#        }
#    ];
#   }
sub _daemons
{
    return undef;
}

sub _startDaemon
{
    my($self, $daemon) = @_;
    my $action;
    if($self->_isDaemonRunning($daemon->{'name'})) {
        $action = 'restart';
    } else {
        $action = 'start';
    }
    if(daemon_type($daemon) eq 'upstart') {
        EBox::Service::manage($daemon->{'name'}, $action);
    } else {
        my $script = INITDPATH . $daemon->{'name'} . ' ' . $action;
        EBox::Sudo::root($script);
    }
}

sub _stopDaemon
{
    my($self, $daemon) = @_;
    if(daemon_type($daemon) eq 'upstart') {
        EBox::Service::manage($daemon->{'name'},'stop');
    } elsif(daemon_type($daemon) eq 'init.d') {
        my $script = INITDPATH . $daemon->{'name'} . ' ' . 'stop';
        EBox::Sudo::root($script);
    } else {
        throw EBox::Exceptions::Internal(
            "Service type must be either 'upstart' or 'init.d'");
    }
}

# Method: _manageService
#
#   This method will try to perform the action passed as first argument on 
#   all the daemons return by the module's daemons method.
#
sub _manageService
{
    my ($self,$action) = @_;

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
            $self->_startDaemon($daemon);
        } else {
            $self->_stopDaemon($daemon);
        }
    }
}

# Method: _startService
#
#   This method will try to start or restart all the daemons associated to
#   the module
#
sub _startService
{
    my ($self) = @_;
    $self->_manageService('start');
}

# Method: stopService
#
#   This is the external interface to call the implementation which lies in
#   _stopService in subclassess
#
#
sub stopService
{
    my $self = shift;

    $self->_lock();
    try {
        $self->_stopService();
    } finally {
        $self->_unlock();
    };
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

# Method: _enforceServiceState
#
#   This method will start, restart or stop the associated daemons to 
#   bring them to their desired state
#
sub _enforceServiceState
{
    my ($self) = @_;
    if($self->isEnabled()) {
        $self->_startService();
    } else {
        $self->_stopService();
    }
}

# Method: _supportsActions
# 
#   This method determines if the service will have a button to start/restart
#   it in the module status widget. By default services will have the button
#   unless this method is overriden to return undef
sub _supportsActions
{
    return 1;
}

sub _gconfModule
{
    my ($self) = @_;

    my $global = EBox::Global->instance();

    my $name = $self->serviceModuleName();
    return undef unless(defined($name) and $global->modExists($name));

    return $global->modInstance($name);
}

1;
