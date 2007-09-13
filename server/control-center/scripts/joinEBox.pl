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

# This script is intended to join an eBox to the Control center

use warnings;
use strict;

###############
# Dependencies
###############
use File::Slurp;
use Date::Calc::Object qw(:all);
use Perl6::Junction qw(any);
use Config::Tiny;
use Net::IP;

# Core modules
use Getopt::Long;
use Fcntl;
use Cwd;

###############
# eBox modules
###############
use EBox;
use EBox::Validate;
use EBox::Sudo;

# Common procedures and constants for CC scripts
use EBox::ControlCenter::Common qw(:all);
use EBox::ControlCenter::FileEBoxDB;

# Constants

# Index for every field (split with tabs) withing the eBoxes.db file
use constant CN_BD_IDX     => 0;
use constant SERIAL_DB_IDX => 1;

use constant EXPIRE_DATE_IDX     => 1;
use constant REV_DATE_REASON_IDX => 2;
use constant FILE_IDX            => 4;
use constant SUBJECT_IDX         => 5;

# Procedure: _usage
#
#      Print the usage prompt
#

sub _usage
  {

    print 'joinEBox.pl [--days=daysToExpire] ' .
          '[--conf=OpenSSLConfFile] [--usage|help] commonName' . $/;
    print 'Where       days: the number of days until the eBox certificate is valid. Default value: the days till CA which signs the certificate is valid' . $/;
    print '            conf: the path to the OpenSSL configuration file' . $/;
    print '           usage: print this help' . $/;
    print '      commonName: the common name which eBox will be identified' . $/;

    exit 1;

  }


# A private function to flat a <Date::Calc::Object> to a OpenSSL form like
# YYMMDDHHMMSSZ
sub _flatDate # (date)
  {
    my ($date) = @_;

    return q{} unless ( UNIVERSAL::isa($date, 'Date::Calc'));

    my $dateStr =sprintf("%02d%02d%02d%02d%02d%02dZ",
			 $date->year() - 2000,
			 $date->month(),
			 $date->day(),
			 $date->hours(),
			 $date->minutes(),
			 $date->seconds());

    return $dateStr;

  }

