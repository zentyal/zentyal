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

package EBox::Types::Basic;
use strict;
use warnings;

use base 'EBox::Types::Abstract';

use EBox::Exceptions::MissingArgument;

# Group: Public methods

sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);
        bless($self, $class);

	# Setting as non-optional, if no optional value is passed
	if ( not defined ( $self->optional() ) ) {
	  $self->setOptional(0);
	}

        return $self;
}

sub paramExist
{
	my ($self, $params, $field) = @_;

	return (defined($params->{$self->fieldName()}));

}

sub memValue
{
	my ($self) = @_;

	return $self->{'value'};
}

sub compareToHash
{
	my ($self, $hash) = @_;

        if ( defined ( $hash->{$self->fieldName()} )
           and defined ( $self->memValue() )) {
            return ($self->memValue() eq $hash->{$self->fieldName()});
        } else {
            return 0;
        }
}

sub isEqualTo
{
	my ($self, $newObject) = @_;

	my $oldValue = $self->{'value'};
	my $newValue = $newObject->memValue();

        # A great dilemma
        if ( not defined ( $oldValue ) and
             not defined ( $newValue )) {
            return 1;
        }

	if ( not defined ( $oldValue ) or
	     not defined ( $newValue )) {
	  return 0;
	}

	return ($oldValue eq $newValue);
}

# Group: Protected methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
{
	my ($self, $params) = @_;

	$self->{'value'} = $params->{$self->fieldName()};
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
	my ($self, $hash) = @_;

	$self->{'value'} = $hash->{$self->fieldName()};
}

# Method: _setValue
#
#     Set the value if any
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - the basic value to pass
#
sub _setValue # (value)
  {

      my ($self, $value) = @_;

      my $params = {
                    $self->fieldName() => $value,
                   };

      $self->setMemValue($params);

  }

1;
