# Copyright (C) 2004-2007 Warp Networks S.L.
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

use strict;
use warnings;

package EBox::Module::Base;

use File::Copy;
use Proc::ProcessTable;
use EBox;
use EBox::Util::Lock;
use EBox::Config;
use EBox::Global;
use EBox::Sudo;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Exceptions::InvalidArgument;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::ServiceManager;
use EBox::DBEngineFactory;
use HTML::Mason;
use File::Temp qw(tempfile);
use Fcntl qw(:flock);
use TryCatch;
use Time::Local;
use File::Slurp;
use Perl6::Junction qw(any);
use Scalar::Util;

# Constants:
use constant APPARMOR_PARSER => '/sbin/apparmor_parser';
use constant APPARMOR_D      => '/etc/apparmor.d/';

# Method: _create
#
#   Base constructor for a module
#
# Parameters:
#
#   name - String module's name
#   printableName - String printable module's name
#   title - String the module's title
#
# Returns:
#
#   EBox::Module instance
#
# Exceptions:
#
#   Internal - If no name is provided
sub _create # (name)
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    $self->{name} = delete $opts{name};
    $self->{title} = delete $opts{title};
    $self->{version} = undef;
    $self->{printableName} = __(delete $opts{printableName});
    unless (defined($self->{name})) {
        use Devel::StackTrace;
        my $trace = Devel::StackTrace->new;
        print STDERR $trace->as_string;
        throw EBox::Exceptions::Internal(
            "No name provided on Module creation");
    }
    bless($self, $class);
    return $self;
}

# Method: info
#
#   Read module information from YAML file
#
sub info
{
    my ($self) = @_;
    return EBox::Global->readModInfo($self->{name});
}

