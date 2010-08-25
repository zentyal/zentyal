# Copyright (C) 2005 Warp Networks S.L.
# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::Software;

use strict;
use warnings;

use base qw(EBox::GConfModule);

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Module::Base;
use EBox::ProgressIndicator;
use EBox::Sudo qw( :all );

use Digest::MD5;
use Error qw(:try);
use Storable qw(fd_retrieve store retrieve);
use Fcntl qw(:flock);
use AptPkg::Cache;

# Constants
use constant {
    LOCK_FILE     => EBox::Config::tmp() . 'ebox-software-lock',
    LOCKED_BY_KEY => 'lockedBy',
    LOCKER_PID_KEY => 'lockerPid',
    CRON_FILE      => '/etc/cron.d/ebox-software',
};

# Group: Public methods

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'software',
                        printableName => __n('Software Management'),
						domain => 'ebox-software',
						@_);
	bless($self, $class);
	return $self;
}

# Method: listEBoxPkgs
#
#       Get the list of the Zentyal packages with information about them.
#
# Parameters:
#
#       clear - Boolean set to true to retrieve the list of Zentyal
#               packages from esofttool utility or false to get from
#               cache
#
# Returns:
#
#	array ref of hashes holding the following keys:
#
#	name - name of the package
#	description - short description of the package
#	version - version installed (if any)
#	avail - latest version available
#	removable - true if the package can be removed
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
	my ($self,$clear) = @_;

	my $eboxlist = [];

    $eboxlist =  _getInfoEBoxPkgs();

	return $eboxlist;
}

# Method: installPkgs
#
#	Installs a list of packages via apt
#
# Parameters:
#
#	array -  holding the package names
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

    $self->_isModLocked();

    if (not @pkgs) {
        EBox::info("No packages to install");
        return;
    }

	my $executable = EBox::Config::share() . "/ebox-software/ebox-update-packages @pkgs";
	my $progress = EBox::ProgressIndicator->create(
						       totalTicks => scalar @pkgs,
						       executable => $executable,
						      );
	$progress->runExecutable();
	return $progress;
}

# Method: removePkgs
#
#	Removes a list of packages via apt
#
# Parameters:
#
#	array -  holding the package names
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

	$self->_isModLocked();

	if (not @pkgs) {
	  EBox::info("No packages to remove");
	  return;
	}

	my $executable = EBox::Config::share() .
	  "/ebox-software/ebox-remove-packages @pkgs";
	my $progress = EBox::ProgressIndicator->create(
						       totalTicks => scalar @pkgs,
						       executable => $executable,
						      );
	$progress->runExecutable();
	return $progress;

}

# Method: updatePkgList
#
#	Update the package list
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

	my $cmd ='/usr/bin/apt-get update -q';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};
}

# Method: fetchAllPkgs
#
#	Download all the new ebox packages and the system updates
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub fetchAllPkgs
{
    my ($self) = @_;

    $self->_isModLocked();

	my @pkgs;

	@pkgs = @{_getInfoEBoxPkgs()};

	my $cmd ='/usr/bin/apt-get install -qq --download-only --force-yes --yes --no-install-recommends ';
	foreach my $pkg (@pkgs) {
		$cmd .= ($pkg->{name} . " ");
	}
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};

	$cmd ='/usr/bin/apt-get dist-upgrade -qq --download-only --force-yes --yes --no-install-recommends ';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};

	$cmd ='/usr/bin/apt-get autoclean -qq --force-yes --yes';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};
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
#	Returns a list of those packages which are ready to be upgraded
#
# Parameters:
#
# 	clear - if set to 1, forces the cache to be cleared
#
#       excludeEBoxPackages - not return ebox packages (but they are saved in the cache anyway)
#
# Returns:
#
#	array ref - holding hashes ref containing keys:
#                   'name' - package's name
# 	            'description' package's short description
#                   'version' - package's latest version
#                   'security' - flag indicating if the update is a security one
#                   'changelog' - package's changelog from current version till last one
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listUpgradablePkgs
{
	my ($self,$clear, $excludeEBoxPackages) = @_;

	my $upgrade = [];

	my $file = $self->_packageListFile(0);

	if (defined($clear) and $clear == 1) {
		if ( -f "$file" ) {
			unlink($file);
		}
	} else {
		if (-f "$file" ) {
			$upgrade = retrieve($file);
                        if ($excludeEBoxPackages) {
                            return $self->_excludeEBoxPackages($upgrade);
                        }
			return $upgrade;
		}
	}

    $self->_isModLocked();

    $upgrade = _getUpgradablePkgs();

    store($upgrade, $file);

    if ($excludeEBoxPackages) {
        return $self->_excludeEBoxPackages($upgrade);
    }

    return $upgrade;
}


