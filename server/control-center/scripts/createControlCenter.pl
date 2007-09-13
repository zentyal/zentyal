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

# This script is intended to create a certification authority to
# manage eBox's groups

use warnings;
use strict;

################
# Core modules
################
use Getopt::Long;
use File::Basename;
use Error qw(:try);

# eBox dependencies
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Validate qw(checkIP checkCIDR);
use EBox;
use EBox::Sudo;

###############
# Dependencies
###############
use File::Slurp;
use Net::IP;

# Common procedures for CC scripts
use EBox::ControlCenter::Common qw(:all);
use EBox::ControlCenter::ApacheSOAP;

# Constants
use constant DEFAULT_DAYS  => 3650;
use constant DEFAULT_ON    => 'group of eBoxes';
use constant CA_CN   => 'Certificate Authority';
use constant OPENVPN_SERVER_CN => 'OpenVPN server';
use constant OPENVPN_SERVER_CONF_FILE => eBoxCCDir() . '/conf/openvpn-server.conf';
use constant DH_FILE => '/etc/openvpn/dh1024.pem';
use constant DEV_DIR => '/dev/net';
use constant TUN_DEV => '/dev/net/tun';

# Directory mode to allow only owner and readable from others
use constant DIR_MODE => 00700;

# Group: Private procedures

# Procedure: usage
#
#      Print the usage prompt
#
sub _usage
  {

    print 'createControlCenter.pl [--days=daysToExpire] [--on=organizationName] ' .
          '[--vpnproto=vpnProtocol] [--vpnport=vpnPort] [--soapport=soapPort] ' .
          '[--conf=OpenSSLConfFile] [--usage|help] publicIP vpnAddress' . $/;
    print 'Where       days: the number of days until the Certification Authority is valid' . $/;
    print '              on: the name of the organization which CA has' . $/;
    print '        vpnproto: the protocol will OpenVPN go (Options: tcp or udp) Default: udp' . $/;
    print '         vpnport: the port where OpenVPN server will be listening to. Default: 1194' . $/;
    print '        soapport: the port where Apache SOAP Web server will be listening to. Default: 4430' . $/;
    print '            conf: the path to the OpenSSL configuration file' . $/;
    print '           usage: print this help' . $/;
    print '        publicIP: IP address (x.x.x.x) which eBox will connect to' . $/;
    print '      vpnAddress: VPN address (x.x.x.x/xx) which eBox and the ' .
          'control center will be communicating each other' . $/;

    exit 1;

  }


# Procedure: _createCA
#
#        Create a Certification Authority with the configuration
#        settings given by OpenSSL configuration file with no password
#
# Parameters:
#
#        days - Int the number of days which the CA will be valid
#        on   - the organization name for the CA
#        confFile - the configuration file to read default values
#        - Unnamed parameters
#
# Exceptions:
#
#        throw any exception if any error happened
#
sub _createCA # (days, on, confFile)
  {

    my ($days, $orgName, $confFile) = @_;

    unless ( -d CATopDir() ) {
      # Create the directory hierchary
      mkdir ( CATopDir(), DIR_MODE );
      # Let's assume the configuration default values for sub dirs
      mkdir ( CATopDir() . '/certs', DIR_MODE );
      mkdir ( CATopDir() . '/crl', DIR_MODE );
      mkdir ( CATopDir() . '/newcerts', DIR_MODE );
      mkdir ( CATopDir() . '/keys', DIR_MODE );
      mkdir ( CATopDir() . '/private', DIR_MODE );
      mkdir ( CATopDir() . '/reqs', DIR_MODE );
      # Create index and CRL number
      open ( my $out, '>', CATopDir() . '/index.txt');
      close ($out);
      open ( $out, '>', CATopDir() . '/crlnumber');
      print $out '01' . $/;
      close ($out);
    }
    else {
      die 'Control center is already created';
    }

    # FIXME: Check 2038 year bug -> 2038/17/1

    my $commonName = CA_CN;

    # Create the self-signed certificate
    system( OpenSSLPath() . qq{ req -new -x509 -config $confFile -batch } .
	    '-keyout ' . CATopDir() . '/private/cakey.pem -nodes ' .
	    '-out ' . CACert() . ' -subj ' .
	    qq{'/O=$orgName/CN=$commonName/' -days $days} );

    # Create the serial OpenSSL v 0.9.7
    unless ( -f CATopDir() . '/serial' ) {
      system ( OpenSSLPath() . ' x509 -in ' . CATopDir() . '/cacert.pem ' .
	       '-noout -next_serial -out ' . CATopDir() . '/serial' );
    }

  }

