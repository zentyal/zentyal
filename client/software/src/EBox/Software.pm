# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

use base 'EBox::GConfModule';

use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo qw( :all );
use AptPkg::Config;
use Digest::MD5;
use AptPkg::Cache;
use AptPkg::System qw($_system);
use AptPkg::Version;
use Error qw(:try);
use Storable;

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'software', 
						domain => 'ebox-software',
						@_);
	$self->{fetched} = [];
	$self->{notfetched} = [];
	bless($self, $class);
	return $self;
}

# Method: listEBoxPkgs
# 	
# 	Returns an array of hashes with the following fields:
#	name - name of the package
#	description - short description of the package
#	version - version installed (if any)
#	avail - latest version available
#	removable - true if the package can be removed
#
# Returns:
#
# 	array ref of hashes holding the above keys
sub listEBoxPkgs
{
	my $self = shift;
	my $cache = AptPkg::Cache->new;
	my $versioning = $AptPkg::System::_system->versioning();
	my @pkgs = grep(/^ebox/, $cache->keys());
	my @array = ();

	# WARNING - do not move this line before the $cache->keys() call
	my $records = $cache->packages();

        foreach my $p (@pkgs) {
                my $pkg = $cache->{$p};
                my $h;
                $h->{name} = $pkg->{Name};
		if(($h->{name} eq 'ebox') or ($h->{name} eq 'ebox-software')){
			$h->{removable} = 0;
		}else{
			$h->{removable} = 1;
		}
                my $available = $pkg->{VersionList} or next;
                my $curver = undef;
                if ($pkg->{CurrentVer}) {
                        $curver = $pkg->{CurrentVer}{VerStr};
                        $h->{version} = $pkg->{CurrentVer}{VerStr};
                }
                foreach my $v (@{$available}) {
                        if (!$curver) {
                                $curver = $v->{VerStr};
                        } elsif ($versioning->compare
                                        ($curver, $v->{VerStr}) < 0) {
                                $curver = $v->{VerStr};
                        }
                }
		if ($self->pkgIsFetched($p)) {
			$h->{avail} = $curver;
		} else {
			unless (defined($h->{version})) {
				next;
			}
			$h->{avail} = $h->{version};
		}
		my $info = $records->lookup($pkg->{Name});
                $h->{avail} = $curver;
                $h->{description} = $info->{ShortDesc};
		push(@array, $h);
        }

	return \@array;
}

# Method: installPkgs 
#	
#	Installs a list of packages via apt
# 
# Parameters:
#
# 	array -  holding the package names
sub installPkgs # (@pkgs)
{
	my ($self, @pkgs) = @_;
	my $cmd ='/usr/bin/apt-get install --no-download -q --yes --no-remove ';
	$cmd .= join(" ", @pkgs);
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
		throw EBox::Exceptions::External(__('An error ocurred while '.
			'installing components. If the error persists or eBox '.
			'stops working properly, seek technical support.'));
	};
}

# Method: removePkgs 
#	
#	Removes a list of packages via apt
# 
# Parameters:
#
# 	array -  holding the package names
sub removePkgs # (@pkgs)
{
	my ($self, @pkgs) = @_;
	my $cmd ='/usr/bin/apt-get remove --no-download -q --yes ';
	$cmd .= join(" ", @pkgs);
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
		throw EBox::Exceptions::External(__('An error ocurred while '.
			'removing components. If the error persists or eBox '.
			'stops working properly, seek technical support.'));
	};
}

# Method: updatePkgList
#	
#	Update the package list
# 
sub updatePkgList
{
	my $self = shift;

	my $cmd ='/usr/bin/apt-get update -qq';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};
}

# Method: fetchAllPkgs 
#	
#	Download all the new ebox packages and the system updates
# 
sub fetchAllPkgs
{
	my $self = shift;
	my $cache = AptPkg::Cache->new;
	my $versioning = $AptPkg::System::_system->versioning();
	my @pkgs = grep(/^ebox/, $cache->keys());

	my $cmd ='/usr/bin/apt-get install -qq --download-only --yes ';
	$cmd .= join(" ", @pkgs);
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};

	$cmd ='/usr/bin/apt-get dist-upgrade -qq --download-only --yes';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};

	$cmd ='/usr/bin/apt-get autoclean -qq --yes';
	try {
		root($cmd);
	} catch EBox::Exceptions::Internal with {
	};
}