# Method: depends
#
#       Return an array ref with the names of the modules that this
#       module depends on
#
# Returns:
#
#       array ref - holding the names of the modules that the requested module
#
sub depends
{
    my ($self) = @_;

    my $info = $self->info();
    my @list = map {s/^\s+//; $_} @{$info->{'depends'}};
    if (@list) {
        return \@list;
    } else {
        return [];
    }
}

# Method: initialSetup
#
#   This method is run to carry out the actions that are needed
#   when the module is installed or upgraded.
#
#   The run of this method must be always idempotent. So
#   the actions will need to check if they are necessary or
#   not to avoid problems when executed on upgrades.
#
#   The default implementation is to call the following
#   script if exists and has execution rights:
#      /usr/share/zentyal-$module/initial-setup
#
#   But this method can be overriden by any module.
#
#   When upgrading, the version of the previously installed
#   package is passed as argument.
#
# Parameters:
#
#     version - version of the previous package or undef
#               if this is the first install
#
sub initialSetup
{
    my ($self, $version) = @_;

    my $path = EBox::Config::share();
    my $modname = $self->{'name'};

    my $command = "$path/zentyal-$modname/initial-setup";
    if (-x $command) {
        if (defined $version) {
            $command .= " $version";
        }
        EBox::Sudo::root($command);
    }
}

# Method: migrate
#
#   This method runs all the needed migrations on a
#   module upgrade.
#
#   The migration scripts need to be located at:
#      /usr/share/zentyal-$module/migration/[00-99]*.pl
#
# Parameters:
#
#     version - version of the previously installed package
#
sub migrate
{
    my ($self, $version) = @_;

    my $path = EBox::Config::share();
    my $modname = $self->{'name'};
    my $package = $self->package();
    my $dir = "$path/$package/migration";
    my @scripts = glob ("$dir/[00-99]*.pl");

    foreach my $script (@scripts) {
        my $file = read_file($script);
        {
            #silent warnings (redefined subs)
            local $SIG{__WARN__} = sub
            {
                # TODO: remove this after debugging period
                EBox::debug(@_);
            };
            eval $file;
        };
    }
}

# Method: revokeConfig
#
#       Base method to revoke config. It just notifies that he module has been
#       restarted.
#       It should be overriden by subclasses as needed
#
sub revokeConfig
{
    my $self = shift;
    my $global = EBox::Global->getInstance();

    $global->modIsChanged($self->name) or return;
    $global->modRestarted($self->name);
}

# Method: _saveConfig
#
#   Base method to save configuration. It should be overriden
#   by subclasses as needed
#
sub _saveConfig
{
    # default empty implementation. It should be overriden by subclasses as
    # needed
}

# Method: save
#
#   Sets a module as saved. This implies a call to _regenConfig and set
#   the module as saved and unlock it.
#
sub save
{
    my ($self) = @_;

    $self->_lock();
    my $global = EBox::Global->getInstance();
    my $log = EBox::logger;
    $log->info("Restarting service for module: " . $self->name);
    $self->_saveConfig();
    try {
        $self->_regenConfig();
    } catch ($e) {
        $global->modRestarted($self->name);
        $self->_unlock();
        $e->throw();
    }
    $global->modRestarted($self->name);
    $self->_unlock();
}

# Method: saveConfig
#
#   Save module config, but do not call _regenConfig
#
sub saveConfig
{
    my $self = shift;

    $self->_lock();
    try {
        my $global = EBox::Global->getInstance();
        my $log = EBox::logger;
        $log->info("Saving config for module: " . $self->name);
        $self->_saveConfig();
    } catch ($e) {
        $self->_unlock();
        $e->throw();
    }
    $self->_unlock();
}

# Method: saveConfigRecursive
#
#   Save module config and the modules which depends on recursively
#
sub saveConfigRecursive
{
    my ($self) = @_;

    $self->_saveConfigRecursive($self->name);
}

# Method: _saveConfigRecursive
#
#   Save module config and the modules which depends on recursively
#
sub _saveConfigRecursive
{
    my ($self, $module) = @_;

    my $global = EBox::Global->getInstance();
    for my $dependency (@{$global->modDepends($module)}) {
        $self->_saveConfigRecursive($dependency);
    }

    my $modInstance = EBox::Global->modInstance($module);
    $modInstance->saveConfig();
    $global->modRestarted($module);
}

sub _unlock
{
    my ($self) = @_;
    EBox::Util::Lock::unlock($self->name);
}

sub _lock
{
    my ($self) = @_;
    EBox::Util::Lock::lock($self->name);
}

# Method: changed
#
#  Returns whether the module has changes status or not
sub changed
{
    my ($self) = @_;
    my $name = $self->name;
    my $global = EBox::Global->getInstance();
    return $global->modIsChanged($name);
}

# Method: setAsChanged
#
#   Sets the module changed status
#
#   Parameters:
#     newChangedStauts - optional, default to true (changed)
#
sub setAsChanged
{
    my ($self, $newChangedStatus) = @_;
    defined $newChangedStatus or
        $newChangedStatus = 1;

    my $name = $self->name;
    my $global = EBox::Global->getInstance();

    my $changedStatus = $global->modIsChanged($name);
    if ($newChangedStatus) {
        return if $changedStatus;
        $global->modChange($name);
    } else {
        return if not $changedStatus;
        $global->modRestarted($name);
    }
}

# Method: makeBackup
#
#   restores the module state from a backup
#
# Parameters:
#  dir - directory used for the backup operation
#  (named parameters following)
#  bug - wether we are making a bug report instead of a normal backup
sub makeBackup # (dir, %options)
{
    my ($self, $dir, %options) = @_;
    defined $dir or throw EBox::Exceptions::InvalidArgument('directory');

    my $backupDir = $self->_createBackupDir($dir);

    $self->aroundDumpConfig($backupDir, %options);
}

# Method: backupDir
#
# Parameters:
#    $dir - directory used for the restore/backup operation
#
# Returns:
#    the path to the directory used by the module to dump or restore his state
#
sub backupDir
{
    my ($self, $dir) = @_;

    # avoid duplicate paths problem
    my $modulePathPart =  '/' . $self->name() . '.bak';
    ($dir) = split $modulePathPart, $dir;

    my $backupDir = $self->_bak_file_from_dir($dir);
    return $backupDir;
}

# Private method: _createBackupDir
#   creates a directory to dump or restore files containig the module state.
#   If there are already a apropiate directory, it simply returns the path of this directory
#
# Parameters:
#     $dir - directory used for the restore/backup operation
#
# Returns:
#      the path to the directory used by the module to dump or restore his state
#
sub _createBackupDir
{
  my ($self, $dir) = @_;

  my $backupDir = $self->backupDir($dir);

  if (! -d $backupDir) {
    EBox::FileSystem::makePrivateDir($backupDir);
  }

  return $backupDir;
}

# Method: restoreBackup
#
#   restores the module state from a backup
#
# Parameters:
#  dir - directory used for the restore operation
#  (named parameters following)
#
sub restoreBackup # (dir, %options)
{
    my ($self, $dir, %options) = @_;
    defined $dir or throw EBox::Exceptions::InvalidArgument('directory');

    my $backupDir = $self->backupDir($dir);
    (-d $backupDir) or throw EBox::Exceptions::Internal("$backupDir must be a directory");

    if ($options{dataRestore}) {
        $self->aroundRestoreConfig($backupDir, %options);
    }
}

sub callRestoreBackupPreCheck
{
    my ($self, $dir, $options_r) = @_;
    my $backupDir = $self->backupDir($dir);
    (-d $backupDir) or
        throw EBox::Exceptions::Internal("$backupDir must be a directory");

    $self->restoreBackupPreCheck($backupDir, %{ $options_r });
}

sub restoreBackupPreCheck
{
    my ($self, $dir, %options) = @_;

    # default: no check
}

sub _bak_file_from_dir
{
    my ($self, $dir) = @_;
    $dir =~ s{/+$}{};
    my $file = "$dir/" . $self->name . ".bak";
    return $file;
}

# Method: restoreDependencies
#
#   this method should be override by any module that depends on another module/s  to be restored from a backup
#
# Returns: a reference to a list with the names of required eBox modules for a
#   sucesful restore. (default: module dependencies )
#
#
sub restoreDependencies
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance();
    return $global->modDepends($self->name);
}

