# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::DisasterRecovery
#
#     This class is intended as the client side of the Disaster
#     Recovery WS
#

package EBox::RemoteServices::DisasterRecovery;
use base 'EBox::RemoteServices::Auth';
#

use strict;
use warnings;

use EBox::Backup;
use EBox::Config;
use EBox::Exceptions::DataNotFound;

use File::Glob ':globally';
use File::Slurp;
use File::Temp;
use Data::Dumper;
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::DisasterRecovery> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: credentials
#
#     Get the credentials to back up your data
#
# Returns:
#
#     Hash ref - containing the following keys
#
#           username - String the user name
#           password - String the password for that user in that server
#           server   - String the backup server host name
#           quota    - Int the allowed quota
#
sub credentials
{
    my ($self) = @_;

    return $self->soapCall('credentials');

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
    return 'disasterRecoveryServiceUrn';
}

# Method: _serviceHostNameKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceHostNameKey>
#
sub _serviceHostNameKey
{
    return 'backupServiceProxy';
}

# Group: Private methods

1;
