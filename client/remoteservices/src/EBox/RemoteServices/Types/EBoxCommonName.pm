# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::RemoteServices::Types::EBoxCommonName;
use base 'EBox::Types::Text';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate;

# Constants
use constant {
    MAX_LENGTH => 32,
};

# Constructor: new
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);

    bless($self, $class);
    return $self;
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Text::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};
    my $advice = '';
    # Check if this does not contain underscores neither dots
    unless ( EBox::Validate::checkDomainName($value) ) {
        $advice = __('It must be a valid subdomain name');
    } elsif ( $value =~ m/\./g ) {
        $advice = __x('It cannot contain "{char}" character',
                      char => '.');
    } elsif ( length($value) >= MAX_LENGTH ) {
        $advice = __x('It cannot be greater than {n} characters',
                      n => MAX_LENGTH);
    }

    if ( $advice ne '' ) {
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice => $advice);
    }

}

1;