# Given the string date from index.txt file
# obtain the date as a Date::Calc::Object
sub _parseDate
  {
    my ($self, $str) = @_;

    my ($y,$mon,$mday,$h,$m,$s) = $str =~ /([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z$/;

    $y += 2000;
	# my $wday = Day_of_Week($y+1999,$mon,$mday);
    my $date = Date::Calc->new($y, $mon, $mday, $h, $m, $s);

    return $date;
  }

# Procedure: _obtain
#
#      Obtain an attribute from a certificate file
#
# Parameters:
#
#      certFile - the path where the certificate lies
#      attribute -  'DN' return => a DN string /class1=value1/
#                   'CN' return => a CN string from the DN
#                   'O' return  => a O string from the DN
#                   'serial' return => String containing the serial number
#                   'endDate' return => <Date::Calc::Object> with the date
#                   'days' return => number of days from today to expire
#                   undef => if certification file does NOT exist
sub _obtain # (certFile, attribute)
  {

    my ($certFile, $attribute) = @_;

    if (not -f $certFile) {
      return undef;
    }

    my $arg = "";
    if ($attribute eq any('DN', 'CN', 'O')) {
      $arg = "-subject";
    } elsif ($attribute eq 'serial') {
      $arg = "-serial";
    } elsif ($attribute eq 'endDate'
	    or $attribute eq 'days') {
      $arg = "-enddate";
    }
    my $cmd = OpenSSLPath() . qq{ x509 $arg -in '$certFile' -noout};

    my $output = qx($cmd);

    # Remove the attribute name part
    $arg =~ s/-//g;
    if ($arg eq "enddate") {
      $arg = "notAfter";
    }

    $output =~ s/^$arg=( )*//g;

    chomp($output);

    if ($attribute eq 'DN') {
      return $output;
    }
    elsif ( $attribute eq 'CN' ) {
      # Get the Common Name from the DN
      my ($commonName) = $output =~ m/CN=([^\/]+)\//;
      return $commonName;
    }
    elsif ( $attribute eq 'O' ) {
      my ($orgName) = $output =~ m/O=([^\/]+)\//;
      return $orgName;
    }
    elsif ($attribute eq 'serial' ) {
      return $output;
    } elsif ($attribute eq 'endDate' ) {
      my ($monthStr, $day, $hour, $min, $sec, $yyyy) = 
	($output =~ /(.+) (\d+) (\d+):(\d+):(\d+) (\d+) (.+)/);

      $monthStr =~ s/ +//g;
      my $dateObj = Date::Calc->new($yyyy, 
				    Decode_Month($monthStr),
				    $day, $hour, $min, $sec);
      return $dateObj;
    } elsif ($attribute eq 'days') {
      my $certDate = _parseDate($output);
      my $diffDate = $certDate - Date::Calc->Today();
      return $diffDate->day();
    }

  }

# Procedure: _issueEBoxCert
#
#       Issue a certificate for the given common name
#
# Parameters:
#
#       cn   - the common name for the eBox
#       end - Int the number of days which the certificate will be
#              valid or <Date::Calc::Object> if the end date is given
#       confFile - the configuration file to read default values
#       - Unnamed parameters
#
# Returns:
#
#      String - the serial number which identified uniquely the
#      certificate within the CA
#
# Exceptions:
#
#
#

sub _issueEBoxCert
  {

    my ($commonName, $end, $confFile ) = @_;

    my ($days, $endDate);

    # Check if it's a number or a date
    if ( UNIVERSAL::isa( $end, 'Date::Calc' ) ) {
      $endDate = $end;
    }
    else {
      $days = $end;
    }

    # Check the expiration date if days are given
    if ( defined ( $days ) ) {
      my $userDefinedEnd = Date::Calc::Object->now();
      $userDefinedEnd += [ 0, 0, $days, 0, 0, 0];
      my $caEndDate = _obtain(CACert(), 'endDate');
      if ( $userDefinedEnd gt $caEndDate ) {
	die 'The certificate expiration should be lower than the CA '
	  . ' expiration date' . $/;
      }
    }

    # Create the request
    my $dnString = '/CN=' . $commonName . '/O=' . _obtain(CACert(), 'O') . '/';
    my $privKey = CAPrivateDir() . $commonName . '.pem';
    my $reqFile = CARequestDir() . $commonName . '.pem';

    my $cmd = OpenSSLPath() . qq{ req -new -keyout '$privKey'} .
      qq{ -nodes -out '$reqFile' -subj '$dnString'};

    system($cmd);

    # Sign the request
    $cmd = OpenSSLPath() . ' ca -config ' . SSLConfFile() . ' -batch ' .
      '-outdir ' . CACertDir() . ' -policy policy_anything -keyfile ' .
      CAPrivateDir() . '/cakey.pem ';

    # Define days or endDate
    $cmd .= qq{-days $days } if ( defined ( $days ));
    $cmd .= '-enddate ' . _flatDate($endDate) . ' ' if ( defined ( $endDate ));
    $cmd .= qq{-subj '$dnString' };
    $cmd .= qq{-in '$reqFile'};

    system($cmd);

    # Get the serial number to be signed this eBox
    my $serial = read_file( SSLOldSerialFile() );
    chomp($serial);

    return $serial;

  }

# Function: _confParams
#
#      Get the control center cofiguration parameters
#
# Returns:
#
#      hash ref - the hash reference of the configuration parameters
#
sub _confParams
  {

    my $confFile = Config::Tiny->read( CCConfFile() );

    return $confFile->{_};

  }

# Procedure: _createOpenVPNConfFile
#
#      Create the configuration file for this new OpenVPN client.
#
# Parameters:
#
#      commonName - the common name which identifies the newly joined
#                   eBox
#
#      clientIP   - the client IP address
#      networkMask - the VPN mask
#
sub _createOpenVPNConfFile
  {

    my ($commonName, $clientIP, $networkMask) = @_;

    open ( my $dbFile, '>', OpenVPNClientConfigDir() . $commonName )
      or die "Can't open " . OpenVPNClientConfigDir() . "$commonName for writing";

    print $dbFile "ifconfig-push $clientIP $networkMask $/";
    close ($dbFile);

  }

# Procedure: _createTarGz
#
#      Create a tar.gz archive the current path which will be used by
#      eBox recently joined to configure itself to communicate with
#      the control center.
#
#      It stores the client's certificate and private key, the CA
#      certificate and the client's configuration file which it's
#      stored the public IP, port and protocol to connect with OpenVPN
#      server and its own IP and common name.
#
# Parameters:
#
#      cwd - String caller's current working directory
#      commonName - String the eBox common name
#      serial - String the serial number to identify the certificate
#      file within the CA
#      serverParams - hash ref with the server parameters required at
#      the client side
#      - Unnamed parameters
#
sub _createTarGz
  {

    my ($cwd, $commonName, $serialNumber, $serverParams_ref) = @_;

    # Create the symbolic links
    my $path = eBoxCCDir() . '/tmp';

    # Set the client configuration file
    my %clientParams = (
	common_name => $commonName,
	vpn_server_ip => $serverParams_ref->{public_ip_address},
	vpn_server_protocol => $serverParams_ref->{vpn_server_protocol},
	vpn_server_port => $serverParams_ref->{vpn_server_port},
        soap_server_port => $serverParams_ref->{soap_server_port},
		       );

    # Store it in a tmp file
    my $clientConf = new Config::Tiny();
    $clientConf->{_} = \%clientParams;
    $clientConf->write ( "$path/client.conf" );

    # Link certficates
    my $clientCert = CACertDir() . $serialNumber . '.pem';
    my $privateKey = CAPrivateDir() . $commonName . '.pem';
    my $caCert = CACert();
    # Link names
    my $clientCertLink = "$commonName-cert.pem";
    my $privateKeyLink = "$commonName-private-key.pem";
    my $caCertLink = 'ca-cert.pem';

    link ( $clientCert, "$path/$clientCertLink" );
    link ( $privateKey, "$path/$privateKeyLink" );
    link ( $caCert, "$path/$caCertLink" );

    my $zipName = "$commonName.tar.gz";
    my $tarArgs = qq{'$zipName' };
    # The four files to include
    $tarArgs .= qq{'$clientCertLink' '$privateKeyLink' '$caCertLink' client.conf};
    # -h to dump what links point to
    system ( "cd $path; tar czhf $tarArgs" );
    # Put the tar.gz in the current directory
    EBox::Sudo::root( qq{mv '$path/$zipName' '$cwd'} );

    # Remove everthing
    unlink ( "$path/$clientCertLink", "$path/$privateKeyLink", "$path/$caCertLink", "$path/client.conf" );

  }

# Procedure: _restartApacheSOAP
#
#      Restart the apache SOAP server in order to take into account
#      this new added eBox
#
sub _restartApacheSOAP
  {

      EBox::ControlCenter::Common::manageApacheSOAP('restart');

  }

###############
# Main program
###############

# Get caller's current directory
my $cwd = getcwd();

# Become eBox user
EBox::init();

my ($days, $usage, $confFile)
  = ( 0, '', SSLConfFile() );

my $date = undef;

my $correct = GetOptions(
			 "days=i"     => \$days,
			 "conf=s"     => \$confFile,
			 "usage|help" => \$usage,
			);

# Now in ARGV there's the last compulsory arguments
if ( $usage or (not $correct) or ( scalar(@ARGV) != 1) ) {
  _usage();
}

my $fileDB = EBox::ControlCenter::FileEBoxDB->new();

my $commonName = $ARGV[0];

# Check the common name
unless ( EBox::Validate::checkName($commonName) ) {
    print STDERR "The common name $commonName is not valid. " .
      'It should only contain alphanumeric characters and ' .
      'underscores and be than 20 characters.' . $/;
    exit 2;
}

# Check the days
if ( $days == 0 ) {
  # Set the days to the CA one
  $date = _obtain(CACert(), 'endDate');
}

if ( checkExistence($fileDB, $commonName) ) {
  print STDERR "The eBox with common name *$commonName* has already "
    . 'a valid certificate' . $/;
  exit 2;
}

# The end parameter passes days if user defined one, or the enddate if not
my $end = $days == 0 ? $date : $days;

my $serialCert = _issueEBoxCert($commonName, $end, $confFile);

# Get the configuration parameters
my $confParams_ref = _confParams();
my $vpnNetwork = new Net::IP($confParams_ref->{vpn_network});

# Get a ready ip address
my $clientIP = $fileDB->freeIPAddress($vpnNetwork);

# Store eBox in the DB
$fileDB->storeEBox($commonName, $serialCert, $clientIP);

# Create the OpenVPN configuration file for this client
_createOpenVPNConfFile($commonName, $clientIP, $vpnNetwork->mask());

# Restart apache-soap server in order to allow connections from this
# eBox
_restartApacheSOAP();

# Create the tar.gz file with all needed information
_createTarGz( $cwd, $commonName, $serialCert, $confParams_ref );

print "$/The client bundle *$commonName.tar.gz* is ready to be uploaded in " .
  "your eBox to communicate with this control center $/$/";
