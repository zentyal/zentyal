# Copyright (C) 2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::RemoteServices::RESTResource::ConfBackup;
use base 'EBox::RemoteServices::RESTResource';

no warnings 'experimental::smartmatch';
use v5.10;

use Digest::MD5 qw(md5_hex);
use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use HTTP::Request;
use HTTP::Status;
use LWP::UserAgent;
use TryCatch::Lite;
use Date::Calc;
use URI;

# Group: Public methods

# Constructor: new
#
#     Create the subscription client object
#
# Parameters:
#
#     - remoteservices (named)
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless $self, $class;
    return $self;
}

# Method: list
#
#     List the available configuration backups
#
# Returns:
#
#     Array ref - with hash refs the following keys:
#
#        automatic - Boolean if the backup is automatic
#        uuid      - String the Backup Universal Unique identifier
#        label     - String the backup description
#        size      - Integer the size in bytes
#        backup_date - String the backup date using YYYY-MM-DD HH:MM:SS format
#        server    - Hash ref with name and uuid as keys
#        md5sum    - String the backup's hash using MD5 algorithm
#        company   - Hash ref with name, uuid and description as keys
#
sub list
{
    my ($self) = @_;

    my $res = $self->restClientWithServerCredentials()->GET('/v2/confbackup/list/');
    my @backups = @{ $res->data() };
    # change GMT time to localtime
    foreach my $backup (@backups) {
        my ($date_portion, $time_portion) = split ' ', $backup->{backup_date}, 2;
        my ($hour, $min, $sec)   = split ':', $time_portion, 3;
        my ($year, $month, $day) = split '-', $date_portion, 3;

        my $ts = Date::Calc::Date_to_Time($year,$month,$day, $hour,$min,$sec);

        ($year, $month, $day, $hour, $min, $sec) = Date::Calc::Localtime($ts);

        my $dateWithTs = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year, $month, $day, $hour, $min, $sec);
        $backup->{backup_date} = $dateWithTs;
    }

    return \@backups;
}

# Method: add
#
#      Upload a new configuration backup.
#
#      TODO: Handle large sizes and digest.
#
# Named parameters:
#
#      automatic - Boolean indicating if the backup is automatic or not
#
#      label - String the backup label
#
#      data  - String the file itself
#
# Returns:
#
#      Hash ref - containing the same keys that <list> returned element.
#
sub add
{
    my ($self, %params) = @_;
    my $url = '/v2/confbackup/add/';
    my $automatic = $params{automatic} ? 'True' : 'False';
    my $label     = $params{label};
    my $data      = $params{data};

    my @parts;
    push @parts, HTTP::Message->new(
        ['Content-Disposition' => 'form-data; name="automatic"' ],
        $automatic
       );
    push @parts, HTTP::Message->new(
        ['Content-Disposition' => 'form-data; name="label"' ],
        $label
       );
    push @parts, HTTP::Message->new(
        ['Content-Disposition' => 'form-data; name="data"; filename="backup.tar" Content-Type: application/x-object'],
        $data
       );

    my $res = $self->restClientWithServerCredentials()->POST($url, multipart => \@parts);
    my $checksum = $res->data()->{md5sum};
    if ($checksum) {
        my $digest = md5_hex($data);
        if ($checksum ne $digest) {
            throw EBox::Exceptions::InvalidData(data   => 'conf backup',
                                                value  => __('Configuration backup upload corrupted'),
                                                advice => __('Try the upload again'));
        }
    }
    return $res->data();
}

# Method: get
#
#      Download a configuration backup.
#
#
# Parameters:
#
#      uuid - String the backup identifier
#
#      fh - FileHandle if you want to download the file directly to a
#           file handle (Optional)
#
# Returns:
#
#      String - the raw backup content
#
sub get
{
    my ($self, $id, $fh) = @_;
    my $url = "/v2/confbackup/get/$id/";
    if (defined($fh)) {
        my $restClient = $self->restClientWithServerCredentials();
        my $url = new URI($restClient->{server} . $url);

        my $ua = new LWP::UserAgent();
        $ua->ssl_opts('verify_hostname' => EBox::Config::boolean('rest_verify_servers'));
        my $req = HTTP::Request->new(GET => $url->as_string());
        $req->authorization_basic($restClient->{credentials}->{username},
                                  $restClient->{credentials}->{password});

        my $res = $ua->request($req,
                               sub {
                                   my ($chunk, $res) = @_;
                                   print $fh $chunk;
                               });

        given($res->code()) {
            when (HTTP::Status::HTTP_NOT_FOUND) {
                throw EBox::Exceptions::Internal(__('Server not found'));
            }
            when (HTTP::Status::HTTP_NO_CONTENT) {
                throw EBox::Exceptions::DataNotFound(
                    data => __('Configuration backup'),
                    value => $id,
                   );
            } when (HTTP::Status::HTTP_BAD_REQUEST) {
                throw EBox::Exceptions::Internal('Bad request');
            } when (HTTP::Status::HTTP_INTERNAL_SERVER_ERROR) {
                throw EBox::Exceptions::Internal('Internal Server Error');
            } when (HTTP::Status::HTTP_FORBIDDEN) {
                throw EBox::Exceptions::Internal('Forbidden request');
            }
        }
        return undef;
    } else {
        my $res = $self->restClientWithServerCredentials()->GET($url);
        return $res->rawContent();
    }
}

# Method: delete
#
#      Delete a configuration backup.
#
# Parameters:
#
#      uuid - String the backup identifier
#
sub delete
{
    my ($self, $id) = @_;
    my $url = "/v2/confbackup/delete/$id/";
    $self->restClientWithServerCredentials()->POST($url);
}



1;