# Method:  dumpConfig
#
#   this must be override by individuals to restore to dump the
#   configuration properly
#
# Parameters:
#   dir - directory where the modules backup files are
#         dumped (without trailing slash)
#
sub dumpConfig
{
    my ($self, $dir, %options) = @_;

}

# Method: aroundDumpConfig
#
# Wraps the dumpConfig call; the purpose of this sub is to allow
# special types of modules like Module::Config to call another method
# alongside with dumConfig transparently.
#
# Normally, ebox modules does not need to override this
#
# Parameters:
#   dir - Directoy where the module configuration is been dumped
#
sub aroundDumpConfig
{
    my ($self, $dir, @options) = @_;
    $self->dumpConfig($dir, @options);
}

#
# Method:  restoreConfig
#
#   This must be override by individuals to restore its configuration
#   from the backup file. Those files are the same were created with
#   dumpConfig
#
# Parameters:
#  dir - Directory where are located the backup files
#        (without the trailing slash)
#
sub restoreConfig
{
    my ($self, $dir) = @_;
}

#  Method: aroundRestoreConfig
#
# wraps the restoreConfig call; the purpose of this sub is to allow specila
# types of modules like Module::Config to call another method alongside with
# restoreConfig transparently
# normally ebox modules does not need to override this
#
# Parameters:
#  dir - directory where are located the backup files
#
sub aroundRestoreConfig
{
    my ($self, $dir, @extraOptions) = @_;

    $self->restoreConfig($dir, @extraOptions);
}

# Method: name
#
#   Return the module name of the current module instance
#
# Returns:
#
#       strings - name
#
sub name
{
    my $self = shift;
    return $self->{name};
}

# Method: setName
#
#   Set the module name for the current module instance
#
# Parameters:
#
#   name - module name
#
sub setName # (name)
{
    my $self = shift;
    my $name = shift;
    $self->{name} = $name;
}

# Method: printableName
#
#       Return the printable module name of the current module
#       instance
#
# Returns:
#
#       String - the printable name
#
sub printableName
{
    my ($self) = @_;

    if ( $self->{printableName} ) {
        return $self->{printableName};
    } else {
        return $self->name();
    }
}

# Method: setPrintableName
#
#       Set the printable module name of the current module
#       instance
#
# Parameters:
#
#       printableName - String the printable name
#
sub setPrintableName
{
    my ($self, $printableName) = @_;

    $self->{printableName} = $printableName;
}

