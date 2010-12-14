# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::Global;

use strict;
use warnings;

use base qw(EBox::GConfModule Apache::Singleton::Process);

use EBox;
use EBox::Exceptions::Command;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use Error qw(:try);
use EBox::Config;
use EBox::Gettext;
use EBox::ProgressIndicator;
use EBox::ProgressIndicator::Dummy;
use EBox::Sudo;
use EBox::Validate qw( :all );
use File::Basename;
use File::Glob;
use YAML::Tiny;
use Log::Log4perl;
use POSIX qw(setuid setgid setlocale LC_ALL);
use Perl6::Junction qw(any all);

use Digest::MD5;
use AptPkg::Cache;
use File::stat;

# Constants
use constant {
    PRESAVE_SUBDIR  => EBox::Config::etc() . 'pre-save',
    POSTSAVE_SUBDIR => EBox::Config::etc() . 'post-save',
    TIMESTAMP_KEY   => 'saved_timestamp',
};

my @CORE_MODULES = qw(sysinfo apache events global logs);

my $lastDpkgStatusMtime = undef;
my $_cache = undef;
my $_brokenPackages = {};

#redefine inherited method to create own constructor
#for Singleton pattern
sub _new_instance
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'global', domain => 'ebox',
                                      printableName => 'global', @_);
    bless($self, $class);
    $self->{'mod_instances'} = {};
    $self->{'mod_instances_hidden'} = {};
    return $self;
}

sub isReadOnly
{
    my $self = shift;
    return $self->{ro};
}

#Method: readModInfo
#
#   Static method which returns the information found in the module's yaml file
#
sub readModInfo # (module)
{
    my ($name) = @_;
    my $yaml = YAML::Tiny->read(EBox::Config::share() . "ebox/modules/$name.yaml");
    return $yaml->[0];
}

#Method: theme
#
#   Returns the information found in custom.theme if exists
#   exists or default.theme if not.
#
sub theme
{
    my ($self) = @_;

    unless (defined $self->{theme}) {
        $self->{theme} = _readTheme();
    }

    return $self->{theme};
}

sub _readTheme
{
    my $path = EBox::Config::share() . 'ebox/www';
    my $theme = "$path/custom.theme";
    unless (-f $theme) {
        $theme = "$path/default.theme";
    }
    my $yaml = YAML::Tiny->read($theme);
    return $yaml->[0];
}

sub _className
{
    my ($self, $name) = @_;
    my $info = readModInfo($name);
    defined($info) or return undef;
    return $info->{'class'};
}

sub _writeModInfo
{
    my ($self, $name, $info) = @_;
    my $yaml = YAML::Tiny->new;
    $yaml->[0] = $info;
    $yaml->write(EBox::Config::share() . "/ebox/modules/$name.yaml");
}

# Method: modExists
#
#      Check if a module exists
#
# Parameters:
#
#       module -  module's name to check
#
# Returns:
#
#       boolean - True if the module exists, otherwise false
#
sub modExists # (module)
{
    my ($self, $name) = @_;

    # Check if module package is properly installed
    #
    # No need to check core modules because if
    # ebox package is not properly installed nothing
    # of this is going to work at all.
    #
    if ($name eq any(@CORE_MODULES)) {
        return defined($self->_className($name));
    } else {
        # Fall back to the classical implementation
        # if we are in middle of a package installation
        if ($ENV{DPKG_RUNNING_VERSION}) {
            return defined($self->_className($name));
        }

        my $package = "ebox-$name";
        # Special case for the usersandgroups modules that
        # are the exception for the above naming rule
        if ($name =~ /^user/) {
            $package = 'ebox-usersandgroups';
        }
        return _packageInstalled($package);
    }
}

# Method: modEnabled
#
#      Check if a module exists and it's enabled
#
# Parameters:
#
#       module -  module's name to check
#
# Returns:
#
#       boolean - True if the module is enabled, otherwise false
#
sub modEnabled # (module)
{
    my ($self, $name) = @_;

    unless ($self->modExists($name)) {
        return 0;
    }
    my $mod = $self->modInstance($name);
    return $mod->isEnabled();
}

