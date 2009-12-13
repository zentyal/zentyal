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
use EBox::RemoteServices::Configuration;
use EBox::Sudo;

use Digest::SHA;
use Error qw(:try);
use File::Slurp;
use Net::DNS::Resolver;
use SOAP::Lite;

use constant CREATE_MON_STATS => 'createMonStats';
use constant SYNC_MON_STATS   => 'syncMonStats';
use constant STORAGE_HOST_KEY => 'storageHost';

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

    return $self->_uploadLargeFile($tarFilePath, CREATE_MON_STATS);

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

    return $self->_uploadLargeFile($deltaFilePath, SYNC_MON_STATS);

}

# Method: deleteData
#
#      Delete all data related to monitor service
#
sub deleteData
{
    my ($self) = @_;

    my $tarLocation = EBox::RemoteServices::Configuration::OldTarLocation();
    if (-e $tarLocation ) {
        unlink($tarLocation);
    }

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