# Method: title
#
#   Returns the module title of the current module instance
#
# Returns:
#
#   string - title or name if title was not provided
#
sub title
{
    my ($self) = @_;
    if(defined($self->{title})) {
        return $self->{title};
    } elsif ( $self->{printableName} ) {
        return $self->{printableName};
    } else {
        return $self->{name};
    }
}

# Method: setTitle
#
#   Sets the module title for the current module instance
#
# Parameters:
#
#   title - module title
#
sub setTitle # (title)
{
    my ($self,$title) = @_;
    $self->{title} = $title;
}

# Method: actionMessage
#
#   Gets the action message for an action
#
# Parameters:
#
#   action - action name
sub actionMessage
{
    my ($self,$action) = @_;
    if(defined($self->{'actions'})) {
        return $self->{'actions'}->{$action};
    } else {
        return $action;
    }
}

# Method: menu
#
#   This method returns the menu for the module. What it returns
#   it will be added up to the interface's menu. It should be
#   overriden by subclasses as needed
sub menu
{
    # default empty implementation
    return undef;
}

# Method: widgets
#
#   Return the widget names for the module. It should be overriden by
#   subclasses as needed
#
# Returns:
#
#   An array of hashes containing keys 'title' and 'widget', 'title' being the
#   title of the widget and 'widget' a function that can fill an
#   EBox::Dashboard::Widget that will be passed as a parameter
#
#   It can optionally have the key 'default' set to 1 to have the widget
#   added by default to the dashboard the first time it's seen.
#
#   It can also contain a 'parameter' key which will be passed as parameter to
#   the widget function. This is intended to allow the dynamic creation of
#   several widgets.
#
sub widgets
{
    # default empty implementation
    return {};
}

# Method: widget
#
#   Return the appropriate widget if exists or undef otherwise
#
# Parameters:
#       name - the widget name
#
# Returns:
#
#       <EBox::Dashboard::Widget> with the appropriate widget
#
sub widget
{
    my ($self, $name) = @_;
    my $widgets = $self->widgets();
    my $winfo = $widgets->{$name};
    if (defined $winfo) {
        my $widget = new EBox::Dashboard::Widget($winfo->{'title'},$self->{'name'},$name);
        #fill the widget
        $widget->{'module'} = $self->{'name'};
        $widget->{'default'} = $winfo->{'default'};
        $widget->{'order'} = $winfo->{'order'};
        my $wfunc = $winfo->{'widget'};
        try {
            $wfunc->($self, $widget, $winfo->{'parameter'});
            return $widget;
        } catch ($ex) {
            EBox::error("Error loading widget $name from module " . $self->name() . ": $ex");
            return undef;
        }
    } else {
        return undef;
    }
}

# Method: statusSummary
#
#   Return the status summary for the module. What it returns will
#   be added up to the common status summary page. It should be overriden by
#   subclasses as needed.
#
# Returns:
#
#       <EBox::Dashboard::ModuleStatus> - the summary status for the module
#
sub statusSummary
{
    # default empty implementation
    return undef;
}

# Method: package
#
#   Returns the package name
#
# Returns:
#
#   strings - package name
#
sub package
{
    my ($self) = @_;

    my $name = $self->{name};
    if ($name eq any((EBox::Global::CORE_MODULES()))) {
        return 'zentyal';
    } else {
        return "zentyal-$name";
    }
}

# Method: version
#
#   Returns the package version
#
# Returns:
#
#   strings - package version
#
sub version
{
    my ($self) = @_;

    unless (defined ($self->{version})) {
        my $package = $self->package();
        $package = 'zentyal-core' if ($package eq 'zentyal');
        my @output = `dpkg-query -W $package`;
        foreach my $line (@output) {
            if ($line =~ m/^$package\s+([\d.]+)/) {
                $self->{version} = $1;
                last;
            }
        }
    }

    return $self->{version};
}

# Method: wizardPages
#
#   Return an array ref containin the wizard pages for the module. It should
#   be overriden by subclasses as needed
#
# Returns:
#
#   An array ref of URL's of wizard pages for this module. This pages
#   must be implemented using WizardPage as base class.
#
#   Example:
#       [
#           {
#               page => '/Module/Wizard/Page'
#               order => 201
#           },
#           ....
#       ]
#
#
sub wizardPages
{
    # default implementation: no wizards
    return [];
}

