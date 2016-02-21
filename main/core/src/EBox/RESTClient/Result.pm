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

package EBox::RESTClient::Result;

# Class: EBox::RESTClient::Result
#
#   Result from a REST query
#

use EBox;
use EBox::Exceptions::MissingArgument;
use TryCatch;
use JSON::XS;

# Constructor: new
#
#   Create the REST result
#
# Parameters:
#
#   result - <HTTP::Result>
#
sub new
{
    my ($class, $result) = @_;

    throw EBox::Exceptions::MissingArgument('result') unless (defined($result));

    my $self = {
        result => $result
    };

    return bless($self, $class);
}

# Method: as_string
#
#   Return the result as string
#
sub as_string
{
    my ($self) = @_;
    my $value = $self->{result}->decoded_content();
    utf8::decode($value);
    return $value;
}

sub rawContent
{
    my ($self) = @_;
    return $self->{result}->content();
}

# Method: data
#
#   Return the result as array or hash ref (it expects a JSON response)
#
sub data
{
    my ($self) = @_;
    unless ($self->{result_json}) {
        $self->{result_json} = decode_json($self->{result}->decoded_content());
    }
    return $self->{result_json};
}

sub code
{
    my ($self) = @_;
    return $self->{result}->code();
}

1;

