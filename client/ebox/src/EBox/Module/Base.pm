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

package EBox::Module::Base;

use strict;
use warnings;

use File::Copy;
use Proc::ProcessTable;
use EBox;
use EBox::Util::Lock;
use EBox::Config;
use EBox::Global;
use EBox::Sudo;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::ServiceManager;
use EBox::DBEngineFactory;
use HTML::Mason;
use File::Temp qw(tempfile);
use Fcntl qw(:flock);
use Error qw(:try);
use Time::Local;

# Method: _create
#
#   Base constructor for a module
#
# Parameters:
#
#   name - String module's name
#   domain - String locale domain
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
sub _create # (name, domain?)
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    $self->{name} = delete $opts{name};
    $self->{domain} = delete $opts{domain};
    $self->{title} = delete $opts{title};
    my $domain = settextdomain($self->{domain});
    $self->{printableName} = __(delete $opts{printableName});
    settextdomain($domain);
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
    return EBox::Global::readModInfo($self->{name});
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
    my $self = shift;

    $self->_lock();
    my $global = EBox::Global->getInstance();
    my $log = EBox::logger;
    $log->info("Restarting service for module: " . $self->name);
    $self->_saveConfig();
    try {
        $self->_regenConfig();
    } finally {
        $global->modRestarted($self->name);
        $self->_unlock();
    };
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
    }
    finally {
      $self->_unlock();
    };
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

