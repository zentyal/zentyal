# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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
use EBox::Exceptions::DataExists;
use Error qw(:try);
use EBox::Config;
use EBox::Gettext;
use EBox::ProgressIndicator;
use EBox::ProgressIndicator::Dummy;
use EBox::Sudo;
use EBox::Validate qw( :all );
use File::Basename;
use Log::Log4perl;
use POSIX qw(setuid setgid setlocale LC_ALL);

use Digest::MD5;

# Constants
use constant {
    PRESAVE_SUBDIR  => EBox::Config::etc() . 'pre-save',
    POSTSAVE_SUBDIR => EBox::Config::etc() . 'post-save',
};


#redefine inherited method to create own constructor
#for Singleton pattern
sub _new_instance 
{
        my $class = shift;
        my $self = $class->SUPER::_create(name => 'global', @_);
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

        my $class = $self->get_string("modules/$name/class");
        return undef unless(defined($class));

        # Try to dectect if gconf is messing with us,
        # and a removed module is still there
        eval "use $class";
        if ($@) {
            EBox::error("Error loading class $class: $@");
        }
        return undef if ($@);

        return 1;
}

#
# Method: modIsChanged 
#
#      Check if the module config has changed
#
#       Global module is considered always unchanged
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
        return $self->get_bool("modules/$name/changed");
}

#
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

        return if $self->get_bool("modules/$name/changed");

        my $mod = $self->modInstance($name);
        defined $mod or throw EBox::Exceptions::Internal("Module $name does not exist");

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


#
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
        foreach my $mod (@{$self->all_dirs_base("modules")}) {
                next unless ($self->modExists($mod));
                next if (grep(/^$mod$/, @allmods));
                my $class = $global->get_string("modules/$mod/class");
                unless (defined($class) and ($class ne '')) {
                        $global->delete_dir("modules/$mod");
                        $log->info("Removing module $mod as it seems " .
                                   "to be empty");
                } else {
                        push(@allmods, $mod);                           
                }
        }
        return \@allmods;
}

#
# Method: unsaved
#
#       Tell you if there is at least one unsaved module
#
# Returns:
#
#   	boolean - indicating if at least a module has unsaved changes
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

#
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

sub modifiedModules
{
    my ($self) = @_;
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

    return \@mods;
}



sub prepareSaveAllModules
{
    my ($self) = @_;

    my $totalTicks = scalar @{$self->modifiedModules()}
      + $self->_nScripts(PRESAVE_SUBDIR, POSTSAVE_SUBDIR);

    return $self->_prepareActionScript('saveAllModules', $totalTicks);
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

        my @mods = @{$self->modifiedModules()};
        my $modNames = join(' ', @mods);

        $self->_runExecFromDir(PRESAVE_SUBDIR, $progress, $modNames);

        my $msg = "Saving config and restarting services: @mods";

        $log->info($msg);

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
                my $class = 'EBox::ServiceModule::ServiceInterface';
                if ($mod->isa($class) and not $mod->configured()) {
                        $mod->_saveConfig();
                        $self->modRestarted($name);
                        next;
                }

                try {
                        $mod->save();
                } catch EBox::Exceptions::Internal with {
                        $failed .= "$name ";
                };
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
            $progress->setAsFinished();
            return;
        }

        my $errorText = "The following modules failed while ".
                "saving their changes, their state is unknown: $failed";

        $progress->setAsFinished(1, $errorText);
        throw EBox::Exceptions::Internal($errorText);
}

#
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

#
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

#
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

# 
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


# 
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
    my $classname = $global->get_string("modules/$name/class");
    unless ($classname) {
        throw EBox::Exceptions::Internal("Module '$name' ".
                                         "declared, but it has no classname.");
    }
    eval "use $classname";
    if ($@) {
        throw EBox::Exceptions::Internal("Error loading ".
                                         "class: $classname");
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


# 
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

# 
# Method: modDepends 
#
#       Return an array ref with the names of the modules that the requested
#       module deed on
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
        my @list = map {s/^\s+//; $_} 
                    @{$self->get_list("modules/$name/depends")};
        if (@list) {
                return \@list;
        } else {
                return [];
        }
}

# 
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

# 
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

# 
# Method: setLocale 
#
#       *deprecated*
#
sub locale 
{
        EBox::deprecated();
        return EBox::locale();
}

# 
# Method: setLocale 
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

1;
