# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::Software;

use base qw(EBox::Module::Config);

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Module::Base;
use EBox::ProgressIndicator;
use EBox::Sudo;

use Digest::MD5;
use TryCatch;
use Storable qw(fd_retrieve store retrieve);
use Fcntl qw(:flock);
use AptPkg::Cache;

use constant {
    LOCK_FILE      => EBox::Config::tmp() . 'ebox-software-lock',
    LOCKED_BY_KEY  => 'lockedBy',
    LOCKER_PID_KEY => 'lockerPid',
    CRON_FILE      => '/etc/cron.d/zentyal-auto-updater',
};

my @COMM_PKGS = qw(zentyal-jabber zentyal-asterisk zentyal-mail zentyal-webmail zentyal-zarafa);

# Group: Public methods

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name => 'software',
        printableName => __('Software Management'),
        @_);
    bless($self, $class);
    return $self;
}

# Method: listEBoxPkgs
#
#       Get the list of the Zentyal packages with information about them.
#
#       The cache is not used anymore and packages are got from real time.
#
# Returns:
#
#   array ref of hashes holding the following keys:
#
#   name - name of the package
#   description - short description of the package
#   version - version installed (if any)
#   avail - latest version available
#   removable - true if the package can be removed
#       depends - array ref containing the names of the package
#                 dependencies to install this package
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listEBoxPkgs
{
    my ($self) = @_;

    my $eboxlist = [];

    $eboxlist = $self->_getInfoEBoxPkgs();

    return $eboxlist;
}

# Method: listBrokenPkgs
#
#       Get the list of the not properly installed Zentyal packages
#       with information about them.
#
# Returns:
#
#   array ref of hashes holding the following keys:
#
#   name - name of the package
#   description - short description of the package
#   version - version installed
#
sub listBrokenPkgs
{
    my ($self) = @_;

    my $cache = $self->_cache();

    my @list;
    for my $pack (@{$self->_brokenPackages()}) {
        my $pkg = $cache->packages()->lookup($pack);
        my %data;
        $data{'name'} = $pkg->{Name};
        $data{'description'} = $pkg->{ShortDesc};
        if ($cache->{$pack}{CurrentVer}) {
            $data{'version'} = $cache->{$pack}{CurrentVer}{VerStr};
        }
        push (@list, \%data);
    }
    return \@list;
}

# Method: installPkgs
#
#   Installs a list of packages via apt
#
# Parameters:
#
#   array -  holding the package names
#
# Returns:
#
#       <EBox::ProgressIndicator> - an instance of the progress
#       indicator to indicate how the installation is working
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub installPkgs # (@pkgs)
{
    my ($self, @pkgs) = @_;

    $self->_isAptReady();
    $self->_isModLocked();

    if (not @pkgs) {
        EBox::info("No packages to install");
        return;
    }

    my $executable = EBox::Config::share() . "/zentyal-software/install-packages @pkgs";
    my $progress = EBox::ProgressIndicator->create(
        totalTicks => scalar @pkgs,
        executable => $executable,
       );
    $progress->runExecutable();
    return $progress;
}

# Method: removePkgs
#
#   Removes a list of packages via apt
#
# Parameters:
#
#   array -  holding the package names
#
# Returns:
#
#       <EBox::ProgressIndicator> - an instance of the progress
#       indicator to indicate how the removal is working
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
sub removePkgs # (@pkgs)
{
    my ($self, @pkgs) = @_;

    $self->_isAptReady();
    $self->_isModLocked();

    if (not @pkgs) {
        EBox::info("No packages to remove");
        return;
    }

    my $executable = EBox::Config::share() .
      "/zentyal-software/remove-packages @pkgs";
    my $progress = EBox::ProgressIndicator->create(
            totalTicks => scalar @pkgs,
            executable => $executable,
            );
    $progress->runExecutable();
    return $progress;
}