# Method: modIsChanged
#
#      Check if the module config has changed
#
#      Global module is considered always unchanged
#
# Parameters:
#
#       module -  module's name to check
#
# Returns:
#
#       boolean - True if the module config has changed , otherwise false
#

sub modIsChanged # (module)
{
    my ($self, $name) = @_;

    defined($name) or return undef;
    ($name ne 'global') or return undef;

    $self->modExists($name) or return undef;

    my $info = readModInfo($name);
    return $self->get_bool("modules/$name/changed");
}

# Method: modChange
#
#       Set a module as changed
#
#      Global cannot be marked as changed and such request will be ignored
#
# Parameters:
#
#       module -  module's name to set
#
sub modChange # (module)
{
    my ($self, $name) = @_;
    defined($name) or return;
    ($name ne 'global') or return;

    return if $self->modIsChanged($name);

    my $mod = $self->modInstance($name);
    defined($mod) or throw EBox::Exceptions::Internal("Module $name does not exist");

    $mod->initChangedState();

    $self->set_bool("modules/$name/changed", 1);
}

#
# Method: modRestarted
#
#       Sets a module as restarted
#
# Parameters:
#
#       module -  module's name to set
#
sub modRestarted # (module)
{
    my ($self, $name) = @_;
    defined($name) or return;
    ($name ne 'global') or return;
    $self->modExists($name) or return;

    $self->set_bool("modules/$name/changed", undef);
}

# Method: modNames
#
#       Return an array containing all module names
#
# Returns:
#
#       array ref - each element contains the module's name
#
sub modNames
{
    my $self = shift;
    my $log = EBox::logger();
    my $global = EBox::Global->instance();
    my @allmods = ();
    foreach (('sysinfo', 'network', 'firewall')) {
        if ($self->modExists($_)) {
            push(@allmods, $_);
        }
    }
    my @files = glob(EBox::Config::share() . '/ebox/modules/*.yaml');
    my @mods = map { basename($_) =~ m/(.*)\.yaml/ ; $1 } @files;
    foreach my $mod (@mods) {
        next unless ($self->modExists($mod));
        next if (grep(/^$mod$/, @allmods));
        my $class = $self->_className($mod);
        if(defined($class)) {
            push(@allmods, $mod);
        }
    }
    return \@allmods;
}

# Method: unsaved
#
#       Tell you if there is at least one unsaved module
#
# Returns:
#
#       boolean - indicating if at least a module has unsaved changes
#
sub unsaved
{
    my $self = shift;
    my @names = @{$self->modNames()};
    foreach (@names) {
        $self->modIsChanged($_) or next;
        return 1;
    }
    return undef;
}


sub prepareRevokeAllModules
{
    my ($self) = @_;

    my $totalTicks = grep {
        $self->modIsChanged($_);
    }  @{$self->modNames};

    return $self->_prepareActionScript('revokeAllModules', $totalTicks);
}

# Method: revokeAllModules
#
#       Revoke the changes made in the configuration for all the modules
#
sub revokeAllModules
{
        my ($self, %options) = @_;

        my $progress = $options{progress};
        if (not $progress) {
            $progress = EBox::ProgressIndicator::Dummy->create();
        }

        my @names = @{$self->modNames};
        my $failed = "";

        foreach my $name (@names) {
                $self->modIsChanged($name) or next;

                $progress->setMessage($name);
                $progress->notifyTick();

                my $mod = $self->modInstance($name);
                try {
                        $mod->revokeConfig;
                } catch EBox::Exceptions::Internal with {
                        $failed .= "$name ";
                };
        }

        if ($failed eq "") {
            $progress->setAsFinished();
            return;
        }

        my $errorText = "The following modules failed while ".
                "revoking their changes, their state is unknown: $failed";
        $progress->setAsFinished(1, $errorText);
        throw EBox::Exceptions::Internal($errorText);
}