# Method: appArmorProfiles
#
#    Return the AppArmor profiles for this module
#
#    There are two possible kinds of solutions:
#
#      - Overwrite the distro AppArmor profile using a mason template
#
#      - Use local/binary not to overwrite the distro AppArmor profile
#        but adding, normally, new directories to access/write/execute
#
# Returns:
#
#    Array ref - containing hash ref as elements with the following
#    keys:
#
#      binary - String the binary to set an AppArmor profile
#
#      local - Boolean indicating if we use local implementation or
#              overwrite the distro one
#
#      file - String the path for the new AppArmor profile. If it is a
#             template, it is relative to stubs path. If not, then it
#             is relative to schemas path
#
#      params - Array ref the parameters if it is a mason template
#
#    Default implementation is to have no profiles
#
sub appArmorProfiles
{
    return [];
}

# Method: pidRunning
#
#   Checks if a PID is running
#
# Parameters:
#
#   pid - PID number
#
# Returns:
#
#   boolean - True if it's running , otherise false
sub pidRunning
{
    my ($self, $pid) = @_;
    my $t = new Proc::ProcessTable;
    foreach my $proc (@{$t->table}) {
        ($pid eq $proc->pid) and return 1;
    }
    return undef;
}

# Method: pidFileRunning
#
#   Given a file holding a PID, it gathers it and checks if it's running
#
# Parameters:
#
#   file - file name
#
# Returns:
#
#   pid number - if the file exists, contains a PID and the PID is running
#   undef      - otherwise
#
sub pidFileRunning
{
    my ($self, $file) = @_;
    my $pid = $self->pidFromFile($file);
    if ($pid and $self->pidRunning($pid)) {
        return $pid;
    } else {
        return undef;
    }
}

sub pidFromFile
{
    my ($self, $file) = @_;
    my $pid;
    try {
        my $output = EBox::Sudo::silentRoot("cat $file");
        if (@{$output}) {
            ($pid) = @{$output}[0] =~ m/(\d+)/;
        }
    } catch {
        $pid = undef;
    }
    return $pid;
}

# Method: _preSetConf
#
#   Base method which is called before _setConf. It should be overriden
#   by subclasses if you need something to be done before _setConf is run
#
sub _preSetConf
{
    # default empty implementation. It should be overriden by subclasses as
    # needed
}

sub _hook
{
    my ($self, $type, @params) = @_;

    my $hookfile = EBox::Config::etc() . "hooks/" . $self->{'name'} . "." . $type;
    if (-x "$hookfile") {
        my $log = EBox::logger;
        my $command = $hookfile . " " . join(" ", @params);
        $log->info("Running hook: " . $command);

        EBox::Sudo::root("$command");
    }
}

sub _preSetConfHook
{
    my ($self) = @_;
    $self->_hook('presetconf');
}

sub _postSetConfHook
{
    my ($self) = @_;
    $self->_hook('postsetconf');
}

# Method: _setConf
#
#   Base method to write the configuration. It should be overriden
#   by subclasses as needed
#
sub _setConf
{
    # default empty implementation. It should be overriden by subclasses as
    # needed
}

# Method: _setAppArmorProfiles
#
#   Set the apparmor profiles if AppArmor is installed and the module
#   has configured profiles overriding <appArmorProfiles>
#
sub _setAppArmorProfiles
{
    my ($self) = @_;

    if ( -x APPARMOR_PARSER ) {
        foreach my $profile ( @{$self->appArmorProfiles()} ) {
            $profile->{params} = [] unless ($profile->{params});

            my $targetProfile = APPARMOR_D . $profile->{binary};
            if ( $profile->{local} ) {
                $targetProfile = APPARMOR_D . 'local/' . $profile->{binary};
            }

            if ( $profile->{file} =~ /\.mas$/ ) {
                if ( $self->can('writeConfFile') ) {
                    $self->writeConfFile($targetProfile, $profile->{file},
                                         $profile->{params});
                } else {
                    writeConfFileNoCheck($targetProfile, $profile->{file},
                                         $profile->{params});
                }
            } else {
                my $baseDir = EBox::Config::scripts() . 'apparmor/';
                EBox::Sudo::root("install -m 0644 $baseDir $targetProfile");
            }
            # Reload the parser
            EBox::Sudo::root(APPARMOR_PARSER . ' --write-cache --replace '
                             . APPARMOR_D . $profile->{binary});
        }
    }
}

