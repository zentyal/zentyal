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

# Class: EBox::ControlCenter::FileEBoxDB
#
#      Class which overrides <EBox::ControlCenter::FileEBoxDB> to
#      store/retrieve eBoxes from the control center
#

package EBox::ControlCenter::FileEBoxDB;

use base 'EBox::ControlCenter::AbstractEBoxDB';

use strict;
use warnings;

# eBox uses
use EBox::ControlCenter::Common;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

################
# Dependencies
################
use File::Slurp;
use Net::IP;

# Group: Public methods

# Constructor: new
#
#      Create the FileEBoxDB object
#
# Parameters:
#
# file - String file path to the database *(Optional)* Default value:
#             the one given <EBox::ControlCenter::Common::CCDBFile>
#
# Returns:
#
#      <EBox::ControlCenter::FileEBoxDB> - the newly created
#      object
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - if the file cannot be read/write
#
sub new
  {

      my ($class, $dbFile) = @_;
      my $self = {};

      bless($self, $class);

      if ( defined ( $dbFile ) ) {
          $self->{file} = $dbFile;
      } else {
          $self->{file} = EBox::ControlCenter::Common::CCDBFile();
      }

      # Check the possibility to write/read a file
      if ( -e $self->_file() ) {
          ( -r $self->_file() ) or
            throw EBox::Exceptions::Internal('The file ' . $self->_file() .
                                             ' cannot be read' . $/);
          ( -w $self->_file() ) or
            throw EBox::Exceptions::Internal('The file ' . $self->_file() .
                                             ' cannot be written' . $/);
      }

      return $self;

  }

# Method: storeEBox
#
#      Store the metadata from an eBox
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::storeEBox>
#
# Parameters:
#
#      commonName - String the common name for the newly joined eBox
#      serialNumber - the serial number which has the certificate
#      clientIP - the fixed IP address leased
#      - Unnamed parameters
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - throw if any parameter is
#     missing
#
sub storeEBox
  {

      my ($self, $commonName, $serialNumber, $clientIP) = @_;

      # Check parameters existence
      defined ( $commonName ) or
        throw EBox::Exceptions::MissingArgument('commonName');
      defined ( $serialNumber ) or
        throw EBox::Exceptions::MissingArgument('serialNumber');
      defined ( $clientIP ) or
        throw EBox::Exceptions::MissingArgument('clientIP');

      open ( my $dbFile, '>>', $self->_file());

      # Seek to the last position SEEK_END = 2
      seek ( $dbFile, 0, 2 );

      # Print the pair
      print $dbFile qq{$commonName\t$serialNumber\t$clientIP\n};
      close ($dbFile);

  }

# Method: deleteEBox
#
#      Delete the metadata from an eBox
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::deleteEBox>
#
# Parameters:
#
#      commonName - String the common name for the next deleted eBox
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - throw if any parameter is
#     missing
#
sub deleteEBox
  {

      my ($self, $commonName) = @_;

      defined ( $commonName ) or
        throw EBox::Exceptions::MissingArgument('commonName');

      my @eBoxes = read_file ( $self->_file() );

      # Delete the line with the common name given
      my @remainderEBoxes = grep { !/^$commonName\t/ } @eBoxes;

      # Write down the remainder eBoxes
      write_file ( $self->_file(), @remainderEBoxes );

  }

# Method: findEBox
#
#       Check the existence of an eBox created from this control
#       center
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::findEBox>
#
# Parameters:
#
#       commonName - String the common name which the eBox is
#                    identified
#
# Returns:
#
#       hash ref - containing the metadata available for this
#       eBox. Check <EBox::ControlCenter::FileEBoxDB::storeEBox> to
#       know the fields available
#       undef - otherwise
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - throw if any parameter is
#     missing
#
sub findEBox
  {

      my ( $self, $commonName ) = @_;

      my @lines;
      if ( -f $self->_file() ) {
          @lines = read_file ( $self->_file() );
      }
      else {
          return undef;
      }

      foreach my $line (@lines) {
          chomp ($line);
          my ($eBoxCN, $serialNumber, $clientIP) = split ( /\t/, $line );
          if ( $eBoxCN eq $commonName ) {
              return {
                      'commonName' => $eBoxCN,
                      'serialNumber' => $serialNumber,
                      'clientIP' => $clientIP,
                     }
          }
      }

      return undef;

  }

# Method: freeIPAddress
#
#       Get the first IP address to use given a vpnNetwork.
#       It assumes the first IP address is for the vpn server.
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::findEBox>
#
# Parameters:
#
#       vpnNetwork - <Net::IP> the VPN Network
#
# Returns:
#
#      String - containing the IP address given
#      undef - if not enough IP addresses can be given
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - throw if any parameter is
#     missing
#
sub freeIPAddress
  {

      my ($self, $vpnNetwork) = @_;

      defined ( $vpnNetwork ) or
        throw EBox::Exceptions::MissingArgument('vpnNetwork');

      my @eBoxes;
      if ( -f $self->_file() ) {
          @eBoxes = read_file ( $self->_file() );
      }
      else {
          # No file was created
          @eBoxes = ();
      }

      # First IP address to the OpenVPN server
      my $initialIP = $vpnNetwork + 2;
      my $range = new Net::IP( $initialIP->ip() . '-' . $vpnNetwork->last_ip());

      if ( scalar( @eBoxes ) == 0 ) {
          # Set the initial IP address
          return $range->ip();
      }
      elsif ( scalar ( @eBoxes ) > $vpnNetwork->size()->as_int() ) {
          # If there's more than eBoxes allowed, return undef
          return undef;
      }

      my %ipAddresses;

      foreach my $eBox (@eBoxes) {
          # Remove trailing newline characters
          chomp($eBox);
          my ($cn, $serial, $ipAddress) = split ( /\t/, $eBox);
          $ipAddresses{$ipAddress} = 1;
      }

      # Check for the lowest one that can be given
      do {
          if ( not $ipAddresses{$range->ip()} ) {
              return $range->ip();
          }
      } while ( $range++ );

      return undef;

  }

# Method: destroyDB
#
#      Destroy all eBoxes stored in the database *(abstract)*
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::destroyDB>
#

sub destroyDB
  {

      my ( $self ) = @_;

      if ( -f $self->_file() ) {
          unlink ( $self->_file() );
      }

  }

# Method: listEBoxes
#
#      List all eBoxes stored in the database *(abstract)*
#
# Overrides:
#
#      <EBox::ControlCenter::AbstractEBoxDB::listEBoxes>
#
# Returns:
#
#      array ref - list containing the list of eBoxes names. It could
#      be empty if there is no eBoxes attached
#
sub listEBoxes
  {
      my ($self) = @_;

      my @lines;
      if ( -f $self->_file() ){
          @lines = read_file( $self->_file() );
      } else {
          return [];
      }

      my @eBoxes;
      foreach my $line (@lines) {
          # Get the first field
          my ($cn) = split ( /\t/, $line, 2 );
          push (@eBoxes, $cn);
      }

      return \@eBoxes;

  }
# Group: Private methods

####################
# Helper functions
####################

# Return the path to the file where the eBoxes's metadata are stored
sub _file
  {

      my ($self) = @_;
      return $self->{file};

  }
1;
