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

# Class: EBox::ControlCenter::AbstractEBoxDB
#
#      Abstract class which encapsulates how eBoxes are stored in the
#      control center.
#

package EBox::ControlCenter::AbstractEBoxDB;

use strict;
use warnings;

use EBox::Exceptions::NotImplemented;

# Group: Public methods

# Constructor: new
#
#      Create the AbstractEBoxDB object
#
# Returns:
#
#      <EBox::ControlCenter::AbstractEBoxDB> - the newly created
#      object
#
sub new
  {

      my ($class) = @_;
      my $self = {};
      bless($self, $class);
      return $self;

  }

# Method: storeEBox
#
#      Store the metadata from an eBox *(abstract)*
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

      throw EBox::Exceptions::NotImplemented();

  }

# Method: deleteEBox
#
#      Delete the metadata from an eBox *(abstract)*
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

      throw EBox::Exceptions::NotImplemented();

  }

# Method: findEBox
#
#       Check the existence of an eBox created from this control
#       center *(abstract)*
#
# Parameters:
#
#       commonName - String the common name which the eBox is
#                    identified
#
# Returns:
#
#       true - if the certificate for this eBox is created and valid
#       undef - otherwise
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - throw if any parameter is
#     missing
#
sub findEBox
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: freeIPAddress
#
#       Get the first IP address to use given a vpnNetwork.
#       It assumes the first IP address is for the vpn server.
#       *(abstract)*
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

      throw EBox::Exceptions::NotImplemented();

  }

# Method: destroyDB
#
#      Destroy all eBoxes stored in the database *(abstract)*
#
sub destroyDB
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: listEBoxes
#
#      List all eBoxes stored in the database *(abstract)*
#
# Returns:
#
#      array ref - list containing the list of eBoxes
#
sub listEBoxes
  {

      throw EBox::Exceptions::NotImplemented();

  }

1;