# Procedure: _issueCert
#
#        Issue a certificate
#
# Parameters:
#
#        days     - Integer days the certificate will be valid for
#        orgName  - String the organization name for the CA
#        commonName - String the common name to use the certificate
#        confFile - String the path to the OpenSSL configuration file
#        - Named parameters
#
# Returns:
#
#        String - the serial number which the certificate has
#
sub _issueCert
  {

      my (%args) = @_;
      my ( $days, $orgName, $commonName, $confFile ) = 
        ( $args{days}, $args{orgName}, $args{commonName}, $args{confFile});

      my $dnString = qq{/CN=$commonName/O=$orgName/};
      my $privKey  = CAPrivateDir() . $commonName . '.pem';
      my $reqFile = CARequestDir() . $commonName . '.pem';

      # Launch the request
      system ( OpenSSLPath() . qq{ req -new -keyout '$privKey'} .
               qq{ -nodes -out '$reqFile' -subj '$dnString'} );

      # Sign the request
      system ( OpenSSLPath() . qq{ ca -config $confFile -batch } .
               '-outdir ' . CACertDir() . ' -policy policy_anything -keyfile ' .
               CAPrivateDir() . qq{/cakey.pem -days $days -subj '$dnString' -in '$reqFile'} );

      # Get the serial number to be signed this eBox
      my $serial = read_file( SSLOldSerialFile() );
      chomp($serial);

      return $serial;

  }

