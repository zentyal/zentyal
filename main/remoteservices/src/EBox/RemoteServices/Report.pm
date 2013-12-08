# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::RemoteServices::Report;

use base 'EBox::RemoteServices::Cred';

# Class: EBox::RemoteServices::Report
#
#      This class sends the report to the cloud using the REST API
#

use strict;
use warnings;

# Group: Public methods

# Method: report
#
#     Push report results from a collection to the cloud
#
# Parameters:
#
#     name - String the report collection
#
#     result - String the report results already in JSON
#
sub report
{
    my ($self, $name, $result) = @_;

    # We're assumming a JSON-encoded string has been received
    my $response = $self->RESTClient()->POST("/v1/reports/$name/",
                                             query => $result,
                                             retry => 1);
}

1;

