# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Util::Software;
# Class: EBox::Util::Software
#
#     Utility functions to query the APT cache database
#

use AptPkg::Cache;
use File::stat;
use Readonly;

Readonly::Scalar my $APT_CHECK   => '/usr/lib/update-notifier/apt-check';
Readonly::Scalar my $PACKAGES_DB => '/var/cache/apt/pkgcache.bin';

my $_cache;

# Function: latestUpdate
#
#     Latest apt-get update which modifies the available packages
#     database
#
# Returns:
#
#     Int - the latest update timestamp in seconds since epoch
#
sub latestUpdate
{
    my $status = stat($PACKAGES_DB);
    return $status->mtime();
}

# Function: errorOnPkgs
#
#   return whether there is a error in the software packages
sub errorOnPkgs
{
    my @output = `$APT_CHECK 2>&1`;
    my $line = $output[0];
    chomp($line);
    return $line =~ m/^E:/;
}

# Function: upgradablePkgsNum
#
#     Return the number of packages that are upgradable with the
#     current APT policy
#
# Returns:
#
#     Array ref - containing two elements:
#
#        Int - the number of total updates
#        Int - the number of security updates
#
sub upgradablePkgsNum
{
    # As output is in stderr, cannot manage with EBox::Sudo
    my @output = `$APT_CHECK 2>&1`;
    my $line = $output[0];
    chomp($line);

    my @result = split(/;/, $line);
    return \@result
}

# Function: upgradablePkgs
#
#     Return an array of upgradable pkgs names
#
# Returns:
#
#     Array ref - containing the names of the upgradable packages
#
sub upgradablePkgs
{
    my @output = `$APT_CHECK -p 2>&1`;
    my @packages = map { chomp(); $_ } @output;
    return \@packages;
}

# Function: isSecUpdate
#
#     Return if a package has a candidate version from a security
#     repository
#
# Parameters:
#
#     pkg - String the package to check
#
# Returns:
#
#     1 - if the update is a security update
#     0 - otherwise
#
# Exceptions:
#
#     <EBox::Exceptions::Internal> - thrown if the given package name
#     is not in the cache
#
sub isSecUpdate
{
    my ($pkg) = @_;

    unless ( defined($_cache) ) {
        $_cache = new AptPkg::Cache();
    }

    my $pkgObj = $_cache->{$pkg};
    unless ( defined($pkgObj) ) {
        throw EBox::Exceptions::Internal("$pkg is not in APT cache")
    }

    my $verObj = $_cache->policy()->candidate($pkgObj);
    my $security = 0;
    foreach my $verFile (@{$verObj->FileList()}) {
        my $file = $verFile->File();
        next unless defined($file->{Archive});
        if ( $file->{Archive} =~ /security/ ) {
            $security = 1;
        }
        last if ($security);
    }
    return $security;
}

1;
