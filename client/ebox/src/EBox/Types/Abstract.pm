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

# TODO 
# 	Document this class
#	Fix the method naming, some names such as
#	setMemValue and memValue are so broken!!!
#

# Class: EBox::Types::Abstract
#
#      It is the parent type where the remainder types overrides from.
#

package EBox::Types::Abstract;

use strict;
use warnings;

use EBox;

# Group: Public methods

sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = {@_};

	if (defined($self->{'hidden'}) and $self->{'hidden'}) {
		$self->{'HTMLViewer'} = undef;
		$self->{'HTMLSetter'} = undef;
	}
        bless($self, $class);

        if ( defined ( $self->{'defaultValue'} )) {
            if ( $self->optional() ) {
                EBox::warn('Defined default value to an optional field ' .
                           $self->fieldName());
            } else {
                $self->_setDefaultValue($self->{'defaultValue'});
            }
        }

        return $self;
}


sub type
{
	my ($self) = @_;

	return $self->{'type'};

}

sub class
{
	my ($self) = @_;

	return $self->{'class'};
}

# Method: volatile
#
#     A type is volatile when its value or printable value is
#     calculated in runtime. This value is obtained from the
#     <EBox::Types::Abstract::filter> method. Thus if this attribute
#     is set, the filter attribute should be defined, otherwise an
#     identity will be applied
#
# Returns:
#
#     boolean - whether the type is volatile or not
#
sub volatile
  {

      my ($self) = @_;

      return $self->{volatile};

  }

sub unique
{
	my ($self) = @_;

	return $self->{'unique'};
}

# Method: editable
#
#      A type is editable when it is possible to change its value by
#      the user. If the type is volatile, the type cannot be editable.
#
# Returns:
#
#      boolean - showing whether the type is editable or not
#
sub editable
{
	my ($self) = @_;

        if ( $self->volatile() ) {
            return 0;
        } else {
            return $self->{'editable'};
        }

}

sub fieldName
{
	my ($self) = @_;

	return $self->{'fieldName'};
}

sub fields
{
	my ($self) = @_;

	return ($self->fieldName());
}

sub printableName
{
	my ($self) = @_;

	return $self->{'printableName'};
}

sub printableValue
{
	my ($self) = @_;

	return $self->filter();
}

# Method: filter
#
# 	This method is used to filter the output of printableValue
#
# Returns:
#	
#	Output filtered
sub filter
{
	my ($self) = @_;

	my $filterFunc = $self->{'filter'};
	if ($filterFunc) {
		return (&$filterFunc($self));
	} else {
		return $self->{'value'};
	}

}


sub value
{
	my ($self) = @_;

	return $self->{'value'};
}

# Method: defaultValue
#
#     Accessor to the default value if any
#
# Returns:
#
#     The default value
#
sub defaultValue
  {

      my ($self) = @_;

      return $self->{'defaultValue'};

  }

sub trailingText
{
	my ($self) = @_;

	return $self->{'trailingText'};
}

sub leadingText
{
	my ($self) = @_;

	return $self->{'leadingText'};
}

sub setOptional # (optional)
  {

    my ($self, $optional) = @_;

    $self->{'optional'} = $optional;

  }

sub optional
{
	my ($self) = @_;

	return $self->{'optional'};
}

sub paramExist
{

}


# Method: storeInGConf
#
#      Store the given type in a GConf directory from a
#      GConfModule. If the type is volatile, nothing will be done.
#
# Parameters:
#
#      gconfmodule - <EBox::GConfModule> the module which is in charge
#      to store the type in GConf
#
#      directory - String the directory where the type will be stored
#      from
#
sub storeInGConf
  {
      my ($self, @params) = @_;

      unless ( $self->volatile() ) {
          $self->_storeInGConf(@params);
      }

  }

sub restoreFromGconf
{

}

# Method: setMemValue
#
#      Set the memory value for the type. If the type is volatile, no
#      value is set
#
# Parameters:
#
#      params - hash ref with the fields to fill the type with its
#      appropiate values
#
sub setMemValue
{

    my ($self, $params) = @_;

    # Set the memory value only if persistent kind of type
    unless ( $self->volatile() ) {
        # Check if the parameters hasn't had an empty value
        if ( $self->_paramIsSet($params) ) {
            # Check if the parameter is valid
            $self->_paramIsValid($params);
            # Set finally the value
            $self->_setMemValue($params);
        } else {
            if ( $self->optional() ) {
                # Nothing to set in the type
                return;
            } else {
                throw EBox::Exceptions::MissingArgument( $self->printableName() );
            }
        }
    }

}

sub memValue
{

}

sub compareToHash
{

}

