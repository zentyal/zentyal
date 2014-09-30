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


use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use TryCatch::Lite;

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
    return $res->data();
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
    return $res->data();
}

# Method: get
#
#      Download a configuration backup.
#
#      TODO: Handle large sizes and digest.
#
# Parameters:
#
#      uuid - String the backup identifier
#
# Returns:
#
#      String - the raw backup content
#
sub get
{
    my ($self, $id) = @_;
    my $url = "/v2/confbackup/get/$id/";
    my $res = $self->restClientWithServerCredentials()->GET($url);
    return $res->rawContent();
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
