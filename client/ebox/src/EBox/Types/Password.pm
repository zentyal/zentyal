# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Types::Password;

# Class: EBox::Types::Password
#
#     Define the password type. This typical text type will not show
#     its value and it may have a minimum and a maximum length

use base 'EBox::Types::Text';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::InvalidData;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::MACAddr>
#
# Returns:
#
#      the recently created <EBox::Types::MACAddr> object
#
sub new
{
        my $class = shift;
    	my %opts = @_;

	unless (exists $opts{'HTMLSetter'}) {
		$opts{'HTMLSetter'} ='/ajax/setter/passwordSetter.mas';
	}
	unless (exists $opts{'HTMLViewer'}) {
		$opts{'HTMLViewer'} ='/ajax/viewer/passwordViewer.mas';
	}
	
        $opts{'type'} = 'password';
        my $self = $class->SUPER::new(%opts);

        $self->{'minLength'} = 0 unless defined ( $self->{'minLength'} );
        $self->{'maxLength'} = 0 unless defined ( $self->{'maxLength'} );
        bless($self, $class);
        return $self;
}

# Method: minLength
#
#      Get the minimum password length.
#
# Returns:
#
#      Int - the minimum length. 0 if no minimum length is not set
#
sub minLength
  {

      my ($self) = @_;

      return $self->{minLength};

  }

# Method: maxLength
#
#      Get the maximum password length.
#
# Returns:
#
#      Int - the maximum length. 0 if no maximum length is not set
#
sub maxLength
  {

      my ($self) = @_;

      return $self->{maxLength};

  }

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct password. Check its length to
#     be in the correct interval.
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
#     true - if the parameter is a password
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       password
#
sub _paramIsValid
{
	my ($self, $params) = @_;

	my $value = $params->{$self->fieldName()};

	if (defined ( $value )) {
            if ( $self->{'minLength'} != 0 ) {
                if ( length ( $value ) < $self->{'minLength'} ) {
                    throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                                         value  => '****',
                                                         advice => __x('The password should have at ' .
                                                                      'least {minLength} characters',
                                                                       minLength => $self->{'minLength'})
                                                       );
                }
            }
            if ( $self->{'maxLength'} != 0 ) {
                if ( length ( $value ) > $self->{'maxLength'} ) {
                    throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                                         value  => '****',
                                                         advice => __x('The password should have at ' .
                                                                       'most {maxLength} characters',
                                                                       maxLength => $self->{'maxLength'})
                                                       );
                }
            }
	}

	return 1;

}


#  Method: cmp
#
#   This method is overrien because we cannot sort the passwords (do so would be
#   given away clues about their value) but we need to know where they are equal
#   or we wil lhave trouble
#
#  Overrides:
#  <EBox::Types::Text::cmp>
sub cmp 
{
    my ($self, $other) = @_;

    my $cmpRes = $self->SUPER::cmp($other);
    if (not defined $cmpRes ) {
        # no comparable case
        return undef;
    }
    elsif ($cmpRes == 0) {
        # equal case
        return 0;
    }

    # other cases we return 1 to have a non-content dependent order
    return 1;
}

1;
