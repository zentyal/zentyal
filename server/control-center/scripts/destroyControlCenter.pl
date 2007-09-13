#!/usr/bin/perl -w

# Copyright (C) 2007 Warp Networks S.L.
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

# This script is intended to destroy everything related to the control center

use warnings;
use strict;

###############
# Core modules
###############
use Getopt::Long;
use Error qw(:try);
use File::Path qw(rmtree);

# eBox modules
use EBox;
use EBox::Sudo;

# Common procedures for CC scripts
use EBox::ControlCenter::Common qw(:all);
use EBox::ControlCenter::FileEBoxDB;
use EBox::ControlCenter::ApacheSOAP;

# Procedure: usage
#
#      Print the usage prompt
#
sub _usage
  {

    print 'destroyControlCenter.pl [--usage|help]' . $/;
    print 'Where usage: print this help' . $/;
    exit 1;

  }

# Procedure: _destroyCA
#
#      Remove the directory where all Certification Authority things
#      are stored, including Certificates, keys and requests.
#
#
sub _destroyCA
  {

    my $caDir = CATopDir();
    # Remove recursively the CA directory and its contents

    if ( -d $caDir ) {
        rmtree($caDir);
    }

  }

# Procedure: _destroyOpenVPN
#
#      Destroy symlinks on /etc and such
#
sub _destroyOpenVPN
  {

    my $cnfFile = OpenVPNServerFileEtc();

    # Is a symbolic link?
    if ( -l $cnfFile ) {
      EBox::Sudo::root( qq{rm -f "$cnfFile"} );
    }

    # Restart the OpenVPN servers
    EBox::ControlCenter::Common::execOpenVPN('restart');

  }

#################
# Main programme
#################

# Become eBox user
EBox::init();

my $usage = q{};

my $correct = GetOptions(
			 "usage|help"  => \$usage,
			);

# Now in ARGV there's the last compulsory arguments
if ( $usage or (not $correct) or ( scalar(@ARGV) != 0) ) {
  _usage();
}


# Remove the whole stuff
_destroyCA();

# Clean the system from the control center database where the
#  mapping against the eBoxes are stored
try {
    my $fileDB = new EBox::ControlCenter::FileEBoxDB();
    $fileDB->destroyDB();
} catch EBox::Exceptions::Internal with {
    # Catch the exception if the file does not exist and pass
};

_destroyOpenVPN();

# Stop apache-soap service
EBox::ControlCenter::Common::manageApacheSOAP('stop');