sub _excludeEBoxPackages
{
    my ($self, $list) = @_;
    my @withoutEBox = grep {
        my $name = $_->{'name'};
        ($name ne 'libebox') and
         ($name ne 'ebox')    and
          not ($name =~ /^ebox-/)
      } @{ $list };
    return \@withoutEBox;
}

# Method: listPackageInstallDepends
#
#	Returns a list of those ebox packages which will be installed when
#	trying to install a given set of packages
#
# Parameters:
#
# 	packages - an array with the names of the packages being installed
#
# Returns:
#
#	array ref - holding the names of the ebox packages which will be
#	            installed
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageInstallDepends
{
    my ($self, $packages) = @_;

    $self->_isModLocked();

    return $self->_packageDepends('install', $packages);
}


# Method: listPackageDescription
#
#	Returns a list of short descriptions of each package in the list.
#
# Parameters:
#
# 	packages - an array with the names of the packages
#
# Returns:
#
#	array ref - holding the short descriptions of the packages
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageDescription
{
	my ($self, $packages) = @_;
	my $cache = AptPkg::Cache->new;

	my @list;
	for my $pack ( @$packages) {
		my $pkgCache = $cache->packages()->lookup($pack) or next;
		push(@list, $pkgCache->{ShortDesc});
	}
	return \@list;
}

# Method: listPackageRemoveDepends
#
#	Returns a list of those ebox packages which will be removed when
#	trying to remove a given set of packages
#
# Parameters:
#
# 	packages - an array with the names of the packages being removed
#
# Returns:
#
#	array ref - holding the names of the ebox packages which will be removed
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub listPackageRemoveDepends
{
    my ($self, $packages) = @_;

    $self->_isModLocked();

    return $self->_packageDepends('remove', $packages);
}


sub _packageDepends
{
    my ($self, $action, $packages) = @_;
    if (($action ne 'install') and ($action ne 'remove')) {
	    throw EBox::Exceptions::Internal("Bad action: $action");
    }

    my $aptCmd = "apt-get -qq --no-install-recommends --simulate $action " .

	join ' ',  @{ $packages };

    my $header;
    if ($action eq 'install') {
	    $header = 'Inst';
    }
    elsif ($action eq 'remove') {
	    $header = 'Remv'
    }


    my $output = root($aptCmd);


    my @packages = grep {
	$_ =~ m/
              ^$header\s      # requested operation
             (?:lib)?ebox     # is a ebox package
             /x
    } @{ $output };


    @packages = map {
	    chomp $_;
	    my ($h, $p) = split '\s', $_;
	    $p;
    } @packages;


   return \@packages;
}

# Method: isInstalled
#
#	Checks if the package is installed
#
# Parameters:
#
#	name - name of the package
#
# Returns:
#
#	1 is package is intalled otherwise returns 0
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the module is locked
#       by other process
#
sub isInstalled
{
    my ($self, $name) = @_;
    my $cache = AptPkg::Cache->new;
    if ($cache->{$name}{CurrentState} eq 'Installed'){
        return 1;
    }
    return 0;
}


# Method: getAutomaticUpdates
#
#	Returns if the automatic update mode is enabled
#
#       Check if there are automatic updates from QA, if so, then
#       return always true.
#
# Returns:
#
#	boolean - true if it's enabled, otherwise false
sub getAutomaticUpdates
{
    my ($self) = @_;

    if ($self->QAUpdates()) {
        my $alwaysAutomatic = EBox::Config::configkey('qa_updates_always_automatic');
        defined $alwaysAutomatic or $alwaysAutomatic = 'true';

        if (lc($alwaysAutomatic) eq 'true') {
            return 1;
        }

    }

    my $auto = $self->get_bool('automatic');
    return $auto;
}