# Method: updatePkgList
#
#   Update the package list
#
# Returns:
#
#       1 - if the update goes fancy well
#
#       0 - An error has ocurred
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub updatePkgList
{
    my ($self) = @_;

    $self->_isModLocked();
    $self->_isAptReady();

    my $cmd ='/usr/bin/apt-get update -q';
    try {
        EBox::Sudo::root($cmd);
        return 1;
    } catch (EBox::Exceptions::Internal $e) {
        EBox::error("Error updating package list");
        return 0;
    }
}

sub _packageListFile
{
    my ($self, $ebox) = @_;

    my $filename = 'packagelist';
    if ($ebox) {
        $filename .= '-ebox';
    }
    my $file = EBox::Config::tmp . $filename;
    return $file;
}

# Method: listUpgradablePkgs
#
#   Returns a list of those packages which are ready to be upgraded
#
# Parameters:
#
#   clear - Boolean if set to 1, forces the cache to be cleared
#
#       excludeEBoxPackages - Boolean not return zentyal packages (but
#                             they are saved in the cache anyway)
#
# Returns:
#
#   array ref - holding hashes ref containing keys:
#                   'name' - package's name
#                   'description' package's short description
#                   'version' - package's latest version
#                   'security' - flag indicating if the update is a security one
#                   'changelog' - package's changelog from current version
#                                 till last one (TODO)
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listUpgradablePkgs
{
    my ($self, $clear, $excludeEBoxPackages) = @_;

    my $upgrade = [];

    my $file = $self->_packageListFile(0);
    my $alreadyGet = 0;

    if (defined($clear) and ($clear == 1)) {
        unlink $file;
    } elsif (-f $file) {
        try {
            $upgrade = retrieve($file);
            $alreadyGet = 1;
        } catch ($ex) {
            EBox::error("Error getting list upgradable packages: $ex. Refreshing file");
            unlink $file;
        }
    }

    if (not $alreadyGet) {
        $self->_isModLocked();
        $upgrade = $self->_getUpgradablePkgs();
        store($upgrade, $file);
    }

    if ($excludeEBoxPackages) {
        $upgrade = $self->_excludeEBoxPackages($upgrade);
    }

    return $upgrade;
}

sub _excludeEBoxPackages
{
    my ($self, $list) = @_;
    my @withoutEBox = grep { $_->{'name'} !~ /^zentyal.*/ } @{ $list };
    return \@withoutEBox;
}

# Method: listPackageInstallDepends
#
#   Returns a list of those ebox packages which will be installed when
#   trying to install a given set of packages
#
# Parameters:
#
#   packages - an array with the names of the packages being installed
#
# Returns:
#
#   array ref - holding the names of the ebox packages which will be
#               installed
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageInstallDepends
{
    my ($self, $packages) = @_;
    return $self->_packageDepends('install', $packages);
}

# Method: listPackageDescription
#
#   Returns a list of short descriptions of each package in the list.
#
# Parameters:
#
#   packages - an array with the names of the packages
#
# Returns:
#
#   array ref - holding the short descriptions of the packages
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageDescription
{
    my ($self, $packages) = @_;

    my $cache = $self->_cache();

    my @list;
    for my $pack (@$packages) {
        my $pkgCache = $cache->packages()->lookup($pack) or next;
        push(@list, $pkgCache->{ShortDesc});
    }
    return \@list;
}

# Method: listPackageRemoveDepends
#
#   Returns a list of those ebox packages which will be removed when
#   trying to remove a given set of packages
#
# Parameters:
#
#   packages - an array with the names of the packages being removed
#
# Returns:
#
#   array ref - holding the names of the ebox packages which will be removed
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageRemoveDepends
{
    my ($self, $packages) = @_;
    return $self->_packageDepends('remove', $packages);
}

