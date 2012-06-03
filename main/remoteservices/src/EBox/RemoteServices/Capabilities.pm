# Copyright (C) 2008-2012 eBox Technologies S.L.
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
use base 'EBox::RemoteServices::Cred';

# Class: EBox::RemoteServices::Capabilities
#
#      This class requests to the Cloud about the capabilities of this
#      Zentyal server (Subscription details)
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

# Method: subscriptionDetails
#
#     Get the subscription details from Zentyal Cloud once authentication is done
#
# Returns:
#
#     Hash ref - containing the following info
#
#          codename - String the subscription codename
#          level    - Int the subscription level
#          security_updates - Boolean the security updates are on
#          disaster_recovery - Boolean the disaster recovery is on
#          technical_support - Int the technical support level
#          renovation_date  - Int the renovation date in seconds from epoch
#
sub subscriptionDetails
{
    my ($self) = @_;

    my $uuid = $self->{cred}->{uuid};
    my $response = $self->RESTClient()->GET("/v1/servers/$uuid/subscription/");
    $self->{details} = $response->data();
    return $self->{details};
}

1;