# Method: setAutomaticUpdates
#
#	Set the automatic update mode. If it's enabled the system will
#	fetch all the updates silently and automatically.
#
#       If the software is QA updated, then you cannot change this parameter.
#
# Parameters:
#
#	auto  - true to enable it, false to disable it
sub setAutomaticUpdates # (auto)
{
    my ($self, $auto) = @_;

    if ( $self->QAUpdates() ) {
        my $key = 'qa_updates_always_automatic';
        my $alwaysAutomatic = EBox::Config::configkey($key);
        defined $alwaysAutomatic or $alwaysAutomatic = 'true';

        if (lc($alwaysAutomatic) eq 'true') {
            throw EBox::Exceptions::External(
                __x('You cannot modify the automatic update using QA updates from Web UI. '
                      . 'To disable automatic updates, edit {conf} and disable {key} key.',
                    conf => EBox::Config::etc() . '78remoteservices.conf',
                    key  => $key));
        }
    }
    $self->set_bool('automatic', $auto);
}

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

sub automaticUpdatesTime
{
    my ($self) = @_;
    my $value = $self->get_string('automatic_time');
    if (not $value) {
        return '04:15';
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
                                           'text' => $self->printableName(),
                                           'separator' => 'Core',
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
#      Lock the ebox-software module to work
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
#      Unlock the ebox-software module
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


# Group: Private methods

sub _getInfoEBoxPkgs
{
	my $cache = AptPkg::Cache->new;
	my @list;
	for my $pack (keys %$cache)     {
		if ($pack =~ /^libebox$|^ebox$|^ebox-.*/) {
			my $pkgCache = $cache->packages()->lookup($pack) or next;
			my %data;
			$data{'name'} = $pkgCache->{Name};
			$data{'description'} = $pkgCache->{ShortDesc};
			if ($pkgCache->{Name} =~ /^libebox$|^ebox$/) {
				$data{'removable'} = 0;
			} else {
				$data{'removable'} = 1;
			}
			$data{'avail'} = $pkgCache->{VerStr};
			if ($cache->{$pack}{CurrentVer}) {
				$data{'version'} = $cache->{$pack}{CurrentVer}{VerStr};
			}
			push(@list, \%data);
		}
	}
	return \@list;
}

sub _getUpgradablePkgs
{
	my $distro = _getDistroId();
	my $cache = AptPkg::Cache->new();
	my @list;
	for my $pack (keys %$cache)     {
		unless ($pack =~ /^libebox$|^ebox$|^ebox-.*|.*kernel-image.*|.*linux-image.*/) {
			my $pkgCache = $cache->packages()->lookup($pack) or next;
			my %data;

			if ($cache->{$pack}{CurrentVer}) {
				$data{'version'} = $pkgCache->{VerStr};
				if ($cache->{$pack}{CurrentVer}{VerStr} eq $data{version}) {
					next;
				}
			} else {
				next;
			}

			$data{'name'} = $pkgCache->{Name};
			$data{'description'} = $pkgCache->{ShortDesc};

			my @files = $cache->files($pack);
			$data{'security'} = 0;
			$data{'ebox-qa'} = 0;
			my $security = 0;
			my $ebox_qa = 0;
			foreach my $file (@files) {
				if ($file->{Archive} =~ /.*security.*/) {
					$security = 1;
				}
				if ($distro eq 'Ubuntu') {
					if ($file-> {Archive}  eq 'ebox-qa'){
						$ebox_qa = 1;
					}
				} elsif ($distro eq 'Debian') {
					if ($file->{Site} eq 'qa.ebox-platform.com'){
						$ebox_qa = 1;
					}
				}
				if ($security and $ebox_qa) {
					last;
				}
			}
			$data{'security'} = $security;
			$data{'ebox-qa'} = $ebox_qa;

			push(@list, \%data);
		}

	}

	return \@list;
}

#return the distro name
sub _getDistroId
{
	my $distroFile = '/etc/lsb-release';
	open(FILE, $distroFile);
	my $distro = <FILE>;
	close(FILE);
	chop($distro);
	if ($distro =~ /.*=(.*)/) {
		return $1;
	} else {
		return '';
	}
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
#   ebox - 1 if ebox components, 0 if system upates
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

# Method: setQAUpdates
#
#     Set the software management system to be updated using QA
#     updates.
#
#     This method must be called from ebox-remoteservices when a
#     subscription is done or released.
#
# Parameters:
#
#     value - boolean indicating if the QA updates are to be set or
#             released
#
sub setQAUpdates
{
    my ($self, $value) = @_;
    $self->set_bool('qa_updates', $value);
}

# Method: QAUpdates
#
#     Return if the management system is being updated using QA
#     updates or not
#
# Returns:
#
#     Boolean -
#
sub QAUpdates
{
    my ($self) = @_;
    return $self->get_bool('qa_updates');
}


sub _setConf
{
    my ($self) = @_;
    $self->_installCronFile();
    $self->_setAptPreferences();
}

sub _setAptPreferences
{
    my ($self) = @_;

    my $enabled;
    if ($self->QAUpdates()) {
        my $exclusiveSource =  EBox::Config::configkey('qa_updates_exclusive_source');
        $enabled = lc($exclusiveSource) eq 'true';
    } else {
        $enabled = 0;
    }

    my $preferences =  '/etc/apt/preferences';
    my $preferencesBak  = $preferences . '.ebox.bak';
    my $preferencesFromCCBak = $preferences . '.ebox.fromcc';

    if ($enabled ) {
        my $existsCC = EBox::Sudo::fileTest('-e', $preferencesFromCCBak);
        if (not $existsCC) {
            EBox::error('Could not find apt preferences file from Control Center, letting APT preferences untouched');
            return;
        }

        # Hardy version
        # EBox::Sudo::root("cp '$preferencesFromCCBak' '$preferences'");

        # Lucid version
        my $preferencesDirFile = '/etc/apt/preferences.d/01ebox';
        EBox::Sudo::root("cp '$preferencesFromCCBak' '$preferencesDirFile'");
    } else {
        my $existsOld = EBox::Sudo::fileTest('-e', $preferencesBak);
        if ($existsOld) {
            EBox::Sudo::root("cp '$preferencesBak' '$preferences'");
            # remove old backup to avoid to overwrite user's modifications
            EBox::Sudo::root("rm -f '$preferencesBak' ");
        }
    }


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
#   Prints first time menu instead of Zentyal default menu.
#   This method is intended to be used by first time wizard pages
#
# Params:
#   current - Current page index which means
#       0 - Package Selection
#       1 - Confirmation
#       2 - Installation
#       3 - Initial Configuration
#
sub firstTimeMenu
{
    my ($self, $current) = @_;

    print "<div id='menu'><ul id='nav'>\n";

    print "<li><div class='separator'>" . __('Welcome') . "</div></li>\n";

    $self->_printMenuItem(__('Package Selection'), 0, $current);
    $self->_printMenuItem(__('Confirmation'), 1, $current);
    $self->_printMenuItem(__('Installation'), 2, $current);
    $self->_printMenuItem(__('Initial Configuration'), 3, $current);
    $self->_printMenuItem(__('Save Changes'), 4, $current);

    print "</ul></div>\n";
}


# Method: _printMenuItem
#
#   Print a menu item for the firstTimeMenu
#
# Params:
#   index - This item index inside the list
#   current - Current item index
#
sub _printMenuItem
{
    my ($self, $text, $index, $current) = @_;

    my $style = 'padding: 8px 10px 8px 20px;';

    if ( $index < $current ) {
        $style .= 'background: url("/data/images/apply.gif") left no-repeat;';
    } elsif ( $index == $current ) {
        $style .= 'font-weight: bold';
    }
    else {
    }

    print "<li><div style='$style'>$text</div></li>\n";
}


1;