# Method: _regenConfig
#
#   Base method to regenerate configuration. It should be overriden
#   by subclasses as needed
#
sub _regenConfig
{
    my ($self, @params) = @_;

    $self->_preSetConf(@params);
    $self->_preSetConfHook();
    $self->_setConf(@params);
    $self->_setAppArmorProfiles();
    $self->_postSetConfHook();
}

# Method: _writeFileCreateTmpFile
#
#   Helper method that creates a temporary file for writeFile* methods.
#
sub _writeFileCreateTmpFile
{
    my $oldUmask = umask 0007;
    my ($fh,$tmpfile);
    try {
        ($fh,$tmpfile) = tempfile(DIR => EBox::Config::tmp);
        binmode ($fh, ":encoding(UTF-8)");
        unless($fh) {
            throw EBox::Exceptions::Internal(
                "Could not create temp file in " .
                EBox::Config::tmp);
        }
    } catch ($e) {
        umask $oldUmask;
        $e->throw();
    }
    umask $oldUmask;

    return ($fh, $tmpfile);
}

# Method: _writeFileSave
#
#   Helper method that permanently saves the files created by writeFile
#   methods.
#
#
# Parameters:
#
#   tmpfile     - file where changes are temporary stored
#   file        - file where changes should be saved
#   defaults    - mode, uid and gid for the final file (optional)
#
sub _writeFileSave # (tmpfile, file, defaults)
{
    my ($tmpfile, $file, $defaults) = @_;

    my $mode;
    my $uid;
    my $gid;

    if ((not defined($defaults)) and (not $defaults->{force}) and
            (-e $file) and (my $st = EBox::Sudo::stat($file))
      ) {
        $mode= sprintf("%04o", $st->mode & 07777);
        $uid = $st->uid;
        $gid = $st->gid;

    } else {
        defined $defaults or $defaults = {};
        $mode = exists $defaults->{mode} ?  $defaults->{mode}  : '0644';
        $uid  = exists $defaults->{uid}  ?  $defaults->{uid}   : 0;
        $gid  = exists $defaults->{gid}  ?  $defaults->{gid}   : 0;
    }

    my @commands;
    push (@commands, "/bin/mv $tmpfile '$file'");
    push (@commands, "/bin/chmod $mode '$file'");
    push (@commands, "/bin/chown $uid.$gid '$file'");
    EBox::Sudo::root(@commands);
}