# Method: modifiedModules
#
#      Return the list of modified modules sorted by from parameter
#
# Parameters:
#
#      from - String the result is sorted depending on this parameter:
#             'enable' - the sort is done by enableDepends attribute
#             'save'   - the sort is done by depends attribute
#
# Returns:
#
#      array ref - containing the list of modified module names
#
sub modifiedModules
{
    my ($self, $from) = @_;

    defined($from) or throw EBox::Exceptions::MissingArgument('from');

    my @names = @{$self->modNames};
    my @mods;

    if ($self->modExists('firewall')) {
        push(@mods, 'firewall');
    }
    foreach my $modname (@names) {
        $self->modIsChanged($modname) or next;

        unless (grep(/^$modname$/, @mods)) {
            push(@mods, $modname);
        }

        my @deps = @{$self->modRevDepends($modname)};
        foreach my $aux (@deps) {
            unless (grep(/^$aux$/, @mods)) {
                push(@mods, $aux);
            }
        }
    }

    @mods = map { __PACKAGE__->modInstance($_) } @mods;

    my $sorted;
    if ( $from eq 'enable' ) {
        $sorted = sortModulesEnableModDepends(\@mods);
    } else {
        $sorted = __PACKAGE__->sortModulesByDependencies(\@mods, 'depends');
    }

    my @sorted = map { $_->name() } @{$sorted};

    return \@sorted;
}

sub sortModulesEnableModDepends
{
    my ($mods) = @_;
    return __PACKAGE__->sortModulesByDependencies(
        $mods,
        'enableModDepends'
       );
}

sub prepareSaveAllModules
{
    my ($self) = @_;

    my $totalTicks;
    my $file = '/var/lib/ebox/.first';
    if ( -f $file ) {
        # enable + save modules
        $totalTicks = scalar @{$self->modNames} * 2;
    } else {
        # save changed modules
        $totalTicks = scalar @{$self->modifiedModules('save')};
    }
    $totalTicks += $self->_nScripts(PRESAVE_SUBDIR, POSTSAVE_SUBDIR);

    return $self->_prepareActionScript('saveAllModules', $totalTicks);
}

sub packageCache
{
    my $status = stat('/var/lib/dpkg/status');
    my $currentMtime = $status->mtime();

    if (defined ($lastDpkgStatusMtime)) {
        # Regenerate cache only if status file has changed
        if ($currentMtime != $lastDpkgStatusMtime) {
            $_cache = new AptPkg::Cache;
            $_brokenPackages = {};
        }
    } else {
        $_cache = new AptPkg::Cache;
    }
    $lastDpkgStatusMtime = $currentMtime;

    return $_cache;
}

sub brokenPackages
{
    my @names = keys %{$_brokenPackages};
    return \@names;
}

sub _prepareActionScript
{
    my ($self, $action, $totalTicks) = @_;

     my $script =   EBox::Config::pkgdata() . 'ebox-global-action';
    $script .= " --action $action";


    my $progressIndicator =  EBox::ProgressIndicator->create(
                             executable => $script,
                             totalTicks => $totalTicks,
                                                    );

    $progressIndicator->runExecutable();

    return $progressIndicator;

}