sub _packageDepends
{
    my ($self, $action, $packages) = @_;
    if (($action ne 'install') and ($action ne 'remove')) {
        throw EBox::Exceptions::Internal("Bad action: $action");
    }

    $self->_isAptReady();
    $self->_isModLocked();

    my $aptCmd = "apt-get --no-install-recommends --simulate $action " .
      join ' ',  @{ $packages };

    my $header;
    if ($action eq 'install') {
        $header = 'Inst';
    }
    elsif ($action eq 'remove') {
        $header = 'Remv'
    }

    my $output;
    try {
        $output = EBox::Sudo::root($aptCmd);
    } catch (EBox::Exceptions::Command $e) {
        my $aptError;
        foreach my $line (@{ $e->error() }) {
            if ($line =~ m/^E: (.*)$/) {
                # was an apt error, reformatting
                foreach my $line (@{ $e->output() }) {
                    if ($line =~ m/\.\.\.$/) {
                        # current action line, ignoring
                        next;
                    }
                    chomp $line;
                    $aptError .= $line . '<br/>';
                }
            }
        }
        if ($aptError) {
            throw EBox::Exceptions::External($aptError);
        } else {
            $e->throw();
        }
    }

    my @packages = grep {
    $_ =~ m/
              ^$header\s  # requested operation
              zentyal-    # is a Zentyal package
             /x
    } @{ $output };

    @packages = map {
        chomp $_;
        my ($h, $p) = split '\s', $_;
        $p;
    } @packages;

   return \@packages;
}

# check whether APT is ready, if not throws exception
sub _isAptReady
{
    my $testCmd = 'LANG=C apt-get install --dry-run -qq -y coreutils';
    my $unreadyMsg;
    try {
        EBox::Sudo::root($testCmd);
    } catch (EBox::Exceptions::Command $e) {
        my $stderr = join '', @{ $e->error() };
        if ($stderr =~ m/Unable to lock the administration directory/) {
            $unreadyMsg = __('Cannot use software package manager. Probably is currently being used by another process. You can either wait or kill the process.');
        } else {
            $unreadyMsg = __x('Cannot use software package manager. Error output: {err}',
                              err => $stderr);
        }
    }

    if ($unreadyMsg) {
        throw EBox::Exceptions::External($unreadyMsg);
    }
}

# Method: isInstalled
#
#   Checks if the package is installed
#
# Parameters:
#
#   name - name of the package
#
# Returns:
#
#   1 is package is intalled otherwise returns 0
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub isInstalled
{
    my ($self, $name) = @_;

    my $cache = $self->_cache();
    my $pkg = $cache->{$name};
    if ($pkg and $pkg->{InstState} == AptPkg::State::Ok
             and $pkg->{CurrentState} == AptPkg::State::Installed) {
        return 1;
    } else {
        return 0;
    }
}

# Method: getAutomaticUpdates
#
#   Returns if the automatic update mode is enabled
#
#       Check if there are automatic updates from QA, if so, then
#       return always true.
#
# Returns:
#
#   boolean - true if it's enabled, otherwise false
sub getAutomaticUpdates
{
    my ($self) = @_;

    unless (EBox::Global->communityEdition()) {
        if ($self->qaUpdatesAlwaysAutomatic()) {
            return 1;
        }
    }

    my $auto = $self->get_bool('automatic');
    return $auto;
}

# Method: qaUpdatesAlwaysAutomatic
#
#  Returns:
#   boolean - whether if the system is configured to install autmatically
#             the qa updates packages
sub qaUpdatesAlwaysAutomatic
{
    return EBox::Config::boolean('qa_updates_always_automatic');
}

# Method: setAutomaticUpdates
#
#   Set the automatic update mode. If it's enabled the system will
#   fetch all the updates silently and automatically.
#
#       If the software is QA updated, then you cannot change this parameter.
#
# Parameters:
#
#   auto  - true to enable it, false to disable it
sub setAutomaticUpdates # (auto)
{
    my ($self, $auto) = @_;

    unless (EBox::Global->communityEdition()) {
        my $key = 'qa_updates_always_automatic';
        my $alwaysAutomatic = EBox::Config::configkey($key);
        defined $alwaysAutomatic or $alwaysAutomatic = 'true';

        if (lc($alwaysAutomatic) eq 'true') {
            throw EBox::Exceptions::External(
                __x('You cannot modify the automatic update using QA updates from Web UI. '
                      . 'To disable automatic updates, edit {conf} and disable {key} key.',
                    conf => EBox::Config::etc() . 'zentyal.conf',
                    key  => $key));
        }
    }
    $self->set_bool('automatic', $auto);
}

