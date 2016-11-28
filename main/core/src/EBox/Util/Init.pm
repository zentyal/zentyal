# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::Util::Init;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;
use EBox::ServiceManager;
use File::Slurp;
use TryCatch;

sub moduleList
{
    print "Module list: \n";
    my $global = EBox::Global->getInstance(1);
    my @mods = @{$global->modInstancesOfType('EBox::Module::Service')};
    my @names = map { $_->{name} } @mods;
    print join(' ', @names);
    print "\n";
}

# Procedure: checkModule
#
#    Check the module is valid
#
#    - the given module name is a valid Zentyal module
#    - the given module is one which services associated to it
#
# Parameters:
#
#    modname - String the module name
#
# Returns:
#
#    <EBox::Module::Base> - the module
#
# Exits:
#
#    - if it is not a valid module name
#    - if it is not a valid service module
#
sub checkModule
{
    my ($modname) = @_;

    my $global = EBox::Global->getInstance(1);
    my $mod = $global->modInstance($modname);
    if (not defined $mod) {
        print STDERR "$modname is not a valid module name\n";
        moduleList();
        exit 2;
    }
    if (not $mod->isa("EBox::Module::Service")) {
        print STDERR "$modname is not a module with services\n";
        moduleList();
        exit 2;
    }
    return $mod;
}

sub start
{
    my $serviceManager = new EBox::ServiceManager;
    my @mods = @{$serviceManager->modulesInDependOrder()};
    my @names = map { $_->{'name'} } @mods;
    @names = grep { $_ ne 'webadmin' } @names;
    push(@names, 'webadmin');

    EBox::info("Modules to start: @names");
    foreach my $modname (@names) {
        moduleAction($modname, 'restartService', 'start');
    }

    EBox::info("Start modules finished");
}

sub stop
{
    my $serviceManager = new EBox::ServiceManager;
    my @mods = @{$serviceManager->modulesInDependOrder()};
    my @names = map { $_->{'name'} } @mods;
    @names = grep { $_ ne 'webadmin' } @names;
    unshift (@names, 'webadmin');

    EBox::info("Modules to stop: @names");
    foreach my $modname (reverse @names) {
        moduleAction($modname, 'stopService', 'stop');
    }

    EBox::info("Stop modules finished");
}

sub moduleAction
{
    my ($modname, $action, $actionName, %opts) = @_;
    my $mod = checkModule($modname); #exits if module is not manageable

    my $redisTrans = $modname ne 'network';

    my $success;
    my $errorMsg;
    my $redis = $mod->redis();
    try {
        $redis->begin() if ($redisTrans);
        $mod->$action(restartModules => 1, %opts);
        $redis->commit() if ($redisTrans);
        $success = 0;
    } catch (EBox::Exceptions::Base $e) {
        $success = 1;
        $errorMsg =  $e->text();
        $redis->rollback() if ($redisTrans);
    } catch ($e) {
        $success = 1;
        $errorMsg = "$e";
        $redis->rollback() if ($redisTrans);
    }

    printModuleMessage($modname, $actionName, $success, $errorMsg);
}

# Procedure: status
#
#    Print the status of a module.
#
#        - RUNNING (enabled and running)
#        - STOPPED (enabled and not running)
#        - RUNNING UNMANAGED (disabled and running)
#        - DISABLED (disabled and not running)
#
#    It exits from the application.
#
# Parameters:
#
#    modname - String the module name
#
# Exits:
#
#    0 - If the module is enabled
#    2 - If the module is not valid or it is not a service one
#    3 - If the module is disabled
#
sub status
{
    my ($modname) = @_;

    my $mod = checkModule($modname); #exits if module is not manageable

    my $msg = "Zentyal: status module $modname:\t\t\t";
    my $enabled = $mod->isEnabled();
    my $running = $mod->isRunning();
    if ($enabled and $running) {
        print STDOUT $msg . "[ RUNNING ]\n";
        exit 0;
    } elsif ($enabled and not $running) {
        print STDOUT $msg . "[ STOPPED ]\n";
        exit 0;
    } elsif ((not $enabled) and $running) {
        print STDOUT $msg . "[ RUNNING UNMANAGED ]\n";
        exit 3;
    } else {
        print STDOUT $msg . "[ DISABLED ]\n";
        exit 3;
    }
}

# Procedure: enabled
#
#    Print if a module is enabled
#
#        - ENABLED
#        - DISABLED
#
#    It exits from the application.
#
# Parameters:
#
#    modname - String the module name
#
# Exits:
#
#    0 - If the module is enabled or disabled
#    2 - If the module is not valid or it is not a service one
#
sub enabled
{
    my ($modname) = @_;

    my $mod = checkModule($modname);

    my $msg = "Zentyal module $modname:\t\t\t";
    if ($mod->isEnabled()) {
        print STDOUT $msg . "[ ENABLED ]\n";
    } else {
        print STDOUT $msg . "[ DISABLED ]\n";
    }
    exit 0;
}

sub _logActionFunction
{
    my ($action, $success) = @_;

    EBox::Sudo::system(". /lib/lsb/init-functions; log_begin_msg \"$action\"; log_end_msg $success");
}

sub printModuleMessage
{
    my ($modname, $action, $success, $errorMsg) = @_;

    my %actions = ( 'start' => 'Starting', 'stop' => 'Stopping',
            'restart' => 'Restarting' );

    my $msg = $actions{$action} . " Zentyal module: $modname";
    _logActionFunction($msg, $success);
    if ($errorMsg) {
        print STDERR $errorMsg, "\n";
    }
}

# Procedure: moduleRestart
#
#     Restart the given module (rewrite configuration and restart daemons)
#
# Parameters:
#
#     modname - String the module name
#
sub moduleRestart
{
    my ($modname) = @_;
    moduleAction($modname, 'restartService', 'restart');
}

# Procedure: moduleStop
#
#     Stop the given module
#
# Parameters:
#
#     modname - String the module name
#
sub moduleStop
{
    my ($modname) = @_;
    moduleAction($modname, 'stopService', 'stop', temporaryStopped => 1);
}

1;