sub _pkgIsFetched # (pkg, cache, versioning, records)
{
	my ($self, $p, $cache, $versioning, $records) = @_;

	my $pquoted = quotemeta($p);

	if (grep(/^$pquoted$/, @{$self->{fetched}})) {
		return 1;
	}
	if (grep(/^$pquoted$/, @{$self->{notfetched}})) {
		return undef;
	}

	if (grep(/^$pquoted$/, @{$self->{visited}})) {
		return 1;
	} else {
		push(@{$self->{visited}}, $p);
	}

	my $pkg = $cache->{$p};

	my $provides = $pkg->{ProvidesList};
	if (defined($provides) and (scalar(@{$provides}) > 0)) {
		foreach my $provide (@{$provides}) {
			my $fetched = $self->_pkgIsFetched(
					$provide->{OwnerPkg}->{Name}, 
					$cache, 
					$versioning, 
					$records);
			if ($fetched) {
				push(@{$self->{fetched}}, $p);
				return 1;
			}
		}
	}

	my $available = $pkg->{VersionList};
	unless (defined($available)) {
		push(@{$self->{notfetched}}, $p);
		return undef;
	}

	my $curver = undef;
	my $arch = undef;
	my $curverobject = undef;
	if ($pkg->{CurrentVer}) {
		$curver = $pkg->{CurrentVer}{VerStr};
		$curverobject = $pkg->{CurrentVer};
	}
	foreach my $v (@{$available}) {
		if (!$curver) {
			$curver = $v->{VerStr};
			$arch = $v->{Arch};
			$curverobject = $v;
		} elsif ($versioning->compare
				($curver, $v->{VerStr}) < 0) {
			$curver = $v->{VerStr};
			$arch = $v->{Arch};
			$curverobject = $v;
		}
	}
	if ($pkg->{CurrentVer}) {
		if ($curver eq $pkg->{CurrentVer}{VerStr}) {
			push(@{$self->{fetched}}, $p);
			return 1;
		}
	}
	# package not installed or upgrade available
	my $info = $records->lookup($pkg->{Name});

	#my $file = $info->{FileName};
	#$file =~ s/^.*\///;
	my $file = "$p" . "_$curver"."_$arch.deb";
	$file =~ s/:/%3a/g;


	unless ( -f "/var/cache/apt/archives/$file" ) {
		push(@{$self->{notfetched}}, $p);
		return undef;
	}
	unless (open(MD5, "/var/cache/apt/archives/$file")) {
		push(@{$self->{notfetched}}, $p);
		return undef;
	}
	my $md5 = Digest::MD5->new;
	$md5->addfile(*MD5);
	my $digest = $md5->hexdigest;
	close(MD5);

	my $expected = $info->{MD5Hash};
	unless ($expected eq $digest) {
		push(@{$self->{notfetched}}, $p);
		return undef;
	}

	# package is fetched, check dependencies
	my @depends = ();
	if($curverobject->{DependsList}) {
		@depends = @{$curverobject->{DependsList}};
	}
	my $skip = 0;
	foreach my $dep (@depends) {
		my $or = $dep->{CompType} & AptPkg::Dep::Or;
		if ($skip) {
			$skip = $or;
			next;
		}
		$skip = 0;

		if (($dep->{DepType} ne "Depends") and 
			($dep->{DepType} ne "PreDepends")) {
			next;
		}

		my $fetched = $self->_pkgIsFetched($dep->{TargetPkg}{Name}, 
							$cache, 
							$versioning, 
							$records);
		if ($fetched) {
			if ($or) {
				$skip = 1;
			}
			next;
		} else {
			if ($or) {
				next;
			} else {
				push(@{$self->{notfetched}}, $p);
				return undef;
			}
		}
	}
	push(@{$self->{fetched}}, $p);
	return 1;
}

# Method: pkgIsFetched
#	
#	Checks if a package has been already feteched.
#
# Parameters:
#
# 	pkgname - package name
#
sub pkgIsFetched # (pkgname)
{
	my ($self, $pkg) = @_;

	my $cache = AptPkg::Cache->new;
	my $versioning = $AptPkg::System::_system->versioning();
	my $records = $cache->packages();
	$self->{visited} = [];
	return $self->_pkgIsFetched($pkg, $cache, $versioning, $records);
}

