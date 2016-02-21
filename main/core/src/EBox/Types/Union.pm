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
#       * Optimize class. Use reference to fetch selected type
#         instead of transverse array.
#
#       * Support automatic unique check
#
use strict;
use warnings;

package EBox::Types::Union;

use base 'EBox::Types::Abstract';

use EBox;
use EBox::Exceptions::Internal;

# Dependencies
use Clone;
use Perl6::Junction qw(none);

# It's a package global
our $AUTOLOAD;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    $self->{'type'} = 'union';

    # Union type cannot be optional
    if ( $self->{'optional'} ) {
        EBox::warn('Union type cannot be optional. To use the non-defined ' .
                   'value, choose EBox::Types::Union::Text');
    }
    $self->{'optional'} = 0;

    # Union type must contain more than one subtype
    unless (@{$self->{'subtypes'}} > 1) {
        throw EBox::Exceptions::Internal("Union type: $self->{'fieldName'}"
                                         . " must contain more than one subtype");
    }

    bless($self, $class);
    return $self;
}

# Method: clone
#
# Overrides:
#
#       <EBox::Types::Abstract::clone>
#
sub clone
{
    my ($self) = @_;

    my $clonedType = {};
    bless($clonedType, ref($self));

    my @suspectedAttrs = qw(model row subtypes);
    foreach my $key (keys %{$self}) {
        if ( $key eq none(@suspectedAttrs) ) {
            $clonedType->{$key} = Clone::clone($self->{$key});
        }
    }
    # Just copy the reference
    foreach my $suspectedAttr (@suspectedAttrs[0 .. 1]) {
        if ( exists $self->{$suspectedAttr} ) {
            $clonedType->{$suspectedAttr} = $self->{$suspectedAttr};
        }
    }
    # Clone subtypes by calling its method clone
    foreach my $subtype (@{$self->subtypes()}) {
        push(@{$clonedType->{'subtypes'}}, $subtype->clone());
    }

    return $clonedType;
}

sub subtype
{
    my ($self) = @_;

    my $selected = $self->selectedType();

    foreach my $type (@{$self->{'subtypes'}}) {
        if ($type->fieldName() eq $selected) {
            return $type;
        }
    }

    return "";
}

# Method: selectedType
#
#       Get the selected type field name from the union. If the user
#       has not selected one explicitly, choose the first declared
#
# Returns:
#
#       String - the selected type field name
#
sub selectedType
{
    my ($self) = @_;

    if (not $self->{'selectedField'}) {
        my @subtypes = @{$self->{'subtypes'}};
        if (@subtypes > 0) {
            return $subtypes[0]->fieldName();
        } else {
            return undef;
        }
    } else {
        return $self->{'selectedField'};
    }

}

sub setSelectedType
{
    my ($self, $field) = @_;

    $self->{'selectedField'} = $field;
}

sub subtypes
{
    my ($self) = @_;

    return $self->{'subtypes'};
}

sub unique
{
    my ($self) = @_;

    my @subtypes = @{$self->{'subtypes'}};
    foreach my $subtype (@subtypes) {
        unless ( $subtype->unique() ) {
            return 0;
        }
    }

    return 1;
}

sub fields
{
    my ($self) = @_;

    my @fields;
    foreach my $type (@{$self->{'subtypes'}}) {
        push (@fields, $type->fields());

    }

    push (@fields, $self->fieldName() . '_selected');

    return @fields;
}

sub setModel
{
    my ($self, $model) = @_;

    $self->SUPER::setModel($model);
    $AUTOLOAD = 'setModel';
    return $self->AUTOLOAD($model);
}

sub setRow
{
    my ($self, $row) = @_;

    $self->SUPER::setRow($row);
    # Call AUTOLOAD method in order not to repeat code
    $AUTOLOAD = 'setRow';
    return $self->AUTOLOAD($row);
}

sub paramExist
{
    my ($self, $params) = @_;

    my $selPar = $self->fieldName() . '_selected';
    my $selected = $params->{$selPar};

    if ( (not defined ( $selected )) and
         $self->optional() ) {
        return 1;
    }

    return 0 unless (defined($selected));

    foreach my $type (@{$self->{'subtypes'}}) {
        next unless ($type->fieldName() eq $selected);
        # If type has no setter, parameter is not required anyway
        return 1 unless( $type->HTMLSetter() );
        return $type->paramExist($params);
    }

    return 0;
}

# Method: trailingText
#
#    Overrides to show the trailing text from the selected subtype
#
# Overrides:
#
#    <EBox::Types::Abstract::trailingText>
#
sub trailingText
{
    my ($self) = @_;

    my $trailing = $self->SUPER::trailingText();
    unless ( $trailing ) {
        $AUTOLOAD = 'trailingText';
        $trailing = $self->AUTOLOAD();
    }
    return $trailing;
}

sub printableValue
{
    my ($self) = @_;

      # Call AUTOLOAD method in order not to repeat code
    $AUTOLOAD = 'printableValue';
    return $self->AUTOLOAD();
}

sub value
{
    my ($self) = @_;

    # Call AUTOLOAD method in order not to repeat code
    $AUTOLOAD = 'value';
    return $self->AUTOLOAD();
}

sub memValue
{

}

sub compareToHash
{

}

