# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::RemoteServices::Monitor;
use base 'EBox::RemoteServices::Auth';

# Class: EBox::RemoteServices::Monitor
#
#      This class sends monitor stats using deltas to the Control
#      Panel using the SOAP client through VPN. It already takes into
#      account to establish the VPN connection and the required data
#      to auth data
#

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::DataNotFound;

use Error qw(:try);
use File::Slurp;

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Monitor> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: sendAll
#
#     Send a tarball containing all monitor stats in RRD files format
#
# Positional parameters:
#
#     tarFilePath - String the tarball file path
#
# Returns:
#
#     true - if the transaction was ok
#
#     false - otherwise
#
sub sendAll
{
    my ($self, $tarFilePath) = @_;

    my $tarContent = File::Slurp::read_file($tarFilePath);

    $self->soapCall('createStats', tarRRDDir => $tarContent);
}

# Method: sendDelta
#
#     Send a delta file containing the differences between latest sent
#     tarball and current monitor stats
#
# Positional parameters:
#
#     deltaFilePath - String the delta file path
#
# Returns:
#
#     true - if the transaction was ok
#
#     false - otherwise
#
sub sendDelta
{
    my ($self, $deltaFilePath) = @_;

    my $deltaContent = File::Slurp::read_file($deltaFilePath);

    $self->soapCall('syncStats', deltaFile => $deltaContent);
}


# Group: Protected methods

# Method: _serviceUrnKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceUrnKey>
#
sub _serviceUrnKey
{
    return 'monitorServiceUrn';
}

# Method: _serviceHostNameKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceHostNameKey>
#
sub _serviceHostNameKey
{
    return 'managementProxy';
}

1;