# Method: setAutomaticUpdatesTime
#
#      Set the time when the automatic update process starts
#
# Parameters:
#
#      time - String in HH:MM format
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the time parameter
#      is not in correct format
#
sub setAutomaticUpdatesTime
{
    my ($self, $time) = @_;

    if (not ($time =~ m/^\d\d:\d\d$/)   ) {
        throw EBox::Exceptions::InvalidData(
                                            data => 'Time for automatic updates',
                                            value => $time
                                           );
    }

    my ($hour, $minute) = split ':', $time, 2;
    if (($hour < 0) or ($hour > 23)) {
        throw EBox::Exceptions::InvalidData(
                                            data => 'Time for automatic updates',
                                            value => $time,
                                            advice => 'Bad hour!'
                                           );
    }
    if (($minute < 0) or ($minute > 59)) {
        throw EBox::Exceptions::InvalidData(
                                            data => 'Time for automatic updates',
                                            value => $time,
                                            advice => 'Bad minute!'
                                           );
    }

    $self->set_string('automatic_time', $time);
}

# Method: automaticUpdatesTime
#
#      Get the time when the automatic update process starts
#
#      If no time is set by the admin, then a random hour in
#      off-office hours is set (from 22:00 to 6:00)
#
# Returns:
#
#      String - in HH:MM format
#
sub automaticUpdatesTime
{
    my ($self) = @_;
    my $value = $self->get_string('automatic_time');
    if (not $value) {
        # Set a random value for the first time to avoid DoS
        # The off-office hours
        my $randHour = int(rand(8)) - 2;
        $randHour += 24 if ($randHour < 0);
        my $randMin  = int(rand(60));
        my $time     = sprintf('%02d:%02d', $randHour, $randMin);
        $self->setAutomaticUpdatesTime($time);
        return $time;
    }

    return $value;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
        my ($self, $root) = @_;
        my $folder = new EBox::Menu::Folder('name' => 'Software',
                                            'icon' => 'software',
                                            'text' => $self->printableName(),
                                            'tag' => 'system',
                                            'order' => 100);

        $folder->add(new EBox::Menu::Item('url' => 'Software/EBox',
                                          'text' => __('Zentyal Components')));
        $folder->add(new EBox::Menu::Item('url' => 'Software/Updates',
                                          'text' => __('System Updates')));
        $folder->add(new EBox::Menu::Item('url' => 'Software/Config',
                                          'text' => __('Settings')));
        $root->add($folder);
}

# Method: lock
#
#      Lock the zentyal-software module to work
#
# Parameters:
#
#      by - String the subsystem name which locks the module
#
#      - Named parameters
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub lock
{
    my ($self, %params) = @_;

    unless (exists $params{by}) {
        throw EBox::Exceptions::MissingArgument('by');
    }

    open( $self->{lockFile}, '>', LOCK_FILE);
    flock( $self->{lockFile}, LOCK_EX );

    $self->st_set_string(LOCKED_BY_KEY, $params{by});
    $self->st_set_int(LOCKER_PID_KEY, $$);
}

# Method: unlock
#
#      Unlock the zentyal-software module
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if the module has not
#      previously locked
#
sub unlock
{
    my ($self) = @_;

    unless ( exists( $self->{lockFile} )) {
        throw EBox::Exceptions::Internal('The ebox-module has not '
                                         . 'locked previously');
    }

    flock( $self->{lockFile}, LOCK_UN );
    close( $self->{lockFile} );
    undef $self->{lockFile};

    $self->st_unset(LOCKED_BY_KEY);
    $self->st_unset(LOCKER_PID_KEY);
}

# Method: setAutoUpgradePkgNo
#
#     Set the number of packages that have been upgraded in last
#     automatic upgrade
#
#     As a side effect, it stores the time when this method call is
#     done
#
# Parameters:
#
#     packageNum - Int the number of packages automatically upgraded
#                  using auto-updater script
#
sub setAutoUpgradePkgNo
{
    my ($self, $packageNum) = @_;

    $self->st_set_int('auto_upgrade/timestamp', time());
    $self->st_set_int('auto_upgrade/package_num', $packageNum);
}

