# Copyright (C) 2011-2013 Zentyal S.L.
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

#   Class: EBox::Types::HTML
#
#       This class represents a type which contains raw HTML
#
use strict;
use warnings;

package EBox::Types::HTML;

use base 'EBox::Types::Text';

use EBox::Exceptions::InvalidData;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Create the type
#
# Returns:
#
#      <EBox::Types::HTML> - the newly created type
#
sub new
{
    my ($class, %opts) = @_;

    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/rawHTML.mas';
    }

    $opts{'type'}     = 'html';
    $opts{'editable'} = 0;

    my $self = $class->SUPER::new(%opts);

    bless ( $self, $class );

    unless (exists $opts{'HTMLSetter'}) {
        $self->{'HTMLSetter'} = '/ajax/viewer/rawHTML.mas';
    }

    return $self;
}

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct HTML string
#
# Overrides:
#
#    <EBox::Types::Abstract::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct HTML string
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#     HTML string
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if ( defined ( $value )) {
        # The test is quite de risa
        unless ( $value =~ m:^<.*>$: ) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->fieldName(),
                value  => $value,
                advice => __('It must be a valid HTML string')
               );
        }
    }

    return 1;
}

1;
