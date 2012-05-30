# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::RemoteServices::RESTClient;

# Class: EBox::RemoteServices::RESTClient
#
#   Zentyal Cloud REST client. It provides a common
#   interface to access Zentyal Cloud services
#

use warnings;
use strict;

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::RemoteServices::RESTResult;
use URI;
use LWP::UserAgent;
use Error qw(:try);

use constant BASE_URL => 'http://192.168.156.1:8000/api/'; #FIXME

# Method: new
#
#   Zentyal Cloud REST client. It provides a common
#   interface to access Zentyal Cloud services
#
sub new {
    my $class = shift;

    my $self = bless({}, $class);
    return $self;
}

# Method: GET
#
#   Perform a GET operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub GET {
    my ($self, $path, $query) = @_;
    return $self->request('GET', $path, $query);
}

# Method: PUT
#
#   Perform a PUT operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub PUT {
    my ($self, $path, $query) = @_;
    return $self->request('PUT', $path, $query);
}

# Method: POST
#
#   Perform a POST operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub POST {
    my ($self, $path, $query) = @_;
    return $self->request('POST', $path, $query);
}

# Method: DELETE
#
#   Perform a DELETE operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub DELETE {
    my ($self, $path, $query) = @_;
    return $self->request('DELETE', $path, $query);
}


sub request {
    my ($self, $method, $path, $query) = @_;

    throw EBox::Exceptions::MissingArgument('method') unless (defined($method));
    throw EBox::Exceptions::MissingArgument('path') unless (defined($path));

    # build UA
    my $ua = LWP::UserAgent->new;
    my $version = EBox::Config::version();
    $ua->agent("ZentyalServer $version");

    my $req = HTTP::Request->new( $method => BASE_URL . $path );

    #build headers
    if ($query) {
        my $uri = URI->new();
        $uri->query_form($query);

        my $data = $uri->query();
        $req->content_type('application/x-www-form-urlencoded');
        $req->content($data);
        $req->header('Content-Length', length($data));
    } else{
        $req->header('Content-Length', 0);
    }

    my $res = $ua->request($req);

    if ($res->is_success) {
        return new EBox::RemoteServices::RESTResult($res);
    }
    else {
        $self->{last_error} = new EBox::RemoteServices::RESTResult($res);
        throw EBox::Exceptions::Internal($res->content());
    }
}


# Method: last_error
#
#   Return last error result after a failed request
#
sub last_error
{
    my ($self) = @_;

    return $self->{last_error};
}


1;

