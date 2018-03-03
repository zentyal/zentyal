# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::ServiceManager
#
#   This class is responsible to check if a given module is going to
#   modify a file which has previously been modifyed by a user.
#
#   It uses MD5 digests to track the changes
#
#
use strict;
use warnings;

package EBox::ServiceManager;

use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use EBox::Global;
use EBox::Sudo;

use TryCatch;
use File::Basename;

use constant CONF_DIR => 'ServiceModule/';
use constant CLASS => 'EBox::Module::Service';

# Group: Public methods

sub new
{
    my $class = shift;

    my $ebox = EBox::Global->getInstance();

    my $self =
    {
        'confmodule' => $ebox,
    };

    bless($self, $class);

    return $self;
}

# Method: enableService
#
#   set service for a module, taking care of enabling or disabling its dependencies
#
# Parameters
#
#       modName -  module name
#       status    - true to enable, false to disable
#
sub enableService
{
    my ($self, $modName, $status) = @_;
    my $global = EBox::Global->getInstance();
    if ($status) {
        # enable dependencies of all modules to enable, if the module is disabled
        # the setService module take cares of that
        my @deps = @{ $global->modInstance($modName)->enableModDependsRecursive()};
        foreach my $name (@deps) {
            $global->modInstance($name)->enableService(1);
        }
    }

    my $mod = $global->modInstance($modName);
    $mod->enableService($status);
}

# Method: moduleStatus
#
#   It returns the status for all modules which implement the interface CLASS
#
#   The status is a hash ref containing:
#
#       configured - boolean to store if the user has accepted to carry out
#                    the operation that involve enabling the module
#       depends    - boolean to store if the module's dependencies are met
#                    and therefore it can be enabled or not
#       status     - boolean to store if the user wants the service enabled
#
# Returns:
#
#   Array ref of hashes containing the module's name and its status
#
sub moduleStatus
{
    my ($self) = @_;

    my $global = $self->{'confmodule'};

    my @mods;
    my $change = undef;
    for my $modName (@{$self->_dependencyTree()}) {
        my $mod = $global->modInstance($modName);
        my $status = {};
        $status->{'configured'} = $mod->configured();
        $status->{'depends'} = $self->dependencyEnabled($mod->name());
        $status->{'status'} = $mod->isEnabled();
        $status->{'name'} = $mod->name();
        $status->{'printableName'} = $mod->printableName();
        $status->{'printableDepends'} = $self->printableDepends($mod->name());
        if ($mod->showModuleStatus()) {
            push (@mods, $status);
        }
    }

    return \@mods;
}

# Method: printableDepends
#
#   Return the printable dependencies for a given module, that is: i18ized
#
# Parameters:
#
#   module - module's name
#
# Returns:
#
#   Array ref
sub printableDepends
{
    my ($self, $module) = @_;

    my $global = $self->{'confmodule'};

    my @depends;
    for my $mod (@{$global->modInstance($module)->enableModDepends()}) {
        push (@depends, $global->modInstance($mod)->printableName());
    }
    return \@depends;
}

# Method: dependencyEnabled
#
#   Check if every module's dependency is enabled
#
# Returns:
#
#   boolean - true if all dependencies are enabled
sub dependencyEnabled
{
    my ($self, $module) = @_;

    my $global = $self->{'confmodule'};

    for my $mod (@{$global->modInstance($module)->enableModDepends()}) {
        my $instance = $global->modInstance($mod);
        unless (defined($instance)) {
            EBox::warn("$mod can't be instanced");
            next;
        }

        next unless ($instance->isa(CLASS));

        return undef unless ($instance->isEnabled());
    }

    return 1;
}
# Method: enableAllModules
#
#       This method enables all modules implementing
#       <EBox::Module::Service>
#
sub enableAllModules
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    for my $modName (@{$self->_dependencyTree()}) {
        my $module = $global->modInstance($modName);
        try {
            $module->configureModule();
        } catch ($e) {
            EBox::warn("Failed to enable module $modName: "  . $e->text());
        }
    }
}

# Method: modulesInDependOrder
#
#     Return a module list ordered by the boot dependencies
#
sub modulesInDependOrder
{
    my ($self) = @_;
    my @modules = map { EBox::Global->modInstance($_) }
        (@{$self->_dependencyBootTree()});
    return \@modules;
}

# Group: Private methods

sub modulesInFirstInstallOrder
{
    my ($self) = @_;
    my @mods;
    my @rawMods = @{$self->_dependencyTree()};

    my ($firewallSeen, $logsSeen, $auditSeen);
    foreach my $mod (@rawMods) {
        if ($mod eq 'firewall') {
            $firewallSeen = 1;
            push @mods, 'firewall';
        } elsif ($mod eq 'logs') {
            # we will add the module later
            $logsSeen = 1;
        } elsif ($mod eq 'audit') {
            # we will add the module later
            $auditSeen = 1;
        } else {
            push @mods, $mod;
        }
    }

    if ($logsSeen) {
        # added in the last to receive all new logobservers
        push @mods, 'logs';
    }
    if ($auditSeen) {
        # after logs, to respect its dependency
        push @mods, 'audit';
    }
    if ($firewallSeen) {
        # added one more time to receive rules added by enables
        push @mods, 'firewall';
    }

    return \@mods;
}

sub _dependencyTree
{
    my ($self, $tree, $hash) = @_;

    return $self->_genericDependencyTree($tree, $hash, 'enableModDepends');
}

sub _dependencyBootTree
{
    my ($self, $tree, $hash) = @_;

    return $self->_genericDependencyTree($tree, $hash, 'bootDepends');
}

sub _genericDependencyTree
{
    my ($self, $tree, $hash, $func) = @_;

    $tree = [] unless (defined($tree));
    $hash = {} unless (defined($hash));

    my $global = $self->{'confmodule'};

    my $numMods = @{$tree};
    for my $mod (@{$global->modInstancesOfType(CLASS)}) {
        next if (exists $hash->{$mod->{'name'}});
        my $depOk = 1;
        for my $modDep (@{$mod->$func()}) {
            unless (exists $hash->{$modDep}) {
                $depOk = undef;
                last;
            }
        }
        if ($depOk) {
            push (@{$tree}, $mod->{'name'});
            $hash->{$mod->{'name'}} = 1;
        }
    }

    if ($numMods ==  @{$tree}) {
        return $tree;
    } else {
        return $self->_genericDependencyTree($tree, $hash, $func);
    }
}

1;