# Method: writeConfFileNoCheck
#
#    It executes a given mason component with the passed parameters over
#    a file. It becomes handy to set configuration files for services.
#    Also, its file permissions will be kept.
#    It is called as class method.
#    XXX : the correct behaviour will be to throw exceptions if file will not be stated and no defaults are provided. It will provide hardcored defaults instead because we need to be backwards-compatible
#
#
# Parameters:
#
#    file      - file name which will be overwritten with the execution output
#    component - mason component
#    params    - parameters for the mason component. Optional. Defaults to no parameters
#    defaults  - a reference to hash with keys mode, uid, gid and force. Those values will be used when creating a new file. (If the file already exists and the force parameter is not set the existent values of these parameters will be left untouched)
#
sub writeConfFileNoCheck # (file, component, params, defaults)
{
    my ($file, $compname, $params, $defaults) = @_;

    my ($fh, $tmpfile) = _writeFileCreateTmpFile();

    my $comp;
    my $customStubCompRoot = EBox::Config::etc() . 'stubs';
    my $interp;
    my $stub = EBox::Config::stubs() . $compname;

    # first try custom stub if it exists
    my $customStub = $customStubCompRoot . '/' . $compname;
    if (-f $customStub) {
        $interp = HTML::Mason::Interp->new(
            comp_root => [ [ custom => $customStubCompRoot],
                           [ default => EBox::Config::stubs] ],
            out_method => sub { $fh->print($_[0]) }
        );
        try {
            EBox::info("Using custom template for $file: $customStub");
            $comp = $interp->make_component(comp_file => $customStub);
            $stub = $customStub;
        } catch ($e) {
            EBox::error("Falling back to default $stub due to exception " .
                         "when processing custom template $customStub: $e");
            $comp = undef;
        }
    }

    if (not $comp) {
        # using default stubs
        $interp = HTML::Mason::Interp->new(
            comp_root => EBox::Config::stubs,
            out_method => sub { $fh->print($_[0]) }
        );
        try {
            $comp = $interp->make_component(comp_file => $stub);
        }  catch ($e) {
            throw EBox::Exceptions::Internal("Compilation of template $stub failed with $e");
        }
    }

    # Workaround bogus mason warnings, redirect stderr to /dev/null to not
    # scare users. New mason version fixes this issue
    my $old_stderr;
    my $tmpErr = EBox::Config::tmp() . 'mason.err';
    open($old_stderr, ">&STDERR");
    open(STDERR, ">$tmpErr");

    try {
        $interp->exec($comp, @{$params});
    } catch ($e) {
        $fh->close();
        throw EBox::Exceptions::Internal("Execution of template $stub failed with $e");
    }
    $fh->close();

    open(STDERR, ">&$old_stderr"); # mason workaround

    _writeFileSave($tmpfile, $file, $defaults);
}

# Method: writeFile
#
#    Writes a file with the given data, owner and permissions.
#
# Parameters:
#
#    file      - file name which will be overwritten with the execution output
#    data      - data to write in the file
#    defaults  - a reference to hash with keys mode, uid, gid and force. Those values will be used when creating a new file. (If the file already exists and the force parameter is not set the existent values of these parameters will be left untouched)
#
sub writeFile # (file, data, defaults)
{
    my ($file, $data, $defaults) = @_;

    my ($fh, $tmpfile) = _writeFileCreateTmpFile();

    $fh->print($data);
    $fh->close();

    _writeFileSave($tmpfile, $file, $defaults);
}

# Method: global
#
#  Gets an EBox::Global instance with the same read-only status as the module
#
#  As EBox::Module::Base does not store config, this always returns a regular instance
#
sub global
{
    my ($self) = @_;

    return EBox::Global->getInstance();
}

# Method: backupFilesToArchive
#
#  Backup all the given  files in a compressed archive in the given dir
#  This is used to create backups
#
#   Parameters:
#   dir - directory where the archive will be stored
#   files - array reference with path to be backed up. Paths are taken recursive
sub backupFilesToArchive
{
    my ($self, $dir, $files) = @_;

    my @filesToBackup = @{ $files };
    @filesToBackup or
        return;

    my $archive = $self->_filesArchive($dir);

    my $firstFile  = shift @filesToBackup;
    my $archiveCmd = "tar  -C / -cf $archive --atime-preserve --absolute-names --preserve-permissions --same-owner '$firstFile'";
    EBox::Sudo::root($archiveCmd);

    # we append the files one per one bz we don't want to overflow the command
    # line limit. Another approach would be to use a file catalog however I think
    # that for only a few files (typical situation for now) the append method is better
    foreach my $file (@filesToBackup) {
        $archiveCmd = "tar -C /  -rf $archive --atime-preserve --absolute-names --preserve-permissions --preserve-order --same-owner '$file'";
        EBox::Sudo::root($archiveCmd);
    }
}

# Method: restoreFilesFromArchive
#
#  Restore all the files from the  tar archive in backup dir
#  This is used to restore backups
#
#   Parameters:
#   dir - directory where the archive is stored
sub restoreFilesFromArchive
{
    my ($self, $dir) = @_;
    my $archive = $self->_filesArchive($dir);

    (-f $archive) or return;

    my $restoreCmd = "tar  -C / -xf $archive --atime-preserve --absolute-names --preserve-permissions --preserve-order --same-owner";
    EBox::Sudo::root($restoreCmd);
}


sub searchContents
{
    my ($searchStringRe) = @_;
    return [];
}

1;
