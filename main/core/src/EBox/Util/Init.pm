# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::Util::Init;

use strict;
use warnings;

use EBox::Global;
use EBox;
use EBox::Sudo;
use EBox::ServiceManager;
use File::Slurp;
use Error qw(:try);

sub moduleList {
    print "Module list: \n";
    my $global = EBox::Global->getInstance(1);
    my @mods = @{$global->modInstancesOfType('EBox::Module::Service')};
    my @names = map { $_->{name} } @mods;
    print join(' ', @names);
    print "\n";
}

sub checkModule {
    my ($modname) = @_;
    my $global = EBox::Global->getInstance(1);
    my $mod = $global->modInstance($modname);
    if (!defined $mod) {
        print STDERR "$modname is not a valid module name\n";
        moduleList();
        exit 2;
    }
    if(!$mod->isa("EBox::Module::Service")) {
        print STDERR "$modname is a not manageable module name\n";
        moduleList();
        exit 2;
    }
    return $mod;
}

sub checkDatabase() {
    unless (-e '/var/lib/zentyal/.db-created')  {
        system('sudo /usr/share/zentyal/create-db eboxlogs');
    }
}

sub start() {
    my $serviceManager = new EBox::ServiceManager;
    my @mods = @{$serviceManager->modulesInDependOrder()};
	my @names = map { $_->{'name'} } @mods;
    @names = grep { $_ ne 'apache' } @names;
	push(@names, 'apache');

    checkDatabase();
	foreach my $modname (@names) {
	    moduleAction($modname, 'restartService', 'start');
	}
}

sub stop() {
    my $serviceManager = new EBox::ServiceManager;
    my @mods = @{$serviceManager->modulesInDependOrder()};
    my @names = map { $_->{'name'} } @mods;
    @names = grep { $_ ne 'apache' } @names;
    unshift(@names, 'apache');

    foreach my $modname (reverse @names) {
        moduleAction($modname, 'stopService', 'stop');
    }
}


sub moduleAction
{
    my ($modname, $action, $actionName) = @_;
    my $mod = checkModule($modname); #exits if module is not manageable

    # Do not restart apache if we are run under zentyal-software
    if ($actionName eq 'restart' and $modname eq 'apache' ) {
        return if (exists $ENV{'EBOX_SOFTWARE'} and
                   $ENV{'EBOX_SOFTWARE'} == 1 );
    }

    my $success;
    my $errorMsg;
    try {
        $mod->$action();
        $success = 0;
    }
    catch EBox::Exceptions::Base with {
        my $ex = shift;
        $success = 1;
        $errorMsg =  $ex->text();
    } otherwise {
        my ($ex) = @_;
        $success = 1;
        $errorMsg = "$ex";
    };

    printModuleMessage($modname, $actionName, $success, $errorMsg);
}

sub status
{
    my ($modname, $action, $actionName) = @_;

    my $mod = checkModule($modname); #exits if module is not manageable

    my $msg = "EBox: status module $modname:\t\t\t";
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

sub _logActionFunction
{
	my ($action, $success) = @_;
	system(". /lib/lsb/init-functions; " .
	       " log_begin_msg \"$action\"; log_end_msg $success");
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


sub moduleRestart
{
    my ($modname) = @_;
    checkDatabase();
    moduleAction($modname, 'restartService', 'restart');
}

sub moduleStop
{
    my ($modname) = @_;
    moduleAction($modname, 'stopService', 'stop');
}

1;