# Method: isEqualTo
#
# Overrides:
#
#   <EBox::Types::Abstract::isEqualTo>
#
sub isEqualTo
{
    my ($self, $newObject) = @_;
    my $comparison = $self->cmp($newObject);
    if ( defined($comparison) ) {
        return $comparison == 0;
    } else {
        return 0;
    }
}

# Method: HTMLSetter
#
#      Set the mason template to set the value for the type.
#
#      It returns undef when all subtypes within has no setter.
#
# Overrides:
#
#      <EBox::Types::Abstract::HTMLSetter>
#
# Returns:
#
#      String - the path to the mason template which contains the code
#      to set the value for this type
#      undef  - if all subtypes have no setter
#
sub HTMLSetter
{
    my ($self) = @_;

    return undef if $self->{'hiddenOnSetter'} or $self->{'hidden'};

    my $definedSetter = 0;
    foreach my $type (@{$self->{'subtypes'}}) {
        next unless ( defined ( $type->HTMLSetter() ));
        $definedSetter = 1;
        last;
    }

    if ( $definedSetter ) {
        return '/ajax/setter/unionSetter.mas';
    } else {
        return undef;
    }
}

sub HTMLViewer
{
    my ($self) = @_;

    return undef if $self->{'hiddenOnViewer'} or $self->{'hidden'};

    # Call AUTOLOAD method in order not to repeat code
    $AUTOLOAD = 'HTMLViewer';
    return $self->AUTOLOAD();
}

# Function: AUTOLOAD
#
#      Special function called when an undefined method is called
#      within this package. The method name is stored at $AUTOLOAD
#      global variable.
#
#      Known subclass methods: HTMLViewer, linkToView
#
# Parameters:
#
#      self - <EBox::Types::Union> the object
#
#      parameters - Array containing the remainder parameters got from the
#      method call
#
sub AUTOLOAD
{
    my ($self, @params) = @_;
    my $methodName = $AUTOLOAD;

    # Remove namespaces
    $methodName =~ s/.*:://;

    # Ignore DESTROY callings (the Perl destructor)
    if ( $methodName eq 'DESTROY' ) {
        return;
    }

    # setRow and setModel must be run for all subtypes
    if ($methodName eq 'setRow' or $methodName eq 'setModel') {
        foreach my $subtype (@{$self->{'subtypes'}}) {
            $subtype->$methodName(@params);
        }
    }

    # Call the method from the selected type
    my $selected = $self->selectedType();

    unless ( defined ( $selected )) {
        throw EBox::Exceptions::Internal('There is no selected type ' .
                                         "to call its own method $methodName");
    }

    foreach my $subtype (@{$self->{'subtypes'}}) {
        next unless ($subtype->fieldName() eq $selected);
        # Check if the method is defined
        if ( $subtype->can($methodName)) {
            return $subtype->$methodName(@params);
        } else {
            throw EBox::Exceptions::Internal("Method $methodName is not defined " .
                                             'in type ' . $subtype->type());
        }
    }
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

    my $selPar = $self->fieldName() . '_selected';
    my $selected = $params->{$selPar};

    if (defined ($selected)) {
        foreach my $type (@{$self->{'subtypes'}}) {
            if ($type->fieldName() eq $selected) {
                $type->setMemValue($params);
                $self->setSelectedType($selected);
            }
        }
    }
}

# Method: _storeInHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInHash>
#
sub _storeInHash
{
    my ($self, $hash) = @_;

    my $selected = $self->selectedType();

    foreach my $type (@{$self->{'subtypes'}}) {
        # Every union type should be stored in order to unset its
        # value if it has not got one
        $type->storeInHash($hash);
        if ($type->fieldName() eq $selected) {
              my $selected = $self->fieldName() . '_selected';
              $hash->{$selected} = $self->selectedType();
          }
    }
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

    return unless ($self->row());

    my $selPar = $self->fieldName() . '_selected';
    my $selected = $hash->{$selPar};

    return unless (defined($selected));

    foreach my $type (@{$self->{'subtypes'}}) {
        next unless ($type->fieldName() eq $selected);
        $type->restoreFromHash($hash);
        $self->setSelectedType($selected);
    }
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    my $selPar = $self->fieldName() . '_selected';
    my $selected = $params->{$selPar};

    unless ( defined ( $selected )) {
        return 0;
    }

    foreach my $type (@{$self->{'subtypes'}}) {
        next unless ($type->fieldName() eq $selected);
        # If type has no setter, parameter is not required anyway
          return 1 unless( $type->HTMLSetter() );
        return $type->_paramIsSet($params);
    }

    return 0;
}

# Method: _setValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setValue>
#
sub _setValue
{
    my ($self, $value) = @_;

    my ($selectedField, $selectedValue) = each ( %{$value} );

    $self->setSelectedType( $selectedField );

    # Call AUTOLOAD method in order not to repeat code
    $AUTOLOAD = '_setValue';
    return $self->AUTOLOAD($selectedValue);
}

# Method: cmp
#
# Overrides:
#
#      <EBox::Types::Abstract::cmp>
#
# Returns:
#
#      -1 - if all simpler types from self are lower than compareType
#
#       0 - if all simpler types from self are equal to compareType
#
#       1 - if all simpler types from self are higher than compareType
#
#       undef - otherwise
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }

    my $selfSelected = $self->subtype();
    my $compareSelected = $compareType->subtype();

    return $selfSelected->cmp($compareSelected);
}

1;