# Method: autoUpgradeStats
#
#     Get the last automatic upgrade stats
#
# Returns:
#
#     Hash ref - containing the following key/value pairs:
#
#         timestamp - Int the timestamp of last auto upgrade
#         packageNum - In the number of upgraded packages
#
#     undef - if this has never happened
#
sub autoUpgradeStats
{
    my ($self) = @_;

    if ( $self->st_entry_exists('auto_upgrade/timestamp') ) {
        my %stats = (
            timestamp  => $self->st_get_int('auto_upgrade/timestamp'),
            packageNum => $self->st_get_int('auto_upgrade/package_num'),
           );
        return \%stats;
    } else {
        return undef;
    }
}

sub QAUpdates
{
    return (not EBox::Global->communityEdition());
}

# Group: Private methods

sub _getInfoEBoxPkgs
{
    my ($self) = @_;

    my $cache = $self->_cache(1);
    my @list;

    my %seen; # XXX workaround launchpad bug 994509
    for my $pack (keys %$cache) {
        if ($pack =~ /^zentyal-.*/) {
            if ($seen{$pack}) {
                next;
            } else {
                $seen{$pack} = 1;
            }

            my $pkgCache = $cache->packages()->lookup($pack) or next;
            my %data;
            $data{'name'} = $pkgCache->{Name};
            $data{'description'} = $pkgCache->{ShortDesc};
            if ($pkgCache->{Name} =~ /^zentyal-common$|^zentyal-core|^zentyal-software$/) {
                $data{'removable'} = 0;
            } else {
                $data{'removable'} = 1;
            }
            my $candidateVersion = $self->_candidateVersion($cache->{$pack});
            if ($candidateVersion) {
                $data{'avail'} =  $candidateVersion->{version};
            }

            if ($cache->{$pack}{CurrentVer}) {
                $data{'version'} = $cache->{$pack}{CurrentVer}{VerStr};

                my @depends;
                for my $dep (@{$cache->{$pack}{CurrentVer}{DependsList}}) {
                    push (@depends, $dep->{TargetPkg}{Name});
                }
                $data{'depends'} = \@depends;
            }

            push(@list, \%data);
        }
    }
    return \@list;
}

sub _getUpgradablePkgs
{
    my ($self) = @_;

    my $cache = $self->_cache(1);
    my @list;
    my @held = `apt-mark showhold`;
    chomp (@held);
    my %seen = map { $_ => 1 } @held;
    for my $pack (keys %$cache) {
        my ($pname) = split(':', $pack);
        if ($seen{$pname}) {
            next;
        } else {
            $seen{$pname} = 1;
        }

        my $pkgCache = $cache->packages()->lookup($pack) or next;

        my $currentVerObj = $cache->{$pack}{CurrentVer};

        if ($currentVerObj) {
            if ($currentVerObj->{VerStr} eq $pkgCache->{VerStr}) {
                # Nothing new available
                next;
            }
        } else {
            next;
        }

        my %data;
        $data{'name'} = $pkgCache->{Name};
        $data{'description'} = $pkgCache->{ShortDesc};
        my $candidateVerInfo = $self->_candidateVersion($cache->{$pack});
        if ($candidateVerInfo) {
            $data{'security'}    = $candidateVerInfo->{security};
            $data{'ebox-qa'}     = $candidateVerInfo->{qa};
            $data{'version'}     = $candidateVerInfo->{version};
        }
        next if ($data{'version'} eq $currentVerObj->{VerStr});

        push(@list, \%data);
    }

    return \@list;
}

# Get the version and several properties given the package
sub _candidateVersion
{
    my ($self, $pkgObj) = @_;

    my $qa = 0;
    my $security = 0;

    my $policy = $self->_cache()->policy();
    my $verObj = $policy->candidate($pkgObj);
    defined $verObj or
        return undef;
    foreach my $verFile (@{$verObj->FileList()}) {
        my $file = $verFile->File();
        # next if the archive is missing or installed using dpkg
        next unless defined($file->{Archive});
        if ($file->{Archive} =~ /security/) {
            $security = 1;
        }
        if ($file->{Archive} eq 'zentyal-qa') {
            $qa = 1;
        }
        if ($security and $qa) {
            last;
        }
    }

    my $version  = $verObj->{VerStr};
    return { qa => $qa, security => $security, version => $version };
}

