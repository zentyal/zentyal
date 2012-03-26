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
#   content - body content to send in the request (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub GET {
    my ($self, $path, $query, $content) = @_;
    return $self->request('GET', $path, $query, $content);
}

# Method: PUT
#
#   Perform a PUT operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#   content - body content to send in the request (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub PUT {
    my ($self, $path, $query, $content) = @_;
    return $self->request('PUT', $path, $query, $content);
}

# Method: POST
#
#   Perform a POST operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#   content - body content to send in the request (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub POST {
    my ($self, $path, $query, $content) = @_;
    return $self->request('POST', $path, $query, $content);
}

# Method: DELETE
#
#   Perform a DELETE operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - hash ref containing query parameters (Optional)
#   content - body content to send in the request (Optional)
#
# Returns:
#
#   hash ref with the reply from the server
#
sub DELETE {
    my ($self, $path, $query, $content) = @_;
    return $self->request('DELETE', $path, $query, $content);
}


sub request {
    my ($self, $method, $path, $query, $data) = @_;

    throw EBox::Exceptions::MissingArgument('method') unless (defined($method));
    throw EBox::Exceptions::MissingArgument('path') unless (defined($path));

    #build UA
    my $uri = URI->new(BASE_URL . $path);
    $uri->query_form($query);
    my $url = $uri->as_string();

    my $ua = LWP::UserAgent->new;
    my $version = EBox::Config::version();
    $ua->agent("ZentyalServer $version");

    my $req = HTTP::Request->new( $method => $url );

    #build headers
    if($data){
        $req->content($data);
        $req->header('Content-Length', length($data));
    }else{
        $req->header('Content-Length', 0);
    }

    my $res = $ua->request($req);

    if ($res->is_success) {
        return new EBox::RemoteServices::RESTResult($res);
    }
    else {
        throw EBox::Exceptions::Internal($res->status_line);
    }
}


1;