# Procedure: _storeConfParams
#
#        Store the public IP address and the VPN address on the
#        control center configuration file
#
# Parameters:
#
#        public_ip_address - String the public IPv4 address (x.x.x.x)
#
#        vpn_network - String the VPN address in CIDR format
#                      (x.x.x.x/x)
#
#        vpn_server_protocol - String the protocol where VPN server will be
#                              listening
#        vpn_server_port - Integer the port where VPN server will be
#                          listening
#        soap_server_port - Integer the port where the Apache SOAP Web server
#                           will be listening to
#
#        - Named parameters
#
sub _storeConfParams
  {

    my ( %args ) = @_;

    my @confLines = read_file ( CCConfFile() );

    for (my $idx = 0; $idx < scalar (@confLines); $idx++) {
      my $line = $confLines[$idx];
      chomp($line);
      # Ignore lines starting with #
      next if ( $line =~ m/^#/ );
      foreach my $key (keys %args) {
	if ( $line =~ m/$key/ ) {
	  $line =~ s/^(.*)$key(.*)=(.*)$/$key = $args{$key}/;
	  $line .= $/;
	  $confLines[$idx] = $line;
	}
      }
    }

    write_file ( CCConfFile(), @confLines );

    return;

  }

# Procedure: _createOpenVPNFile
#
#        Create the OpenVPN server configuration file which will be
#        read by OpenVPN server.
#
# Parameters:
#
#        publicIP - the public IPv4 address will be set up here
#        vpnProto - String the protocol to use
#        vpnPort - Integer the port to listen to
#        serial - the certificate serial number for the OpenVPN server
#        cn - the common name given to the OpenVPN server
#        vpnAddress - the VPN network in CIDR notation
#
#        - Named parameters
#
sub _createOpenVPNFile
  {

    my ( %args ) = @_;

    my @confLines = read_file ( OPENVPN_SERVER_CONF_FILE );

    for ( my $idx = 0; $idx < scalar (@confLines); $idx++ ) {
      my $line = $confLines[$idx];
      chomp($line);
      if ( $line =~ m/<publicIP>/ ) {
	$line = qq{local $args{publicIP} $/};
	$confLines[$idx] = $line;
      }
      elsif ( $line =~ m/^port/ ) {
	$line = qq{port $args{vpnPort} $/};
	$confLines[$idx] = $line;
      }
      elsif ( $line =~ m/^proto/ ) {
	$line = qq{proto $args{vpnProto} $/};
	$confLines[$idx] = $line;
      }
      elsif ( $line =~ m/^cert/ ) {
	my $certFile = CACertDir() . $args{serial} . '.pem';
	$line = qq{cert "$certFile" $/};
	$confLines[$idx] = $line;
      }
      elsif ( $line =~ m/^key/ ) {
	my $keyFile = CAPrivateDir() . $args{cn} . '.pem';
	$line = qq{key "$keyFile" $/};
	$confLines[$idx] = $line;
      }
      elsif ( $line =~ m/^server/ ) {
	my $block = new Net::IP($args{vpnAddress});
	$line = 'server ' . $block->ip() . ' ' . $block->mask() . $/;
	$confLines[$idx] = $line;
      }

    }

    # Finally write down the config file
    write_file ( OPENVPN_SERVER_CONF_FILE, @confLines );

    # Create a symbolic link with the /etc/openvpn start up when reboot
    # is done
    EBox::Sudo::root ( q{ln -s '} . OPENVPN_SERVER_CONF_FILE . q{' '} . OpenVPNServerFileEtc() . q{' });

  }

# Procedure: _setupOpenVPN
#
#     Set up the OpenVPN parameters and devices to work in an
#     environment quite hostile or new
#
sub _setupOpenVPN
  {

    # Add tun device if it doesn't exist
    unless ( -d DEV_DIR ) {
      EBox::Sudo::root( 'mkdir ' . DEV_DIR . ' 0755' );
    }
    try {
        # Check the existence as character device of the TUN_DEV
        # Check as root since it the only allowable to check it
        EBox::Sudo::root( 'test -c ' . TUN_DEV );
    } catch EBox::Exceptions::Sudo::Command with {
      EBox::Sudo::root( 'mknod ' . TUN_DEV . ' c 10 200' );
    };

    # Create the Diffie-Hellman parameters
    unless ( -f DH_FILE ) {
      EBox::Sudo::root( OpenSSLPath() . ' dhparam -out ' . DH_FILE . ' 1024' );
    }

  }

# Procedure: _setupSOAPServer
#
#      Set up the Apache SOAP Web server
#
sub _setupSOAPServer
  {

      EBox::ControlCenter::Common::manageApacheSOAP('start');

  }

# Procedure: _createEBoxDB
#
#    Create the eBox database
#
sub _createEBoxDB
  {

      my $dbFile = EBox::ControlCenter::Common::CCDBFile();
      my ($dir, $fileName) = File::Basename::fileparse($dbFile);

      unless ( -d $dir ) {
          mkdir ( $dir, 0700 );
      }

  }

###############
# Main program
###############

# Become eBox user
EBox::init();

# Default Options
my ($days, $organizationName, $usage, $confFile, $vpnPort, $vpnProto, $soapPort)
  = ( DEFAULT_DAYS, DEFAULT_ON, '', SSLConfFile(), 1194, 'udp', 4430 );

my $correct = GetOptions(
			 "on=s"        => \$organizationName,
			 "usage|help"  => \$usage,
			 "days=i"      => \$days,
			 "conf=s"      => \$confFile,
			 "vpnport=i"   => \$vpnPort,
			 "vpnproto=s"  => \$vpnProto,
                         "soapport=i"  => \$soapPort,
			);

# Now in ARGV there's the last compulsory arguments
if ( $usage or (not $correct) or ( scalar(@ARGV) != 2) ) {
  _usage();
}

my $publicIP = $ARGV[0];
my $vpnAddress = $ARGV[1];

# Check if it is an IP
unless ( defined ( EBox::Validate::checkIP($publicIP) ) ) {
  print STDERR 'Not a valid IP (x.x.x.x)' . $/;
  _usage();
}

# Check if it is a correct IP address
unless ( defined ( EBox::Validate::checkCIDR($vpnAddress) ) ) {
  print STDERR 'Not a valid network CIDR IP Address (x.x.x.x/x)' . $/;
  _usage();
}

# Check protocol
unless ( $vpnProto eq 'tcp' or $vpnProto eq 'udp' ) {
  print STDERR 'The VPN protocol will go over should be tcp or udp' . $/;
  _usage();
}

# Check ports
unless ( defined ( EBox::Validate::checkPort($vpnPort) ) ) {
  print STDERR 'The OpenVPN server should listen to a valid port' . $/;
  _usage();
}
unless ( defined ( EBox::Validate::checkPort($soapPort) ) ) {
  print STDERR 'The Apache SOAP Web server should listen to a valid port' . $/;
  _usage();
}

# Create the CA
_createCA($days, $organizationName, $confFile);

# Issue certificate for the OpenVPN server where the eBoxes
# will be connected to. It should not be revoked until the CA
# certificate will be revoked.
my $serialServer = _issueCert(days       => $days,
                              orgName    => $organizationName,
                              commonName => OPENVPN_SERVER_CN,
                              confFile   => $confFile,
                             );

# Store configuration parameters
_storeConfParams( public_ip_address   => $publicIP,
		  vpn_network         => $vpnAddress,
		  vpn_server_port     => $vpnPort,
		  vpn_server_protocol => $vpnProto,
                  soap_server_port    => $soapPort);

# Create the OpenVPN configuration file
_createOpenVPNFile(
		   publicIP   => $publicIP,
		   vpnProto   => $vpnProto,
		   vpnPort    => $vpnPort,
		   serial     => $serialServer,
		   cn         => OPENVPN_SERVER_CN,
		   vpnAddress => $vpnAddress,
		  );

# Set up the OpenVPN environment
_setupOpenVPN();

# Create the infrastructure for the eBoxes database
_createEBoxDB();

# Issue the certificate for the Control Center
_issueCert(
           days       => $days,
           orgName    => $organizationName,
           commonName => EBox::ControlCenter::Common::controlCenterCN(),
           confFile   => $confFile,
          );

# Launch the OpenVPN server
EBox::ControlCenter::Common::execOpenVPN('restart');
# Set up the Apache SOAP Web Server
_setupSOAPServer();

