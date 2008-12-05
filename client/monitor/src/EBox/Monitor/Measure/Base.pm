# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Monitor::Measure::Base
#
#     This is a base class to measure different values of stuff
#

package EBox::Monitor::Measure::Base;

use strict;
use warnings;

use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

# Constants
use constant TYPES => qw(int percentage byte grade);

# Constructor: new
#
sub new
{
    my ($class, @params) = @_;

    my $self = { @params };
    bless($self, $class);

    $self->_setDescription($self->_description());

    return $self;
}


# Group: Protected methods

# Method: _description
#
#      Give the description for the measure
#
# Returns:
#
#      hash ref - the measure description containing the following
#      elements:
#
#         name - String the measure's name *(Optional)* Default value:
#         class name
#
#         printableName - String the measure's localisated name
#         +(Optional)* Default value: empty string
#
#         help - String the localisated help which may give an
#         explanation about the measure and measurement
#         *(Optional)*
#
#         dataset - array ref the data name for each CDP (consolidated
#         data point) *(Optional)* Default value: [ 'value' ]
#
#         rrds - array ref the path to the RRD files where it is
#         stored this measure
#
#         type - String the measure's gauge type. Possible values:
#         int, grade, percentage and byte
#         *(Optional)* Default value: 'int'
#
#
sub _description
{
    return {};
}

# Group: Private methods

# Method: _setDescription
#
#      Check the measure description and stores the attributes in the
#      measure base instance
#
# Parameters:
#
#      description - hash ref the description to check and set
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - thrown if any attribute has
#      not correct type
#
#      <EBox::Exceptions::InvalidData> - thrown if any attribute has
#      not correct data
#
sub _setDescription
{
    my ($self, $description) = @_;

    $self->{name} = ref( $self );
    $self->{help} = exists($description->{help}) ? $description->{help} : '';
    $self->{printableName} =
      exists($description->{printableName}) ? $description->{printableName} : '';

    $self->{dataset} = [ 'value' ];
    if ( exists($description->{dataset}) ) {
        unless ( ref($description->{dataset}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{dataset}, 'array ref');
        }
        $self->{dataset} = $description->{dataset};
    }

    if ( exists($description->{rrds}) ) {
        unless ( ref($description->{rrds}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{rrds}, 'array ref');
        }
        $self->{rrds} = [];
        my $baseDir = EBox::Monitor->RRDBaseDirPath();
        foreach my $rrdPath (@{$description->{rrds}}) {
            if ( -f $rrdPath ) {
                push(@{$self->{rrds}}, $rrdPath);
            } else {
                throw EBox::Exceptions::Internal("RRD file $rrdPath does not exist");
            }
        }
    } else {
        throw EBox::Exceptions::MissingArgument('rrds');
    }

    $self->{type} = 'int';
    if ( exists($description->{type}) ) {
        if ( scalar(grep { $_ eq $description->{type} } TYPES) == 1 ) {
            $self->{type} = $description->{type};
        } else {
            throw EBox::Exceptions::InvalidData(
                data => 'type',
                value => $description->{type},
                advice => 'Use one of this types: ' . join(', ', TYPES)
               );
        }
    }

}

1;