# Method: listUpgradablePkgs
#	
#	Returns a list of those packages which are ready to be upgraded
#
# Parameters:
#
# 	clear - if set to 1, forces the cache to be cleared
#
# Returns:
#
#	array ref - holding hashes ref containing keys: 'name' and 
#	'description' for each package
sub listUpgradablePkgs 
{
	my ($self,$clear) = @_;

	my $upgrade = ();

	my $file = EBox::Config::tmp . "packagelist";

	if(defined($clear) and $clear == 1){
		if ( -f "$file" ) {
			unlink($file);
		}
	}else{
		if (-f "$file" ) {
			$upgrade = retrieve($file);
			return $upgrade;
		}
	}
	
	my $cache = AptPkg::Cache->new;
	my $versioning = $AptPkg::System::_system->versioning();

	# ebox packages are handled separately
	# kernel-images are not upgraded
	my @packages = grep(!/^(kernel-image)|(ebox)/, $cache->keys());

	# WARNING - do not move this line before the $cache->keys() call
	my $records = $cache->packages();

	foreach my $p (@packages) {
                my $pkg = $cache->{$p};
                ($pkg->{CurrentState} == AptPkg::State::Installed) or next;
                my $available = $pkg->{VersionList} or next;
                my $curver = $pkg->{CurrentVer}{VerStr};
		my $arch;
                foreach my $v (@{$available}) {
                        if ($versioning->compare($curver, $v->{VerStr}) < 0) {
                                $curver = $v->{VerStr};
                                $arch = $v->{Arch};
                        }
                }
                if ($curver eq $pkg->{CurrentVer}{VerStr}) {
                        next;
                }

                my $info = $records->lookup($pkg->{Name});

		#my $file = $info->{FileName};
		#$file =~ s/^.*\///;
		my $pkgfile = "$p" . "_$curver"."_$arch.deb";
		$pkgfile =~ s/:/%3a/g;

		( -f "/var/cache/apt/archives/$pkgfile" ) or next;
		open(MD5, "/var/cache/apt/archives/$pkgfile") or next;
		my $md5 = Digest::MD5->new;
		$md5->addfile(*MD5);
		my $digest = $md5->hexdigest;
		close(MD5);

		my $expected = $info->{MD5Hash};
		($expected eq $digest) or next;

                my $h;
                $h->{name} = $pkg->{Name};
                $h->{description} = $info->{ShortDesc};

                push(@{$upgrade}, $h);
	}
	store($upgrade, $file);
	return $upgrade;
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
sub listPackageInstallDepends
{
	my ($self,$packages) = @_;
	my $cmd = "apt-get -qq -s install " . join(" ", @{$packages}) . " | grep ^Inst | cut -d' ' -f 2 | grep ^ebox";
	my $pkglist = root($cmd);
	my @array = @{$pkglist};
	@array = map { chomp($_); $_ } @array;
	return \@array;
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
sub listPackageRemoveDepends
{
	my ($self,$packages) = @_;
	my $cmd = "apt-get -qq -s remove " . join(" ", @{$packages}) . " | grep ^Remv | cut -d' ' -f 2 | grep ^ebox";
	my $pkglist = root($cmd);
	my @array = @{$pkglist};
	@array = map { chomp($_); $_ } @array;
	return \@array;
}

# Method: getAutomaticUpdates 
#	
#	Returns if the automatic update mode is enabled
#
# Returns:
#
#	boolean - true if it's enabled, otherwise false
sub getAutomaticUpdates
{
	my $self = shift;
	return $self->get_bool('automatic');
}

# Method: setAutomaticUpdates 
#	
#	Sets the automatic update mode. If it's enabled the system will
#	fetch all the updates silently and automatically.
#
# Parameters:
#
#	auto  - true to enable it, false to disable it
sub setAutomaticUpdates # (auto)
{
	my ($self, $auto) = @_;
	$self->set_bool('automatic', $auto);
}

#   Function: rootCommands
#
#       Overrides EBox::Module method.
#   
# 
sub rootCommands
{
	my $self = shift;
	my @array = ();

	push(@array, '/usr/bin/apt-get');
	push(@array, '/usr/bin/dpkg');
   
	return @array;
}

#   Function: menu 
#
#       Overrides EBox::Module method.
#   
#
sub menu
{
        my ($self, $root) = @_;
        my $folder = new EBox::Menu::Folder('name' => 'Software',
                                           'text' => __('Software management'));

        $folder->add(new EBox::Menu::Item('url' => 'Software/EBox',
                                          'text' => __('eBox components')));
        $folder->add(new EBox::Menu::Item('url' => 'Software/Updates',
                                          'text' => __('System updates')));
        $folder->add(new EBox::Menu::Item('url' => 'Software/Config',
                                          'text' => __('Configuration')));
        $root->add($folder);
}

1;
