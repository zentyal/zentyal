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

use EBox::Config;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo qw( :all );
use Digest::MD5;
use Error qw(:try);
use Storable qw(fd_retrieve store retrieve);

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'software', 
						domain => 'ebox-software',
						@_);
	bless($self, $class);
	return $self;
}

sub _getSoftToolResult {
	my ($command) = @_;
	open(PKGS, EBox::Config::libexec . "eboxsofttool --$command |");
	return fd_retrieve(\*PKGS);
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
	my ($self,$clear) = @_;

	my $eboxlist = [];

	my $file = EBox::Config::tmp . "eboxpackagelist";

	if(defined($clear) and $clear == 1){
		if ( -f "$file" ) {
			unlink($file);
		}
	}else{
		if (-f "$file" ) {
			$eboxlist = retrieve($file);
			return $eboxlist;
		}
	}
	
	$eboxlist =  _getSoftToolResult("ebox-info");

	store($eboxlist, $file);
	return $eboxlist;
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
	my $cmd ='/usr/bin/apt-get remove --purge --no-download -q --yes ';
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
	my @pkgs;
	@pkgs = @{_getSoftToolResult("ebox")};

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

	my $upgrade = [];

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
	
	$upgrade = _getSoftToolResult("upgradable");

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
