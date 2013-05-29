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

# Class: EBox::Types::URI
#
#      A specialised text type to represent an Uniform Resource
#      Identifiers (URIs)
#
package EBox::Types::URI;

use strict;
use warnings;

use base 'EBox::Types::Text';

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::Gettext;

# Dependencies
use Perl6::Junction qw(any);
use URI;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::URI>
#
# Returns:
#
#      the recently created <EBox::Types::URI> object
#
sub new
{
    my $class = shift;
    my %params = @_;
    my $self = $class->SUPER::new(
            @_,
            );
    $self->{'type'} = 'uri';
    if ( $params{validSchemes} ) {
        if ( ref($params{validSchemes}) eq 'ARRAY' ) {
            $self->{'validSchemes'} = $params{validSchemes};
        } else {
            throw EBox::Exceptions::InvalidType('validSchemes',
                                                'ARRAY');
        }
    }
    bless($self, $class);
    return $self;
}

# Method: uri
#
#     Get the <URI> object from this type
#
# Returns:
#
#     <URI> - the object
#
sub uri
{
    my ($self) = @_;

    return new URI($self->value());
}

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct URI
#
# Overrides:
#
#     <EBox::Types::Text::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is either a correct URI
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       URI
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ( $value )) {
        my $uri = new URI($value);
        # FIXME: We can use Data::Validate::URI,
        unless ( defined($uri->scheme()) and length($uri->scheme())
                   and defined($uri->path())) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(), value => $value,
                advice => __('URI usually follows the format scheme://authority/path'));
        }
        if ( $self->{validSchemes} ) {
            # Check against valid schemes
            unless ( $uri->scheme() eq any(@{$self->{validSchemes}}) ) {
                throw EBox::Exceptions::InvalidData(
                    data => $self->printableName(), value => $value,
                    advice => __x('Scheme should be one of: {schemes}, not {scheme}',
                                   schemes => join(', ', @{$self->{validSchemes}}),
                                   scheme  => $uri->scheme()));
            }
        }
    }
    return 1;
}

1;
