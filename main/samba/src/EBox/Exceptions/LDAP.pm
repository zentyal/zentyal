# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Exceptions::LDAP;

use base 'EBox::Exceptions::Internal';

use Data::Dumper;
use EBox::Exceptions::MissingArgument;

# Constructor:  new
#
#  Parameters:
#     result - Net::LDAP::Message with the response of the failed operation
#     message - Custom message to prepend to the error description (optional)
#     opArgs - Arguments of the faield LDAP operation (optional)
#
sub new
{
    my ($class, %args) = @_;
    my $result = $args{result};
    if (not $result) {
        throw EBox::Exceptions::MissingArgument('result');
    }
    my $message = $args{message};
    my $opArgs  = $args{opArgs};

    my $exText;
    if ($message) {
        $exText = $message . ' ';
    } else {
        $exText = 'LDAP error: ';
    }
    $exText .= $result->error_text;
    if ($opArgs) {
        $exText .= ".<br/> Operation parameters:";
        local $Data::Dumper::Terse = 1;
        $exText .= Dumper($opArgs);
    }

    local $Error::Depth = $Error::Depth ? $Error::Depth + 1 : 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    my $self = $class->SUPER::new($exText);
    $Log::Log4perl::caller_depth--;

    $self->{result} = $result;
    bless $self, $class;
    return $self;
}

# Method: error
#
#   Returns the error message in the result message from the server
#
sub error
{
    my ($self) = @_;

    return $self->{result}->error();
}

# Method: errorName
#
#  Returns:
#     the LDAP error name
sub errorName
{
    my ($self) = @_;

    return $self->{result}->error_name();
}

# Method: errorText
#
#   Returns the short text description of the error code in the result message
#   from the server
#
sub errorText
{
    my ($self) = @_;

    return $self->{result}->error_text();
}

# Method: errorDescription
#
#   Returns a long text description of the error code in the result message
#   from the server
#
sub errorDescription
{
    my ($self) = @_;

    return $self->{result}->error_desc();
}

1;
