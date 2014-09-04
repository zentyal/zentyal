# Copyright (C) 2012-2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::RESTClient;

# Class: EBox::RESTClient
#
#   REST client which uses LWP::UserAgent.
#   Its main feature set is having replay for the failed operations.
#

#no warnings 'experimental::smartmatch';
use v5.10;

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::RESTClient::Result;
use EBox::Validate;
use File::Temp;
use HTTP::Status qw(HTTP_BAD_REQUEST HTTP_UNAUTHORIZED);
use IO::Socket::SSL;
use JSON::XS;
use LWP::UserAgent;
use Time::HiRes;
use TryCatch::Lite;
use URI;

use constant JOURNAL_OPS_DIR => EBox::Config::conf() . 'ops-journal/';

# Group: Public methods

# Constructor: new
#
#   Generic REST client
#
# Named parameters:
#
#   server      - String the server hostname or IP address
#   credentials - Hash ref containing the credentials required
#                 to access the given server
#                 It must contain the following keys:
#
#                    realm - String the realm
#                    username - String the username
#                    password - String the password
#
#                 (Optional)
#
#   scheme - String the valid scheme *(Optional)* Default value: https
#
#   uri - String the complete URI (host + scheme). Using this is incompatible
#         with server and scheme arguments
#
#   verifyHostname - Boolean verify hostname when using https scheme.
#                    *(Optional)* Default value: rest_verify_servers configuration key
#
#   verifyPeer - Boolean verify peer certification when using https scheme.
#                If it is set to false, verifyHostname is not taken into account.
#                *(Optional)* Default value: true
#
sub new
{
    my ($class, %params) = @_;

    my $uri = new URI($params{uri});
    if (not defined($params{uri}) and not defined($params{server})) {
            throw EBox::Exceptions::MissingArgument('server');
    }

    my $self = bless(
        { credentials => $params{credentials},
          uri => $uri},
        $class);

    $self->{verifyHostname} = $params{verifyHostname};
    unless (defined($self->{verifyHostname})) {
        $self->{verifyHostname} = EBox::Config::boolean('rest_verify_servers');
    }
    if (exists $params{verifyPeer} and (not $params{verifyPeer})) {
        $self->{verifyPeer} = 0;
    } else {
        $self->{verifyPeer} = 1;
    }

    unless (defined($params{uri})) {
        my $scheme = $params{scheme};
        $scheme = 'https' unless defined($scheme);
        $self->setScheme($scheme);
        $self->setServer($params{server});
    }

    return $self;
}

# Method: setServer
#
#   Set the server the RESTClient must connect to
#
# Parameters:
#
#   server - IP or Domain Name the RESTClient must connect to
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidData> - thrown if the server is not a valid.
#
sub setServer
{
    my ($self, $server) = @_;

    EBox::Validate::checkHost($server, "RESTClient Server");

    $self->{uri}->host($server);
    $self->{server} = $self->{uri}->as_string();
}

# Method: setPort
#
#   Set the server port the RESTClient must connect to
#
# Parameters:
#
#   port - Int the network port
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidData> - thrown if the port is not a valid.
#
sub setPort
{
    my ($self, $port) = @_;

    EBox::Validate::checkPort($port, "RESTClient server port");

    $self->{uri}->port($port);
    $self->{server} = $self->{uri}->as_string();
}

# Method: setScheme
#
#   Set the server scheme where the RESTClient must connect to
#
# Parameters:
#
#   scheme - String it can be https or http
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidData> - thrown if the port is not a valid.
#
sub setScheme
{
    my ($self, $scheme) = @_;

    unless ( $scheme eq 'http' or $scheme eq 'https' ) {
        throw EBox::Exceptions::InvalidData(data => 'scheme', value => $scheme,
                                            advice => 'https or http');
    }

    $self->{uri}->scheme($scheme);
    $self->{server} = $self->{uri}->as_string();
}

# Method: GET
#
#   Perform a GET operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - ref containing query parameters
#            (Optional)
#   retry - Boolean whether the journaling must be used for this call
#                If not specified, it will be DISABLED
#                 (Optional)
#   The optional params are named
#
# Returns:
#
#   hash ref with the reply from the server
#
sub GET {
    my ($self, $path, %params) = @_;
    return $self->request('GET', $path, $params{query}, $params{retry});
}

# Method: PUT
#
#   Perform a PUT operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - ref containing query parameters (Optional)
#   retry - Boolean whether the journaling must be used for this call
#                If not specified, it will be DISABLED
#                 (Optional)
#   The optional params are named
#
# Returns:
#
#   hash ref with the reply from the server
#
sub PUT {
    my ($self, $path, %params) = @_;
    return $self->request('PUT', $path, $params{query}, $params{retry});
}

# Method: POST
#
#   Perform a POST operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - ref containing query parameters (Optional)
#   retry - Boolean whether the journaling must be used for this call
#                If not specified, it will be DISABLED
#                 (Optional)
#   The optional params are named
#
# Returns:
#
#   hash ref with the reply from the server
#
sub POST {
    my ($self, $path, %params) = @_;
    return $self->request('POST', $path, $params{query}, $params{retry});
}

# Method: DELETE
#
#   Perform a DELETE operation
#
# Parameters:
#
#   path - relative path for the query (ie. /subscription)
#   query - ref containing query parameters (Optional)
#   retry - Boolean whether the journaling must be used for this call
#                If not specified, it will be DISABLED
#                 (Optional)
#   The optional params are named
#
# Returns:
#
#   hash ref with the reply from the server
#
sub DELETE {
    my ($self, $path, %params) = @_;
    return $self->request('DELETE', $path, $params{query}, $params{retry});
}