# Method: saveAllModules
#
#      Save changes in all modules
#
sub saveAllModules
{
        my ($self, %options) = @_;

        my $log = EBox::logger();

        my $failed = "";

        my $progress = $options{progress};
        if (not $progress) {
            $progress = EBox::ProgressIndicator::Dummy->create();
       }

        my @mods = @{$self->modifiedModules('save')};
        my $modNames = join (' ', @mods);

        $self->_runExecFromDir(PRESAVE_SUBDIR, $progress, $modNames);

        my $msg = "Saving config and restarting services: @mods";

        $log->info($msg);


        # First instalation modules enable
        my $file = '/var/lib/ebox/.first';
        if ( -f $file ) {
            my $mgr = EBox::ServiceManager->new();
            @mods = @{$mgr->_dependencyTree()};
            $modNames = join(' ', @mods);

            foreach my $name (@mods) {
                $progress->setMessage(__x("Enabling {modName} module",
                                          modName => $name));
                $progress->notifyTick();

                next if ($name eq 'dhcp'); # Skip dhcp module
                next if ($name eq 'users'); # Skip usersandgroups

                my $module = $self->modInstance($name);
                $module->setInstalled();
                $module->setConfigured(1);
                $module->enableService(1);
                try {
                    $module->enableActions();
                } otherwise {
                    my ($ex) = @_;
                    my $err = $ex->text();
                    $module->setConfigured(0);
                    $module->enableService(0);
                    EBox::debug("Failed to enable module $name: $err");
                };
            }
        }

        my $apache = 0;
        foreach my $name (@mods) {
                if ($name eq 'apache') {
                        $apache = 1;
                        next;
                }

                $progress->setMessage(__x("Saving {modName} module",
                                          modName => $name));
                $progress->notifyTick();

                my $mod = $self->modInstance($name);
                my $class = 'EBox::Module::Service';

                if ($mod->isa($class)) {
                    $mod->setInstalled();

                    if (not $mod->configured()) {
                        $mod->_saveConfig();
                        $self->modRestarted($name);
                        next;
                    }
                }

                try {
                        $mod->save();
                } catch EBox::Exceptions::Internal with {
                        $failed .= "$name ";
                };
        }

        # Delete first time installation file (wizard)
        if ( -f $file ) {
            unlink $file;
        }

        # FIXME - tell the CGI to inform the user that apache is restarting
        if ($apache) {
                $progress->setMessage(__x("Saving {modName} module",
                                          modName => 'apache'));
                $progress->notifyTick();

                my $mod = $self->modInstance('apache');
                try {
                        $mod->save();
                } catch EBox::Exceptions::Internal with {
                        $failed .= "apache";
                };

        }
        if ($failed eq "") {
            $self->_runExecFromDir(POSTSAVE_SUBDIR, $progress, $modNames);
            # Store a timestamp with the time of the ending
            $self->st_set_int(TIMESTAMP_KEY, time());
            $progress->setAsFinished();

            return;
        }

        my $errorText = "The following modules failed while ".
                "saving their changes, their state is unknown: $failed";

        $progress->setAsFinished(1, $errorText);
        throw EBox::Exceptions::Internal($errorText);
}

# Method: restartAllModules
#
#       Force a restart for all the modules
#
sub restartAllModules
{
        my $self = shift;
        my @names = @{$self->modNames};
        my $log = EBox::logger();
        my $failed = "";
        $log->info("Restarting all modules");

        unless ($self->isReadOnly) {
                $self->{ro} = 1;
                $self->{'mod_instances'} = {};
        }

        foreach my $name (@names) {
                my $mod = $self->modInstance($name);
                try {
                        $mod->restartService();
                } catch EBox::Exceptions::Internal with {
                        $failed .= "$name ";
                };

        }
        if ($failed eq "") {
                return;
        }
        throw EBox::Exceptions::Internal("The following modules failed while ".
                "being restarted, their state is unknown: $failed");
}

# Method: stopAllModules
#
#       Stops all the modules
#
sub stopAllModules
{
        my $self = shift;
        my @names = @{$self->modNames};
        my $log = EBox::logger();
        my $failed = "";
        $log->info("Stopping all modules");

        unless ($self->isReadOnly) {
                $self->{ro} = 1;
                $self->{'mod_instances'} = {};
        }

        foreach my $name (@names) {
                my $mod = $self->modInstance($name);
                try {
                        $mod->stopService();
                } catch EBox::Exceptions::Internal with {
                        $failed .= "$name ";
                };

        }

        if ($failed eq "") {
                return;
        }
        throw EBox::Exceptions::Internal("The following modules failed while ".
                "stopping, their state is unknown: $failed");
}

