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

package EBox::RemoteServices::ConfBackup;
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

sub list
{
    my ($self) = @_;
    my $res = $self->_restClientWithServerCredentials()->GET('/v2/confbackup/list/');
    return $res->data();
}

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
        ['Content-Disposition' => 'form-data; name="data"; filename="hello.o" Content-Type: application/x-object'],
        $data
       );

    my $res = $self->_restClientWithServerCredentials()->POST($url, multipart => \@parts);
    return $res->data();
}

sub get
{
    my ($self, $id) = @_;
    my $url = "/v2/confbackup/get/$id/";
    my $res = $self->_restClientWithServerCredentials()->GET($url);
    return $res->rawContent();
}

sub delete
{
    my ($self, $id) = @_;
    my $url = "/v2/confbackup/delete/$id/";
    $self->_restClientWithServerCredentials()->POST($url);
}



1;
