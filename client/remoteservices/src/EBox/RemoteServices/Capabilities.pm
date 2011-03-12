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

package EBox::RemoteServices::Capabilities;
use base 'EBox::RemoteServices::Auth';

# Class: EBox::RemoteServices::Capabilities
#
#      This class requests to the Cloud about the capabilities of this
#      Zentyal server
#

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::DataNotFound;

use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Capabilities> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: subscriptionLevel
#
#     Check the subscription level with the cloud
#
sub subscriptionLevel
{
    my ($self) = @_;

    my $result = { level => -1, codename => ''};

    try {
        $result = $self->soapCall('subscriptionLevel');
    } otherwise {
        EBox::warn("SOAP call subscriptionLevel failed: $@");
    };

    return $result;
}

# Method: securityUpdatesAddOn
#
#     Check the if securityUpdates addon is available in the cloud
#
sub securityUpdatesAddOn
{
    my ($self) = @_;

    my $result = '';

    try {
        $result = $self->soapCall('securityUpdatesAddOn');
    } otherwise {
        EBox::warn("SOAP call securityUpdatesAddOn failed: $@");
    };

    return $result;
}

# Method: disasterRecoveryAddOn
#
#     Check the if disaster recovery addon is available in the cloud
#     for this company
#
sub disasterRecoveryAddOn
{
    my ($self) = @_;

    my $result = '';

    try {
        $result = $self->soapCall('disasterRecoveryAddOn');
    } otherwise {
        EBox::warn("SOAP call disasterRecoveryAddOn failed: $@");
    };

    return $result;
}

# Method: technicalSupport
#
#     Check the if the zentyal server has technical support
#     for this company
#
sub technicalSupport
{
    my ($self) = @_;

    my $result = -2;

    try {
        $result = $self->soapCall('technicalSupport');
    } otherwise {
        EBox::warn("SOAP call technicalSupport failed: $@");
    };

    return $result;
}

# Method: renovationDate
#
#     Check the if the zentyal server has technical support
#     for this company
#
sub renovationDate
{
    my ($self) = @_;

    my $result = -1;

    try {
        $result = $self->soapCall('renovationDate');
    } otherwise {
        EBox::warn("SOAP call renovationDate failed: $@");
    };

    return $result;
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
    return 'capabilitiesServiceUrn';
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
