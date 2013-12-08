# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::RemoteServices::Alerts;

use base 'EBox::RemoteServices::Cred';

# Class: EBox::RemoteServices::Alerts
#
#      This class sends events to the Control Panel using the REST API
#

use strict;
use warnings;

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Backup> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: pushAlerts
#
#     Push alerts to the CC
#
# Parameters:
#
#     alerts - array ref of <EBox::Event> to be sent to the CC
#
sub pushAlerts
{
    my ($self, $alerts) = @_;

    my $response = $self->RESTClient()->POST("/v1/alerts/servers/",
                                             query => $alerts,
                                             retry => 1);
}

1;