# Check if the module is locked or not
sub _isModLocked
{
    my ($self) = @_;

    my $lockedBy = $self->st_get_string(LOCKED_BY_KEY);

    if ( $lockedBy ) {
        unless ( $$ == $self->st_get_int(LOCKER_PID_KEY)) {
            throw EBox::Exceptions::External(__x('Software management is currently '
                                                 . ' locked by {locker}. Please, try'
                                                 . ' again later',
                                                 locker => $lockedBy));
        }
    }
}

# Method: updateStatus
#
#  Return the status of the package list
#
#  Parameter:
#   ebox - 1 if ebox components, 0 if system updates
#
#  Returns:
#  -1 if currently updating
#   0 if never successfully updated
#   otherwise tiemstamp of the last update
sub updateStatus
{
    my ($self, $ebox) = @_;

    my $lockedBy = $self->st_get_string(LOCKED_BY_KEY);
    if (defined $lockedBy) {
        if ($lockedBy eq 'ebox-software') {
            return -1;
        }
    }

    my $file = $self->_packageListFile($ebox);
    if (not -f $file) {
        return 0;
    }

    my $stat = File::stat::stat($file);
    return $stat->mtime;
}

sub _setConf
{
    my ($self) = @_;
    $self->_installCronFile();
}

sub _installCronFile
{
    my ($self) = @_;
    my $time = $self->automaticUpdatesTime();
    my ($hour, $minute) = split ':', $time;

    # We cannot call writeConfFile since we are not
    # EBox::Module::Service, we are not updating the digests
    # but ebox-software script is not from other package
    EBox::Module::Base::writeConfFileNoCheck(
        CRON_FILE,
        'software/software.cron',
        [
            hour => $hour,
            minute => $minute,
        ]
       );
}

# Method: firstTimeMenu
#
#   Returns first time menu instead of Zentyal default menu.
#   This method is intended to be used by first time wizard pages
#
# Params:
#
#   current - Current page index which means
#       1 - Package Selection
#       2 - Installation
#       3 - Initial Configuration
#       4 - Save Changes
#
sub firstTimeMenu
{
    my ($self, $current) = @_;

    my $output = '';

    $output .= "<div id='menu'><ul id='nav' class='install-steps'>\n";

    $output .= $self->_dumpMenuItem(__('Package Selection'), 1, $current);
    $output .= $self->_dumpMenuItem(__('Installation'), 2, $current);
    $output .= $self->_dumpMenuItem(__('Initial Configuration'), 3, $current);
    $output .= $self->_dumpMenuItem(__('Save Changes'), 4, $current);

    $output .= "</ul></div>\n";
    $output .= <<END_SCRIPT;
<script>
\$(function() {
   // ping the server each 60s
   var ping_server = function() {
        \$.getJSON('/SysInfo/HasUnsavedChanges',  function(response){});
         setTimeout(ping_server, 60000);
   };
  setTimeout(ping_server, 60000);
});
</script>
END_SCRIPT

    return $output;
}

# Method: _dumpMenuItem
#
#   Dumps a menu item for the firstTimeMenu
#
# Params:
#   index - This item index inside the list
#   current - Current item index
#
sub _dumpMenuItem
{
    my ($self, $text, $index, $current) = @_;

    my $class = '';
    if ($index < $current) {
        $class = 'step-done';
    } elsif ($index == $current ) {
        $class = 'step-actual';
    }

    return "<li class='$class'>$text</li>\n";
}

sub _cache
{
    my ($self, $regen) = @_;

    if (not defined $self->{cache} or $regen) {
        $self->{cache} = new AptPkg::Cache();
    }

    return $self->{cache};
}

sub _brokenPackages
{
    my ($self) = @_;

    # Force call to modExists for all modules
    # in order to refresh values after apache restart
    EBox::Global->modNames();

    return EBox::Global->brokenPackages();
}

1;