# Method: getInstance
#
#       Return an instance of global class
#
# Parameters:
#
#       readonly - If this value is passed, it will return a readonly instance
#
# Returns:
#
#       <EBox::Global> instance - It will be read-only if it's required
#
sub getInstance # (read_only?)
{
    my $tmp = shift;
    if (!$tmp or ($tmp ne 'EBox::Global')) {
        throw EBox::Exceptions::Internal("Incorrect call to ".
                "EBox::Global->getInstance(), maybe it was called as an static".
                " function instead of a class method?");
    }
    my $ro = shift;
    my $global = EBox::Global->instance();
    if ($global->isReadOnly xor $ro) {
        $global->{ro} = $ro;
        # swap instance groups
        my $bak = $global->{mod_instances};
        $global->{mod_instances} = $global->{mod_instances_hidden};
        $global->{mod_instances_hidden} = $bak;
    }
    return $global;
}

#
# Method: modInstances
#
#       Return an array ref with an instance of every module
#
# Returns:
#
#       array ref - the elements contains the instance of modules
#
sub modInstances
{
    my $self = EBox::Global->instance();
    my @names = @{$self->modNames};
    my @array = ();

    foreach my $name (@names) {
        my $mod = $self->modInstance($name);
        push(@array, $mod);
    }
    return \@array;
}

# Method: modInstancesOfType
#
#       Return an array ref with an instance of every module that extends
#       a given classname
#
#   Parameters:
#
#       classname - the class base you are interested in
#
# Returns:
#
#       array ref - the elments contains the instance of the modules
#                   extending the classname
#
sub modInstancesOfType # (classname)
{
    shift;
    my $classname = shift;
    my $self = EBox::Global->instance();
    my @names = @{$self->modNames};
    my @array = ();

    foreach my $name (@names) {
        my $mod = $self->modInstance($name);
        if ($mod->isa($classname)) {
            push(@array, $mod);
        }
    }
    return \@array;
}