# Method: restoreFromHash
#
#      Restore the value from a hash.
#
#      If the type is volatile, the memory value will be set from the
#      <EBox::Types::Abstract::wangler>. If the function is empty, a
#      function which returns '' will be used.
#
# Parameters:
#
#      hash - hash ref which contains the data to fill the type value
#
#
sub restoreFromHash
  {

      my ($self, $hashRef) = @_;

      if ( $self->volatile() ) {
          my $volatileFunc = $self->{acquirer};
          $volatileFunc = \&_identity unless defined ( $volatileFunc );
          $self->{value} = &$volatileFunc($self);
      } else {
          $self->_restoreFromHash($hashRef);
      }

  }

# Method: acquirer
#
#      Get the function which obtains the value from somewhere instead
#      of GConf. This method is useful for volatile instances of
#      types.
#
# Parameters:
#
#      hash - hash ref which contains the row from a data table. This
#      information should be sufficient to set the value for that
#      instance
#
# Returns:
#
#      function - the pointer to that function
#
sub acquirer
  {

      my ($self) = @_;

      return $self->{acquirer};

  }

sub isEqualTo
{

}

# Method: row
#
#   Return the row to which this data belongs
#
# Returns:
#
#   row - hash ref containting a row
sub row
{
	my ($self) =  @_;
	return $self->{'row'};
}

# Method: setRow
#
#   Set the row identifier to which this data belongs
#
# Parameters:
#
#   (POSITIONAL)
#
#   row - hash ref of a row
sub setRow
{
	my ($self, $row) = @_;
	$self->{'row'} = $row;
}

# Method: setModel
#
#   Set the model to which this data belongs
#
# Parameters:
#
#   (POSITIONAL)
#
#   model -  an object of type <EBox::Model::DataTable>
sub setModel
{
	my ($self, $id) = @_;
	$self->{'model'} = $id;
}

# Method: model
#
#   Return the model to which this data belongs
#
# Returns:
#
#   model -  an object of type <EBox::Model::DataTable>
sub model
{
	my ($self) =  @_;
	return $self->{'model'};
}

sub HTMLSetter
{
    my ($self) = @_;

    return undef unless (exists $self->{'HTMLSetter'});
    return $self->{'HTMLSetter'};
}

sub HTMLViewer
{
    my ($self) = @_;

    return undef unless (exists $self->{'HTMLViewer'});
    return $self->{'HTMLViewer'};
}

# Group: Protected methods

# Method: _setMemValue
#
#       Set the memory value for the type. It is assured that this
#       method will be called if only there is something to fill the
#       type and its content is valid. This method should be
#       overridden from non volatile types.
#
# Parameters:
#
#       params - hash ref with the fields to fill the type with its
#       appropiate values
sub _setMemValue
  {

  }

# Method: _storeInGConf
#
#      Store the given type in a GConf directory from a
#      GConfModule. The expected behaviour is if it has no value to
#      store, remove any previous data stored.
#
#      This method should be overridden from non volatile types.
#
# Parameters:
#
#      gconfmodule - <EBox::GConfModule> the module which is in charge
#      to store the type in GConf
#
#      directory - String the directory where the type will be stored
#      from
#
sub _storeInGConf
  {

  }


# Method: _restoreFromHash
#
#      Restore the type value from a hash reference. This method should be
#      overridden from non volatile types.
#
# Parameters:
#
#      hash - hash ref which has all the information required to set
#      the value from this type
#
sub _restoreFromHash
  {

  }

# Method: _paramIsValid
#
#      Check the correctness from the parameters passed. It assures
#      that it is something to be checked.
#
#      It should launch an exception when the parameter is not valid,
#      It should be overridden by the subclasses.
#
# Parameters:
#
#      params - hash ref which has all the information required to
#      check its correctness
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the parameters passed
#      does not contain a valid data for this type
#
sub _paramIsValid
  {

  }

# Method: _paramIsSet
#
#      Check if the given parameters contain the data needed to fill
#      the type, i.e. it exists and it is not empty. It should be
#      overridden by the subclasses
#
# Parameters:
#
#      params - hash ref which has all the information required to
#      check its emptyness
#
# Returns:
#
#      boolean - indicating if the parameters does not contain enough
#      data to fill the type
#
sub _paramIsSet
  {

      return 0;

  }

# Method: _setDefaultValue
#
#     Set the default value. To be overridden by subclasses which
#     allows default values
#
# Parameters:
#
#     defaultValue - the default value to set
#
sub _setDefaultValue # (defaultValue)
  {

      return;

  }

# Group: Private functions

# Function: _identity
#
#      Identity function in order to set the value from hash ref
#
# Parameters:
#
#      instancedType - <EBox::Types::Abstract>
#
sub _identity
  {

      return '';

  }

1;