sub request {
    my ($self, $method, $path, $query, $retry) = @_;

    throw EBox::Exceptions::MissingArgument('method') unless (defined($method));
    throw EBox::Exceptions::MissingArgument('path') unless (defined($path));

    # build UA
    my $ua = LWP::UserAgent->new;
    my $version = EBox::Config::version();
    $ua->agent("ZentyalServer $version");
    if ($self->{verifyPeer}) {
        $ua->ssl_opts('verify_hostname' => $self->{verifyHostname});
    } else {
        $ua->ssl_opts('verify_hostname' => 0);
        $ua->ssl_opts('SSL_verify_mode' => IO::Socket::SSL::SSL_VERIFY_NONE);
    }
    # Set HTTP proxy if it is globally set as environment variable
    $ua->proxy('https', $ENV{HTTP_PROXY}) if (exists $ENV{HTTP_PROXY});

    my $req = HTTP::Request->new( $method => $self->{server} . $path );
    if ( exists $self->{credentials} ) {
        $req->authorization_basic($self->{credentials}->{username}, $self->{credentials}->{password});
    }

    #build headers
    if ($query) {
        given(ref($query)) {
            when('ARRAY' ) {
                throw EBox::Exceptions::Internal('Cannot send ARRAY ref as query when using GET method')
                  if ($method eq 'GET');
                # Send data in JSON if the query is an array of elements
                my $encoder = new JSON::XS()->utf8()->allow_blessed(1)->convert_blessed(1);
                my $data = $encoder->encode($query);
                $req->content_type('application/json');
                $req->content($data);
                $req->header('Content-Length', length($data));
            }
            when('') {
                throw EBox::Exceptions::Internal('Cannot send scalar as query when using GET method')
                  if ($method eq 'GET');
                # We're assuming a JSON-encoded string has been passed
                $req->content_type('application/json');
                $req->content($query);
                $req->header('Content-Length', length($query));
            }
            default {
                my $uri = URI->new();
                $uri->query_form($query);
                if ( $method eq 'GET' ) {
                    $req->uri( $self->{server} . $path . '?' . $uri->query() );
                    $req->header('Content-Length', 0);
                } else {
                    my $data = $uri->query();
                    $req->content_type('application/x-www-form-urlencoded');
                    $req->content($data);
                    $req->header('Content-Length', length($data));
                }
            }
        }
    } else{
        $req->header('Content-Length', 0);
    }

    my $res = $ua->request($req);

    if ($res->is_success()) {
        use Data::Dumper;
        EBox::debug("XXX RESUKLTL:" . Dumper($res));
        return new EBox::RESTClient::Result($res);
    }
    else {
        EBox::debug("XXX NOT SUCCESS");
        $self->{last_error} = new EBox::RESTClient::Result($res);
        given ($res->code()) {
            when (HTTP_UNAUTHORIZED) {
                throw EBox::Exceptions::External($self->_invalidCredentialsMsg());
            }
            when (HTTP_BAD_REQUEST) {
                my $error = $self->last_error()->data();
                my $msgError = $error;
                if (ref($error) eq 'HASH') {
                    # Flatten the arrays
                    my @errors;
                    foreach my $singleErrors (values %{$error}) {
                        push(@errors, @{$singleErrors});
                    }
                    $msgError = join("\n", @errors);
                }
                throw EBox::Exceptions::External($msgError);
            }
            default {
                # Add to the journal unless specified not to do so
                if ($retry) {
                    $self->_storeInJournal($method, $path, $query, $res);
                }
                use Data::Dumper;
                EBox::debug("RES " . Dumper($res));
                EBox::debug("content " . $res->content());
                throw EBox::Exceptions::Internal($res->code() . " : "
                . $res->content()); 
                
            }
        }

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

# Method: JournalOpsDirPath
#
#      Return the directory path for the REST operations that cannot
#      be completed
#
#      If the directory does not exist, then create it
#
# Returns:
#
#      String - the journal ops dir path
#
sub JournalOpsDirPath
{
    my $dir = JOURNAL_OPS_DIR;

    unless ( -d $dir ) {
        mkdir($dir, 0700);
    }
    return $dir;
}

# Group: Protected methods

# Function: _invalidCredentialsMsg
#
#     Return the invalid credentials message
#
# Returns:
#
#     String - the message
#
sub _invalidCredentialsMsg
{
    return __x('User and password do not match.');
}

# Group: Private methods

# Store the op in the journal
sub _storeInJournal
{
    my ($self, $method, $path, $query, $res) = @_;

    my $journalDir = $self->JournalOpsDirPath();
    my $time = join('', Time::HiRes::gettimeofday());
    my $tmpFile = new File::Temp(TEMPLATE => "$time-XXXX", DIR => $journalDir,
                                 UNLINK => 0);

    my $encoder = new JSON::XS()->utf8()->allow_blessed(1)->convert_blessed(1);
    my $action = {
        'uri'         => $self->{uri}->as_string(),
        'credentials' => $self->{credentials},
        'method'      => $method,
        'path'        => $path,
        'query'       => $query,
        'res_code'    => $res->code(),
        'res_content' => $res->decoded_content()
    };
    print $tmpFile $encoder->encode($action);
}

1;