# Method: modInstance
#
#       Build an instance of a module. Can be called as a class method or as an
#       object method.
#
#   Parameters:
#
#       module - module name
#
# Returns:
#
#       If everything goes ok:
#
#       <EBox::Module> - An instance of the requested module
#
#       Otherwise
#
#       undef
sub modInstance # (module)
{
    my ($self, $name) = @_;

    if (!$self) {
        throw EBox::Exceptions::Internal("Incorrect call to ".
                                         "EBox::Global modInstance(), maybe it was called as an static".
                                         " function instead of an instance method?");
    }
    if (not $name) {
        throw EBox::Exceptions::MissingArgument(q{module's name});
    }

    my $global = undef;
    if ($self eq "EBox::Global") {
        $global = EBox::Global->getInstance();
    } elsif ($self->isa("EBox::Global")) {
        $global = $self;
    } else {
        throw EBox::Exceptions::Internal("Incorrect call to ".
                                         "EBox::Global modInstance(), the first parameter is not a class".
                                         " nor an instance.");
    }

    if ($name eq 'global') {
        return $global;
    }

    my $modInstance  = $global->{'mod_instances'}->{$name};
    if (defined($modInstance)) {
        if (not ($global->isReadOnly() xor $modInstance->{'ro'})) {
            return $modInstance;
                    }
    }

    $global->modExists($name) or return undef;
    my $classname = $global->_className($name);
    unless ($classname) {
        throw EBox::Exceptions::Internal("Module '$name' ".
                                         "declared, but it has no classname.");
    }
    eval "use $classname";
    if ($@) {
        throw EBox::Exceptions::Internal("Error loading ".
                                         "class: $classname error: $@");
    }
    if ($global->isReadOnly()) {
        $global->{'mod_instances'}->{$name} =
            $classname->_create(ro => 1);
    } else {
        $global->{'mod_instances'}->{$name} =
            $classname->_create;
    }

    return $global->{'mod_instances'}->{$name};
}


# Method: logger
#
#       Initialise Log4perl if necessary, returns the logger for the i
#       caller package
#
#   Parameters:
#
#       caller -
#
# Returns:
#
#       If everything goes ok:
#
#       <EBox::Module> - A instance of the requested module
#
#       Otherwise
#
#       undef
sub logger # (caller?)
{
    shift;
    EBox::deprecated();
    return EBox::logger(shift);
}

# Method: modDepends
#
#       Return an array ref with the names of the modules that the requested
#       module depends on
#
#   Parameters:
#
#       module - requested module
#
# Returns:
#
#       undef -  if the module does not exist
#       array ref - holding the names of the modules that the requested module
sub modDepends # (module)
{
    my ($self, $name) = @_;

    $self->modExists($name) or return undef;
    my $mod = $self->modInstance($name);
    return $mod->depends();
}

# Method: modRevDepends
#
#       Return an array ref with the names of the modules which depend on a given
#       module
#
#   Parameters:
#
#       module - requested module
#
# Returns:
#
#       undef -  if the module does not exist
#       array ref - holding the names of the modules which depend on the
#       requested module
#
sub modRevDepends # (module)
{
    my ($self, $name) = @_;
    $self->modExists($name) or return undef;
    my @revdeps = ();
    my @mods = @{$self->modNames};
    foreach my $mod (@mods) {
        my @deps = @{$self->modDepends($mod)};
        foreach my $dep (@deps) {
            defined($dep) or next;
            if ($name eq $dep) {
                push(@revdeps, $mod);
                last;
            }
        }
    }
    return \@revdeps;
}


# Name: sortModulesByDependencies
#
#  Sort a list of modules objects by its dependencies. The dependencies are get
# using a method that returns the names of the dependencies of each module.
#
#  Parameters:
#        modules_r          - reference to list of modules
#        dependenciesMethod - name of the method called in each module
#                             to get its dependencies
sub sortModulesByDependencies
{
    my ($package, $modules_r, $dependenciesMethod) = @_;

    my @modules = @{ $modules_r };
    my %availableModulesAndDependencies = map {
        $_->name() => undef;
    } @modules;

    my $i =0;
    while ($i < @modules) {
        my $mod = $modules[$i];
        my $modName = $mod->name();
        my @depends = ();
        if (defined $availableModulesAndDependencies{$modName}) {
            @depends = @{ $availableModulesAndDependencies{$modName} }
        } elsif ($mod->can($dependenciesMethod)) {
            @depends  = @{ $mod->$dependenciesMethod() };
            @depends = grep {
                exists $availableModulesAndDependencies{$_}
            } @depends;
            $availableModulesAndDependencies{$modName} = \@depends;
        }

        my $depOk = 1;

        foreach my $dependency (@depends) {
            my $depFound = 0;
            foreach my $j (0 .. $i) {
                if ($i == $j) {
                    # for $i ==0 case
                    last;
                } elsif ($modules[$j]->name() eq $dependency) {
                    $depFound = 1;
                    last;
                }
            }

            if (not $depFound) {
                $depOk = 0;
                last;
            }
        }

        if ($depOk) {
            $i += 1;
        } else {
            my $unreadyMod = splice @modules, $i, 1;
            push @modules, $unreadyMod;
        }

    }

    return \@modules;
}

# Method: lastModificationTime
#
#      Return the latest modification time, this is the latest of
#      these events:
#
#      - After finishing saving changes using <saveAllModules> call
#      - After a modification in LDAP in users module is present and at
#      least configured
#
# Returns:
#
#      Int - the lastModificationTime
#
sub lastModificationTime
{
    my ($self) = @_;

    my $lastStamp = $self->st_get_int(TIMESTAMP_KEY);
    $lastStamp = 0 unless defined($lastStamp);
    if ( $self->modExists('users') ) {
        my $usersMod = $self->modInstance('users');
        if ( $usersMod->configured() ) {
            my ($sec, $min, $hour, $mday, $mon, $year) = localtime($lastStamp);
            my $lastStampStr = sprintf('%04d%02d%02d%02d%02d%02dZ',
                                       ($year + 1900, $mon + 1, $mday, $hour,
                                        $min, $sec));
            my $ldapStamp = $usersMod->ldap()->lastModificationTime($lastStampStr);
            if ( $ldapStamp > $lastStamp ) {
                $lastStamp = $ldapStamp;
            }
        }
    }
    return $lastStamp;

}

# Method: setLocale
#
#       *deprecated*
#
sub setLocale # (locale)
{
    shift;
    EBox::deprecated();
    EBox::setLocale(shift);
}

# Method: locale
#
#       *deprecated*
#
sub locale
{
    EBox::deprecated();
    return EBox::locale();
}

# Method: init
#
#       *deprecated*
#
sub init
{
    EBox::deprecated();
    EBox::init();
}

# Method: _runExecFromDir
#
#      Run executables files from a directory using
#      <EBox::Sudo::command>. The execution will be done in lexical
#      order
#
# Parameters:
#
#      dir - String the directory to search for executables
#
#      progress - <EBox::ProgressIndicator> to indicate the user how
#      the actions are being performed
#
#      modNames - string with the names of modified modules
#
# Exceptions:
#
#      The ones launched by <EBox::Sudo::command>
#
sub _runExecFromDir
{
    my ($self, $dirPath, $progress, $modNames) = @_;

    unless ( -e $dirPath ) {
        throw EBox::Exceptions::DataNotFound(data  => 'directory',
                                             value => $dirPath);
    }

    opendir(my $dh, $dirPath);
    my @execs = ();
    while( my $file = readdir($dh) ) {
        next unless ( -f "${dirPath}/$file" or -l "${dirPath}/$file");
        next unless ( -x "${dirPath}/$file" );
        push(@execs, "${dirPath}/$file");
    }
    closedir($dh);

    # Sorting lexically the scripts to execute
    @execs = sort(@execs);

    if ( @execs > 0 ) {
        EBox::info("Running executable files from $dirPath");
        foreach my $exec (@execs) {
            try {
                EBox::info("Running $exec");
                # Progress indicator stuff
                $progress->setMessage(__x('running {scriptName} script',
                                          scriptName => scalar(File::Basename::fileparse($exec))));
                $progress->notifyTick();
                my $output = EBox::Sudo::command("$exec $modNames");
                if ( @{$output} > 0) {
                    EBox::info("Output from $exec: @{$output}");
                }
            } catch EBox::Exceptions::Command with {
                my ($exc) = @_;
                my $msg = "Command $exec failed its execution\n"
                  . 'Output: ' . @{$exc->output()} . "\n"
                  . 'Error: ' . @{$exc->error()} . "\n"
                  . 'Return value: ' . $exc->exitValue();
                EBox::error($msg);
            } otherwise {
                my ($exc) = @_;
                EBox::error("Error executing $exec: $exc");
            };
        }
    }
}

# Method: _nScripts
#
# Parameters:
#
#     array - the dir path to count executable files
#
# Returns:
#
#     Integer - number of executable scripts in pre/post dirs
#
sub _nScripts
{
    my ($self, @dirPaths) = @_;

    my $nScripts = 0;
    foreach my $dirPath (@dirPaths) {
        opendir(my $dh, $dirPath);
        while( my $file = readdir($dh) ) {
            next unless ( -f "${dirPath}/$file" or -l "${dirPath}/$file");
            next unless ( -x "${dirPath}/$file" );
            $nScripts++;
        }
        closedir($dh);
    }
    return $nScripts;
}

sub _packageInstalled
{
    my ($name) = @_;

    my $cache = packageCache();

    if (exists $_brokenPackages->{$name}) {
        return 0;
    }

    my $installed = 0;
    if ($cache->exists($name)) {
        my $pkg = $cache->get($name);
        if ($pkg->{SelectedState} == AptPkg::State::Install) {
            $installed = ($pkg->{InstState} == AptPkg::State::Ok and
                          $pkg->{CurrentState} == AptPkg::State::Installed);
            unless ($installed) {
                $_brokenPackages->{$name} = 1;
            }
        }
    }
    return $installed;
}

1;
