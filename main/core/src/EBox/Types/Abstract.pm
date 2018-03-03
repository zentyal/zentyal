# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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
#       Document this class
#       Fix the method naming, some names such as
#       setMemValue and memValue are so broken!!!
#

# Class: EBox::Types::Abstract
#
#      It is the parent type where the remainder types overrides from.
#

use strict;
use warnings;

package EBox::Types::Abstract;

use EBox;

use Clone;
use Scalar::Util 'weaken';
use File::Basename;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = {@_};

    if (not $self->{fieldName}) {
        throw EBox::Exceptions::MissingArgument('fieldName');
    }

    if (not $self->{printableName}) {
        $self->{printableName} = undef;
    }

    bless($self, $class);

    if ( defined ( $self->defaultValue() )) {
        if ( $self->optional() ) {
            throw EBox::Exceptions::Internal(
             'Defined default value to an optional field ' . $self->fieldName()
                                            );
        }
        $self->_setValue($self->defaultValue());
    }

    return $self;
}

# Method: clone
#
#     Clone the current type safely
#
# Returns:
#
#     <EBox::Types::Abstract> - the cloned object
#
sub clone
{
    my ($self) = @_;

    my $clonedType = {};
    bless($clonedType, ref($self));

    my @suspectedAttrs = qw(model row);
    foreach my $key (keys %{$self}) {
        if ($key ne 'model' and $key ne 'row') {
            $clonedType->{$key} = Clone::clone($self->{$key});
        }
    }
    # Just copy the reference
    foreach my $suspectedAttr (@suspectedAttrs) {
        if ( exists $self->{$suspectedAttr} ) {
            $clonedType->{$suspectedAttr} = $self->{$suspectedAttr};
        }
    }
    return $clonedType;
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
#      the user. If the type is volatile, the type cannot be editable
#      unless a <EBox::Types::Abstract::storer> was defined.
#
# Returns:
#
#      boolean - showing whether the type is editable or not
#
sub editable
{
    my ($self) = @_;

    if ($self->volatile() and not $self->storer()) {
        return 0;
    } elsif (ref $self->{'editable'} eq 'CODE') {
        my $editableFunc = $self->{editable};
        return &$editableFunc($self);
    } else {
        return $self->{'editable'};
    }
}

sub hidden
{
    my ($self) = @_;

    if (defined $self->{'hidden'} and ref $self->{'hidden'}) {
        my $hiddenFunc = $self->{'hidden'};
        return (&$hiddenFunc());

    } elsif (defined($self->{'hidden'})) {
        return $self->{'hidden'};
    }

    return 0;
}

sub fieldName
{
    my ($self) = @_;

    return $self->{'fieldName'};
}

sub fields
{
    my ($self) = @_;

    my $field = $self->fieldName();

    my @fields = @{$self->_attrs()};
    unless (@fields) {
        return ($field);
    }
    @fields = map { $field . '_' . $_ } @fields;

    return @fields;
}

sub section
{
    my ($self) = @_;
    return $self->{'section'};
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
#       This method is used to filter the output of printableValue
#
# Returns:
#
#       Output filtered
sub filter
{
    my ($self) = @_;

    my $filterFunc = $self->{'filter'};
    if ($filterFunc) {
        return (&$filterFunc($self));
    } else {
        return $self->value();
    }
}

# Method: value
#
#       Return the value for the type
#
sub value
{
    my ($self) = @_;
    if (not exists $self->{value}) {
        if ($self->volatile()) {
            return $self->_volatileValue();
        } else {
            return undef;
        }
    }

    return $self->{'value'};
}

# return run-time value for volatiles types
sub _volatileValue
{
    my ($self) = @_;
    my $volatileFunc = $self->{acquirer};
    $volatileFunc = \&_identity unless defined ($volatileFunc);
    return $volatileFunc->($self);
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

    my $value = $self->{defaultValue};

    # Check if it is a reference. It can be a function that returns the value
    if (ref ($value)) {
        $value = &$value();
    }

    return $value;
}

# Method: help
#
#   Method to retrieve the associated help to this type
#
# Returns:
#
#     string
#
sub help
{
    my ($self) = @_;

    if (defined($self->{help})) {
        return $self->{help};
    } else {
        return '';
    }
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

sub optionalLabel
{
    my ($self) = @_;

    return defined ($self->{'optionalLabel'}) ?  $self->{'optionalLabel'} :
                                                 $self->{'optional'};
}

# Method: disabled
#
#      An instanced type is disabled when it must appear to be
#      selectable on an union type but it is not selectable
#
# Returns:
#
#      boolean - indicating if the instanced type is disabled or not
#
sub disabled
{
    my ($self) = @_;

    return $self->{'disabled'};
}

# Method: allowUnsafeChars
#
#      Attribute to determine the value which contains this type
#      allows unsafe characters that may be used to inject malicious
#      code. This only makes sense on HTML-based values
#
# Returns:
#
#      boolean - indicating if the instanced type may store unsafe
#      characters or not
#
sub allowUnsafeChars
{

    my ($self) = @_;

    return $self->{'allowUnsafeChars'};
}

# Method: paramExist
#
#      *DEPRECATED*
sub paramExist
{

}

# Method: storeInHash
#
#      Store the given type in a GConf directory from a
#      Module::Config. If the type is volatile, nothing will be done.
#
# Parameters:
#
#      module - <EBox::Module::Config> the module which is in charge
#      to store the type in GConf
#
#      key - String of the key where the type will be stored
#
sub storeInHash
{
    my ($self, $hash) = @_;

    if ($self->volatile()) {
        if ($self->storer()) {
            my $storerProc = $self->storer();
            &$storerProc($self, $hash);
        }
    } else {
        $self->_storeInHash($hash);
    }
}

# Method: setValue
#
#      Set the value for the type. Its behaviour is equal to
#      <EBox::Types::Abstract::setMemValue>, but the argument is a
#      single value to set to the type instead of a series of CGI
#      parameters.
#
#      The type is responsible to parse the value parameter to set
#      the type value appropiately.
#
#      If the type is volatile, no
#      value is set unless <EBox::Types::Abstract::storer> function is
#      defined.
#
# Parameters:
#
#      value - the value to set
#
sub setValue
{
    my ($self, $value) = @_;

    $self->_setValue($value);
}

# Method: setMemValue
#
#      Set the memory value for the type. If the type is volatile, no
#      value is set unless <EBox::Types::Abstract::storer> function is
#      defined
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
    my $toSet = $self->volatile() ? 0 : 1;
    $toSet = ($toSet or ($self->volatile() and (ref($self->storer()) eq 'CODE')));

    if ($toSet) {
        # Check if the parameters hasn't had an empty value
        if ($self->_paramIsSet($params)) {
            # Check if the parameter is valid
            $self->_paramIsValid($params);
            # Set finally the value
            $self->_setMemValue($params);
        } else {
            if ($self->optional()) {
                # set type to empty
                if ($self->memValue()) {
                    $self->_setMemValue($params);
                }
            } else {
                my $defaultValue = $self->defaultValue();
                if ($defaultValue) {
                    $self->_setValue($defaultValue);
                } else {
                    throw EBox::Exceptions::MissingArgument($self->printableName());
                }
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

# Method: cmp
#
#      Comparison among two types of the same type. Some types will
#      override the function, some others not as
#      <EBox::Types::HasMany>
#
#      Its behaviour is equal to cmp function per string. The
#      comparison should be done only if the types are equal
#
# Parameters:
#
#      compareType - <EBox::Types::Abstract> the type to compare with
#
# Returns:
#
#      -1 - if self is lower than compareType
#
#       0 - if both are equal
#
#       1 - if self is higher than compareType
#
#       undef - otherwise (not equal types)
#
sub cmp
{
}

# Method: restoreFromHash
#
#      Restore the value from a hash.
#
#      If the type is volatile, the memory value will be set from the
#      <EBox::Types::Abstract::acquirer>. If the function is empty, a
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

    if ($self->volatile()) {
        $self->{value} = $self->_volatileValue();
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

# Method: storer
#
#      Get the procedure which stores the value to somewhere
#      instead of default backend. This method is useful for volatile instances
#      of types.
#
#      The procedure has one argument: the type itself
#
# Returns:
#
#      function - the pointer to that function
#
sub storer
{
    my ($self) = @_;

    return $self->{storer};
}

# Method: isEqualTo
#
#  returns if a type object is equal to another
#  default implementation uses the cmp method
#  soon to be deprecated.
sub isEqualTo
{
    my ($self, $other) = @_;
    my $cmp = $self->cmp($other);
    return (defined $cmp and $cmp == 0);
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
    weaken($self->{'row'});
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
    weaken($self->{'model'});
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

    return undef if ($self->hidden());
    if (defined($self->{'hiddenOnSetter'}) and $self->{'hiddenOnSetter'}) {
        return undef;
    }

    return undef unless (exists $self->{'HTMLSetter'});
    return $self->{'HTMLSetter'};
}

sub HTMLViewer
{
    my ($self) = @_;

    return undef if ($self->hidden());
    if (defined($self->{'hiddenOnViewer'}) and $self->{'hiddenOnViewer'}) {
        return undef;
    }
    return undef unless (exists $self->{'HTMLViewer'});
    return $self->{'HTMLViewer'};
}

sub typeRowLayout
{
    my ($self) = @_;

    return '/ajax/typeRowLayout.mas' unless (exists $self->{'typeRowLayout'});
    return $self->{'typeRowLayout'};
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
#
sub _setMemValue
{
    my ($self, $params) = @_;

    my @attrs = @{$self->_attrs()};
    return unless @attrs;

    my $field = $self->fieldName();

    foreach my $attr (@attrs) {
        $self->{$attr} = $params->{"${field}_$attr"};
    }
}

# Method: _storeInHash
#
#      Store this type in the given row hash
#
# Parameters:
#
#      hash - reference to row hash
#
sub _storeInHash
{
    my ($self, $hash) = @_;

    my @attrs = @{$self->_attrs()};
    return unless @attrs;

    my $field = $self->fieldName();
    foreach my $attr (@attrs) {
        my $full_attr = "${field}_$attr";
        if ($self->{$attr}) {
            $hash->{$full_attr} = $self->{$attr};
        } else {
            delete $hash->{$full_attr};
        }
    }
}

# Method: _attrs
#
#      This should be overriden by complex types which store more than
#      one value, so _restoreFromHash doesn't need to be implemented
#
sub _attrs
{
    return [];
}

# Method: _restoreFromHash
#
#      Restore the type value from a hash reference.
#      This method should be overridden from non volatile types.
#
# Parameters:
#
#      hash - hash ref which has all the information required to set
#      the value from this type
#
sub _restoreFromHash
{
    my ($self, $hash) = @_;

    my @attrs = @{$self->_attrs()};
    return unless @attrs;

    my $row = $self->row();
    return unless ($row);

    my $field = $self->fieldName();
    for my $attr (@attrs) {
        $self->{$attr} = $hash->{"${field}_${attr}"};
    }
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

# Method: _setValue
#
#     Set the value. To be overridden by subclasses which
#     allows values
#
# Parameters:
#
#     values - the value to set
#
sub _setValue # (value)
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

sub DESTROY
{
    my ($self) = @_;
    $self->{model} = undef;
    $self->{row} = undef;
}

1;