# Method: setAsChanged
#
#   Sets the module as changed
#
sub setAsChanged
{
    my ($self) = @_;
    my $name = $self->name;

    my $global = EBox::Global->getInstance();

    return if $global->modIsChanged($name);

    $global->modChange($name);
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
#  fullRestore - wether we want to do a full restore as opposed a configuration-only restore (default: false)
#
sub restoreBackup # (dir, %options)
{
    my ($self, $dir, %options) = @_;
    defined $dir or throw EBox::Exceptions::InvalidArgument('directory');

    my $backupDir = $self->backupDir($dir);
    (-d $backupDir) or throw EBox::Exceptions::Internal("$backupDir must be a directory");

    if (not $options{dataRestore}) {
        $self->aroundRestoreConfig($backupDir);
    }

    if ($options{fullRestore} or $options{dataRestore}) {
        $self->extendedRestore(dir => $backupDir, %options);
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

# default implementation: do nothing
sub extendedRestore
{
  # my %params = @_;
  # my $dir = $params{dir};
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
# specila types of modules (GConfModule p.e) to call another method
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
# types of modules (GConfModule p.e) to call another method alongside with
# restoreConfig transparently
# normally ebox modules does not need to override this
#
# Parameters:
#  dir - directory where are located the backup files
#
sub aroundRestoreConfig
{
    my ($self, $dir) = @_;

    $self->restoreConfig($dir);
}

# Method: initChangedState
#
#    called before module is in the changed state.
sub initChangedState
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    $global->modIsChanged($self->name) and
        throw EBox::Exceptions::Internal($self->name . ' module already has changed state');
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
    if(defined($winfo)) {
        my $widget = new EBox::Dashboard::Widget($winfo->{'title'},$self->{'name'},$name);
        #fill the widget
        $widget->{'module'} = $self->{'name'};
        $widget->{'default'} = $winfo->{'default'};
        $widget->{'order'} = $winfo->{'order'};
        my $wfunc = $winfo->{'widget'};
        &$wfunc($self, $widget, $winfo->{'parameter'});
        return $widget;
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

# Method: domain
#
#   Returns the locale domain for the current module instance
#
# Returns:
#
#   strings - locale domain
#
sub domain
{
    my $self = shift;

    if (defined $self->{domain}) {
        return $self->{domain};
    } else {
        return 'ebox';
    }
}

# Method: package
#
#   Returns the package name
#
# Returns:
#
#   strings - package name
#
# TODO Change domain  for package which
# is more general. But we must ensure no module uses it directly
sub package
{
    my $self = shift;

    return $self->domain();
}

# Method: wizardPages
#
#   Return the an array containin the wizard pages for the module. It should
#   be overriden by subclasses as needed
#
# Returns:
#
#   An array ref of URL's of ordered wizard pages for this module. This pages
#   must be implemented using WizardPage as base class.
#
sub wizardPages
{
    # default implementation: no wizards
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
#   boolean - True if it's running , otherise false
#
sub pidFileRunning
{
    my ($self, $file) = @_;
    my $pid;
    try {
        my $output = EBox::Sudo::root("cat $file");
        ($pid) = @{$output}[0] =~ m/(\d+)/;
    } otherwise {
        return undef;
    };
    defined($pid) or return undef;
    ($pid ne "") or return undef;
    return $self->pidRunning($pid);
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

# Method: _regenConfig
#
#   Base method to regenerate configuration. It should be overriden
#   by subclasses as needed
#
sub _regenConfig
{
    my ($self) = @_;

    my @params = (@_);
    shift(@params);

    $self->_preSetConf(@params);
    $self->_preSetConfHook();
    $self->_setConf(@params);
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
        unless($fh) {
            throw EBox::Exceptions::Internal(
                "Could not create temp file in " .
                EBox::Config::tmp);
        }
    }
    finally {
        umask $oldUmask;
    };

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
    if ((not defined($defaults)) and (-e $file) and
            (my $st = EBox::Sudo::stat($file))) {
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
#    defaults  - a reference to hash with keys mode, uid and gid. Those values will be used when creating a new file. (If the file already exists the existent values of these parameters will be left untouched)
#
sub writeConfFileNoCheck # (file, component, params, defaults)
{
    my ($file, $compname, $params, $defaults) = @_;

    my ($fh, $tmpfile) = _writeFileCreateTmpFile();

    my $interp = HTML::Mason::Interp->new(
        comp_root => EBox::Config::stubs,
        out_method => sub { $fh->print($_[0]) });
    my $comp;

    try {
        my $stub = EBox::Config::stubs() . $compname;
        my $customStub = EBox::Config::etc() . "stubs/$compname";
        if (-f $customStub) {
            try {
                EBox::info("Using custom template for $file: $customStub");
                $comp = $interp->make_component(comp_file => $customStub);
            } otherwise {
                my $ex = shift;
                EBox::error("Falling back to default $stub due to exception " .
                            "processing custom template $customStub: $ex");
                $comp = $interp->make_component(comp_file => $stub);
            };
        } else {
            $comp = $interp->make_component(comp_file => $stub);
        }
    } otherwise {
        my $ex = shift;
        throw EBox::Exceptions::Internal("Template $compname failed with $ex");
    };

    # Workaround bogus mason warnings, redirect stderr to /dev/null to not
    # scare users. New mason version fixes this issue
    my $old_stderr;
    my $tmpErr = EBox::Config::tmp() . 'mason.err';
    open($old_stderr, ">&STDERR");
    open(STDERR, ">$tmpErr");

    $interp->exec($comp, @{$params});
    $fh->close();

    open(STDERR, ">&$old_stderr");

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
#    defaults  - a reference to hash with keys mode, uid and gid. Those values will be used when creating a new file. (If the file already exists the existent values of these parameters will be left untouched)
#
sub writeFile # (file, data, defaults)
{
    my ($file, $data, $defaults) = @_;

    my ($fh, $tmpfile) = _writeFileCreateTmpFile();

    $fh->print($data);
    $fh->close();

    _writeFileSave($tmpfile, $file, $defaults);
}

# Method: report
#
#   returns the reporting information provided by the module
#
#   Returns:
#     hash reference with the report information
#
#     If not overriden by the subclasses it will return undef
sub report
{
    my ($self) = @_;
    return undef;
}

# Method: runMonthlyQuery
#
#   Runs a query in the database for all the months in t erange,
#   organizing the data for its use in the report
#
# Parameters:
#
#       beg - initial year-month (i.e., '2009-10')
#       end - final year-month
#       query - SQL query without any dates
#       options - hash containing options for the processing of the results
#          key - if key is provided, multiple rows will be processed and
#                hashed by the content of the key field
#
#   Returns:
#     hash reference with the report information
#
#     If not overriden by the subclasses it will return undef
sub runMonthlyQuery
{
    my ($self, $beg, $end, $query, $options) = @_;

    defined($options) or $options = {};
    my $key = $options->{'key'};

    my $db = EBox::DBEngineFactory::DBEngine();

    my @fields = @{ $self->_monthlyQueryDataFields($db, $query, $key) };
    my $data = $self->_emptyMonthlyQueryData($db, $beg, $end, $query, $options, \@fields);

#    use Data::Dumper;
#    print "EMPTY DATA " . Dumper($data) . "\n";

#    return $data;

    my ($begyear, $begmonth) = split('-', $beg);
    my ($endyear, $endmonth) = split('-', $end);

    my $year = $begyear;
    my $month = $begmonth;

    my $orig_where = $query->{'where'};

    my $nMonth = 0;

    while (
        ($year < $endyear) or
        (($year == $endyear) and ($month <= $endmonth))
    ) {
        my $date_where = "date >= '$year-$month-01 00:00:00' AND " .
            "date < date '$year-$month-01 00:00:00' + interval '1 month'";
        my $new_where;
        if (defined($orig_where)) {
            $new_where = "$orig_where AND $date_where";
        } else {
            $new_where = "$date_where";
        }
        $query->{'where'} = $new_where;

        my $results = $db->query_hash($query);
        if (@{$results}) {

            if (defined($key)) {
                for my $r (@{$results}) {
                    my $keyname = $r->{$key};
                    for my $f (@fields) {
                        my $val = $r->{$f};
                        if (defined $val) {
                            $data->{$keyname}->{$f}->[$nMonth] = $val;
                        }

                    }
                }
            } else {
                for my $r (@{$results}) {
                    for my $f (@fields) {
                        my $val = $r->{$f};
                        if (defined $val) {
                            $data->{$f}->[$nMonth] = $val;
                        }

                    }
                }
            }
        }

        $nMonth += 1;

        if($month == 12) {
            $month = 1;
            $year++;
        } else {
            $month++;
        }
    }
    return $data;
}


sub _monthlyQueryDataFields
{
    my ($self, $db, $query, $key) = @_;
    my %fieldsQuery = %{ $query };
    $fieldsQuery{limit} = 1;

    my @fields;
    my $resultFieldsQuery = $db->query_hash(\%fieldsQuery);
    if (defined $resultFieldsQuery and (exists $resultFieldsQuery->[0])) {
        @fields =   (keys %{@{$resultFieldsQuery}[0]});
    }

    if ($key) {
        @fields = grep {  $_ ne $key} @fields;
    }

    return \@fields;

}

sub _emptyMonthlyQueryData
{
    my ($self, $db, $beg, $end, $query, $options, $fields_r) = @_;

    my ($begyear, $begmonth) = split('-', $beg);
    my ($endyear, $endmonth) = split('-', $end);

    my $length = ($endyear - $begyear)*12 + ($endmonth - $begmonth);
    my $makeResults_r = sub { return [ map { 0 } (0 .. $length)  ] };

    my $key = $options->{'key'};
    my @keys;
    if ($key) {
        my $sql = "SELECT DISTINCT $key FROM "  . $query->{from} . ";";
        my $res = $db->query($sql);
        @keys = map {  $_->{ $key } }  @{ $res };

    }

    my @fields = @{ $fields_r };

    my $data = {};
    if ($key) {
        foreach my $key (@keys) {
            $data->{$key} = {};
            foreach my $field (@fields) {
                $data->{$key}->{$field} = $makeResults_r->();
            }
        }
    } else {
        foreach my $field (@fields) {
            $data->{$field} = $makeResults_r->();
        }
    }

    return $data;
}

sub runQuery
{
    my ($self, $beg, $end, $query) = @_;

    my $data = {};
    my $db = EBox::DBEngineFactory::DBEngine();

    my ($begyear, $begmonth) = split('-', $beg);
    my ($endyear, $endmonth) = split('-', $end);

    my $orig_where = $query->{'where'};
    my $date_where = "date >= '$begyear-$begmonth-01 00:00:00' AND " .
                "date < date '$endyear-$endmonth-01 00:00:00' + interval '1 month'";
    my $new_where;
    unless (defined($query->{'options'}) and
            defined($query->{'options'}->{'no_date_in_where'}) and
            $query->{'options'}->{'no_date_in_where'}) {
        if (defined($orig_where)) {
            $new_where = "$orig_where AND $date_where";
        } else {
            $new_where = "$date_where";
        }
        $query->{'where'} = $new_where;
    }
    $query->{'from'} =~s/_date_/$date_where/g;

    my $results = $db->query_hash($query);
    if (@{$results}) {
        my @fields = keys(%{@{$results}[0]});

        for my $f (@fields) {
            $data->{$f} = [];
        }

        for my $r (@{$results}) {
            for my $f (@fields) {
                push(@{$data->{$f}}, $r->{$f});
            }
        }
        return $data;
    }
    return undef;
}

sub runCompositeQuery
{
    my ($self, $beg, $end, $query, $key, $next_query) = @_;

    my $data = {};
    my $db = EBox::DBEngineFactory::DBEngine();

    my ($begyear, $begmonth) = split('-', $beg);
    my ($endyear, $endmonth) = split('-', $end);

    my $orig_where = $query->{'where'};
    my $date_where = "date >= '$begyear-$begmonth-01 00:00:00' AND " .
                "date < date '$endyear-$endmonth-01 00:00:00' + interval '1 month'";
    my $new_where;
    if (defined($orig_where)) {
        $new_where = "$orig_where AND $date_where";
    } else {
        $new_where = "$date_where";
    }
    $query->{'where'} = $new_where;

    my $results = $db->query_hash($query);
    my @keys = map { $_->{$key} } @{$results};
    (@keys) or return undef;

    $orig_where = $next_query->{'where'};
    for my $k (@keys) {
        $data->{$k} = {};
        my $date_where = "date >= '$begyear-$begmonth-01 00:00:00' AND " .
                    "date < date '$endyear-$endmonth-01 00:00:00' + interval '1 month'";
        my $new_where;
        if (defined($orig_where)) {
            $new_where = "$orig_where AND $date_where";
        } else {
            $new_where = "$date_where";
        }
        my $regex = '_' . $key . '_';
        $new_where =~ s/$regex/$k/;
        $next_query->{'where'} = $new_where;

        $results = $db->query_hash($next_query);
        if (@{$results}) {
            my @fields = keys(%{@{$results}[0]});

            for my $f (@fields) {
                $data->{$k}->{$f} = [];
            }

            for my $r (@{$results}) {
                for my $f (@fields) {
                    push(@{$data->{$k}->{$f}}, $r->{$f});
                }
            }
        }
    }
    return $data;
}


# get the start date as timestamp for a new consolidation
sub _consolidateReportStartDate
{
    my ($self, $db, $target_table, $query) = @_;

    my $res = $db->query_hash({
            'select' => 'EXTRACT(EPOCH FROM last_date) AS date',
            'from' => 'report_consolidation',
            'where' => "report_table = '$target_table'"
                              });

    my $date;
    if(@{$res}) {
        my $row = shift(@{$res});
        $date = $row->{'date'};
        $date += 1; # we start consolidation in the next second
    } else {
        # get a reasonable first date from timestamp of source tables
        $res = $self->_unionQuery($db, {
                'select' => 'EXTRACT(EPOCH FROM timestamp) AS date',
                'from' => $query->{'from'},
                'order' => "timestamp",
                'limit' => 1
                                       });
        my $row = shift(@{$res});

        #if there is no rows in source tables for consolidation, return undef
        defined($row) or
            return undef;

        $date = $row->{date};


        #later we call update so we need to have something inserted
        $db->unbufferedInsert('report_consolidation', {
                'report_table' => $target_table,
                'last_date' => 'epoch'
            });
        }

    return $date;
}

sub consolidateReportFromLogs
{
    my ($self) = @_;

    my $queries = $self->consolidateReportQueries();
    return $self->_consolidateReportFromDB(
                                    $queries,
                                    \&_consolidationValuesForMonth
                                   );
}


sub _consolidateReportFromDB
{
    my ($self, $queries, $monthlyValuesMethod_r) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();

    my $consolidationStartTime = time();
    my $gmConsolidationStartTime = gmtime($consolidationStartTime);

    for my $q (@{$queries}) {
        my $target_table = $q->{'target_table'};
        my $query = $q->{'query'};

        my $date = $self->_consolidateReportStartDate($db,
                                                      $target_table,
                                                      $query);

        $date or
            next;

        my @time = localtime($date);
        my $year = $time[5]+1900;
        my $month = $time[4]+1;
        my $day =  $time[3];
        my $hour = $time[2] . ':' . $time[1] . ':' . $time[0];
        my $timeTs = $date; # no tz

        my $curTimeTs = $consolidationStartTime; # no tz
        my @curtime = localtime($curTimeTs);
        my $curyear = $curtime[5]+1900;
        my $curmonth = $curtime[4]+1;

        # precalculed query data
        if ( exists $query->{'where'} ) {
            $query->{orig_where} = $query->{'where'};
        }
        $query->{from_tables} = [ split '\s*,\s*', $query->{from} ];

        while ( $timeTs <  $curTimeTs) {
            my $beginTime = "$year-$month-$day $hour";
            my $beginMonth = "$year-$month-01 00:00:00";

            my $results = $monthlyValuesMethod_r->($self, $db, $query, $beginTime, $beginMonth);
            if (@{$results}) {
                my $updateOverwrite = 0;
                if (exists $query->{updateMode} and ($query->{updateMode} eq 'overwrite')) {
                    $updateOverwrite = 1;
                }
                # query to check if the record exists already
                my @fields = keys(%{@{$results}[0]});

                # these are the fields which identify a line as not repeatable
                my @identityFields;
                if (exists $query->{group}) {
                    push @identityFields, split(/ *, */,$query->{'group'});
                }
                if (exists $query->{key}) {
                    push @identityFields, $query->{key};
                }

                for my $r (@{$results}) {
                    my @from = ($target_table);
                    my @where;

                    for my $f (@identityFields) {
                        if (exists $r->{$f} and defined $r->{$f}) {
                            push(@where, $f . " = '" . $r->{$f} . "'");
                        }

                        # try to detect another required 'from' this will
                        # fail if column name doesn't specify table if
                        # there is one of more dot in the name it will fail too
                        my (@portions) = split '\.', $f;
                        if (@portions == 2) {
                            push @from, $portions[0];
                        }
                    }
                    push(@where, "date = '$beginMonth'");

                    my $res = $db->query_hash({
                            'from' => join(',', @from),
                            'where' => join(' AND ', @where)
                            });
                    if (@{$res}) {
                        # record exists, we will udpate it
                        my $row = shift(@{$res});
                        my $new_row = {};
                        for my $k (keys %$r) {
                            if (!grep(/^$k$/, @identityFields)) {
                                if ($updateOverwrite) {
                                    $new_row->{$k} =  $r->{$k};
                                } else {
                                    # sum values
                                    $new_row->{$k} = $row->{$k} + $r->{$k};
                                }
                            }
                        }

                        $db->update($target_table, $new_row, \@where);
                    } else {
                        # record does not exists, insert it
                        $r->{'date'} = $beginMonth;
                        $db->unbufferedInsert($target_table, $r);
                    }
                }

                # update last consolidation time

               $db->update('report_consolidation',
                    { 'last_date' => "'$gmConsolidationStartTime'" },
                    [ "report_table = '$target_table'" ],
                );
            }

            # only the first loop could  have a hour/day diffetent than the 00:00:00/1
            $hour = '00:00:00';
            $day = 1;
            if($month == 12) {
                $month = 1;
                $year++;
            } else {
                $month++;
            }

            # update timeTs for the next month
            $timeTs = timelocal(0,0,0, 1,($month-1),($year-1900));
        }
    }
}


sub _consolidationValuesForMonth
{
    my ($self, $db, $query, $beginTime, $beginMonth) = @_;

    my @dateWherePortions;
    foreach my $table (@{ $query->{from_tables} }) {
        push @dateWherePortions, "($table.timestamp >= '$beginTime' AND " .
            "$table.timestamp < date '$beginMonth' + interval '1 month')";

    }

    my $date_where = join ' AND ', @dateWherePortions;

    my $new_where;
    if (exists $query->{orig_where}) {
        $new_where = $query->{orig_where} . " AND $date_where";
    } else {
        $new_where = "$date_where";
    }
    $query->{'where'} = $new_where;

    my $results = $db->query_hash($query);
    return $results;
}


sub _lastConsolidationValuesForMonth
{
    my ($self, $db, $origQuery, $beginTime, $beginMonth) = @_;
    my $query = { %{ $origQuery }  };

    my @dateWherePortions;
    foreach my $table (@{ $query->{from_tables} }) {
        push @dateWherePortions, "($table.timestamp >= '$beginTime' AND " .
            "$table.timestamp < date '$beginMonth' + interval '1 month')";
    }

    my $date_where = join ' AND ', @dateWherePortions;

    if (exists $query->{where}) {
        $query->{where} = $query->{where} . " AND $date_where";
    } else {
        $query->{where} = "$date_where";
    }

    $query->{order} = 'timestamp DESC';
    $query->{limit} = 1;

    my $key = $query->{key};
    if (defined $key) {
        my $from = join ', ', @{ $query->{from_tables} };
        my $sql = qq{SELECT DISTINCT $key FROM $from WHERE }. $query->{where};
        my $keyResults = $db->query($sql);
        my @keyValues = map { $_->{$key}  } @{ $keyResults };

        my @results;
        my $origWhere = $query->{where};
        foreach my $keyValue (@keyValues) {
            $query->{where} = $origWhere . " AND $key = '$keyValue'";
            push @results, @{ $db->query_hash($query) };
        }

        return \@results;
    } else {
        return $db->query_hash($query);
    }
}


# Method: consolidateReportQueries
#
# This method defines how to consolidate for the report the database logs of this
# module, using an array including an entry for each table, such as:
#
#         {
#             'target_table' => 'samba_access_report',
#             'query' => {
#                 'select' => 'username, COUNT(event) AS operations',
#                 'from' => 'samba_access',
#                 'group' => 'username'
#             }
#         },
#
#
#
#
# 'target_table' defines the table where the consolidated data will be stored.
# The data will considerate using the provided query. The format of the query is
# the same of <EBox::PgDBEngine::query_hash>. But with the following caveats:
#
#
#
#  - key : this signals a single field as part of the key fields of a row. The
#  other keyfields are the ones from a possible group clause. The query needs
#  either a group clause or a key option or it will consolidate one value per month
#
#  - updateMode : this signals what to do when you need to update a row. A row
#  will be updated instead of inserted when its date and key fields (group + key)
#  are identical. Available update modes:
#
#  - sum: the non-key field are added together (default)
#  - overwrite: the non-key fields are overwritten with the last value
#
#  This data will be used to call consolidateReportFromLogs
sub consolidateReportQueries
{
    return [];
}

sub logReportInfo
{
    return [];
}

# Method: consolidateReportInfoQueries
#
# This method is used to consolidate data from data tables which has been
# populated by the logReportInfo method. It call consolidateReportInfoQueries fr
# that.
#
# The difference between consolidateReportFromLogs and
# consolidateReportInfoQueries is that the last one only takes the latest value
# or the latest value for each of the values of the 'key' field.
#
# Another difference is that the queries have s default update mode the 'overwrite'
# mode instead o 'add'
sub consolidateReportInfoQueries
{
    return [];
}

sub consolidateReportInfo
{
    my ($self) = @_;

    my $queries = $self->consolidateReportInfoQueries();
    # putting the default update mode
    foreach my $q (@{  $queries}) {
        if (not exists $q->{query}->{updateMode}) {
            $q->{query}->{updateMode} = 'overwrite';
        }
    }

    return $self->_consolidateReportFromDB(
                                    $queries,
                                    \&_lastConsolidationValuesForMonth
                                   );
}

# if this is neccesary in more places we will move it to PgDbEngine
sub _unionQuery
{
    my ($self, $dbengine, $orig_query) = @_;
    my %query = %{ $orig_query };

    my @tables = split '\s*,\s*', $query{from};

    my @tableQueries;
    foreach my $table (@tables) {
        $query{from} = $table;
        my $tableSql = '(' . $dbengine->query_hash_to_sql(\%query, 0) . ')';
        push @tableQueries, $tableSql;
    }

    my $sql = join ' UNION ' , @tableQueries;
    $sql .= ';';

    return $dbengine->query($sql);
}

1;
