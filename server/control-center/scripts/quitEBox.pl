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

# This script is intended to quit an eBox from the Control center

use warnings;
use strict;

# Standard libraries
use Getopt::Long;
use Fcntl;

# Dependencies
use File::Slurp qw( read_file write_file ) ;
use Date::Calc::Object qw(:all);

#############
# eBox uses
#############
use EBox;

# Common procedures and constants for CC scripts
use EBox::ControlCenter::Common qw(:all);
use EBox::ControlCenter::FileEBoxDB;

# Constants

# SSL-related constants
use constant CRL_DIR     => CATopDir() . 'crl/';
use constant LASTEST_CRL => CRL_DIR . 'lastest.pem';

use constant REVOKE_REASON => 'cessationOfOperation';

# Procedure: _usage
#
#      Print the usage prompt
#

sub _usage
  {

    print 'quitEBox.pl [--conf=OpenSSLConfFile] [--usage|help] commonName' . $/;
    print 'Where       conf: the path to the OpenSSL configuration file' . $/;
    print '           usage: print this help' . $/;
    print '      commonName: the common name which eBox will be identified' . $/;

    exit 1;

  }


# Procedure: _revokeEBoxCert
#
#       Revoke a certificate for the given common name
#
# Parameters:
#
#       cn   - the common name for the eBox
#       confFile - the configuration file to read default values
#       - Unnamed parameters
#
#
sub _revokeEBoxCert
  {

    my ($commonName, $confFile) = @_;

    # Search for the certificate to revoke
    my $certFile = findCertFile($commonName);

    # Indeed, revoke the certificate
    system( OpenSSLPath() . qq{ ca -config $confFile -batch } .
	    qq{-revoke $certFile -crl_reason } . REVOKE_REASON );

    # Generate the CRL for today
    (my $day, my $month, my $year) = Date::Calc::Today();
    my $date = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);

    system( OpenSSLPath() . qq{ ca -config $confFile -batch } .
	    '-gencrl -out ' . CRL_DIR . $date . '-crl.pem' );

    # Set the link to the last CRL
    unlink ( LASTEST_CRL ) if ( -e LASTEST_CRL );
    symlink ( CRL_DIR . $date . '-crl.pem', LASTEST_CRL );

    return 1;

  }

# Procedure: _deleteEBox
#
#      Delete the metadata from eBox to delete
#
# Parameters:
#
#      commonName - the common name for the next deleted eBox
#
sub _deleteEBox
  {

    my ($commonName) = @_;


    return 1;

  }

# Procedure: _unlinkOpenVPNFile
#
#     Unlink the OpenVPN client configuration file for this eBox,
#     which makes impossible to connect this eBox to the control
#     center.
#
# Parameters:
#
#     commonName - the common name which identifies eBox to quit
#
sub _unlinkOpenVPNFile
  {

    my ($commonName) = @_;

    my $ccf = OpenVPNClientConfigDir() . $commonName;

    if ( -f $ccf ) {
      # If this exists, remove it!
      unlink ( $ccf );
    }
    else {
      print STDERR 'No OpenVPN client configuration file to delete' . $/;
    }

    return 1;

  }

###############
# Main program
###############

# Become ebox user
EBox::init();

my ($usage, $confFile) = (0, SSLConfFile());

my $correct = GetOptions(
			 "usage|help" => \$usage,
			 "conf=s"     => \$confFile,
			);

# Now in ARGV there's the last compulsory arguments
if ( $usage or (not $correct) or ( scalar(@ARGV) != 1) ) {
  _usage();
}

my $commonName = $ARGV[0];

my $fileDB = new EBox::ControlCenter::FileEBoxDB();

# Inform the eBox will be quit from Control center
# SOAP call to quitCC method

# Check existence
unless ( checkExistence($fileDB, $commonName) ) {
  print STDERR "The eBox with common name *$commonName* does NOT "
    . "have a valid certificate $/";
  exit 2;
}

# Revoke the certificate
_revokeEBoxCert($commonName, $confFile);

# Delete from the db
$fileDB->deleteEBox($commonName);

# Delete the OpenVPN file
_unlinkOpenVPNFile($commonName);

# Restart Apache SOAP service
EBox::ControlCenter::Common::manageApacheSOAP('restart');
