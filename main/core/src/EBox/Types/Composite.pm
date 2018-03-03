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

# Class: EBox::Types::Composite
#
#       This type is a type composite which consists of other
#       types. This type is very useful as subtype in
#       <EBox::Types::Union>.
#
#       This type is useful in the following use case. You may require
#       to have 3 subtypes within a Union type and one of them is
#       complex, that is, it's comprised more than one type. For this
#       reason, Composite type is created.
#

use strict;
use warnings;

package EBox::Types::Composite;

use base 'EBox::Types::Abstract';

use EBox::Exceptions::Internal;

# Dependencies
use Clone;
use Perl6::Junction qw(none);

# Group: Public methods

# Constructor: new
#
#       The constructor for the type
#
# Returns:
#
#       <EBox::Types::Union::Text> - the union text recently created
#       object
#
sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/composite.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/composite.mas';
    }

    my $self = $class->SUPER::new(%opts);
    $self->{'type'} = 'composite';
    $self->{'types'} = $opts{'types'};
    if (not defined ( $self->{'types'})) {
        throw EBox::Exceptions::Internal('Composite types must have "types" attribute');
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

    my @suspectedAttrs = qw(model row types);
    foreach my $key (keys %{$self}) {
        if ( $key eq none(@suspectedAttrs) ) {
            $clonedType->{$key} = Clone::clone($self->{$key});
        }
    }
    # Just copy the reference to the suspected attributes
    foreach my $suspectedAttr (@suspectedAttrs[0 .. 1]) {
        if ( exists $self->{$suspectedAttr} ) {
            $clonedType->{$suspectedAttr} = $self->{$suspectedAttr};
        }
    }
    # Clone types by calling its method clone
    foreach my $subtype (@{$self->types()}) {
        push(@{$clonedType->{types}}, $subtype->clone());
    }

    return $clonedType;
}

# Method: fields
#
# Overrides:
#
#      <EBox::Types::Abstract::fields>
#
sub fields
{
    my ($self) = @_;

    my @fields;
    foreach my $simpleType (@{$self->types()}) {
        push ( @fields, $simpleType->fields() );
    }

    return @fields;
}

# Method: value
#
# Overrides:
#
#      <EBox::Types::Abstract::value>
#
# Returns:
#
#      hash ref - containing each value for each simple type indexed
#      by the field name
#
sub value
{
    my ($self) = @_;

    my %values;
    foreach my $simpleType (@{$self->types()}) {
      $values{$simpleType->fieldName()} = $simpleType->value();
    }
    return \%values;
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

    return undef unless ($self->type() eq $compareType->type());

    my @selfTypes = @{$self->types()};
    my @comparedTypes = @{$compareType->types()};

    return undef unless ( scalar(@selfTypes) == scalar(@comparedTypes) );
    my $returnValue = undef;
    for (my $idx = 0; $idx <= $#selfTypes; $idx++) {
        my $singleCmp = $selfTypes[$idx]->cmp($comparedTypes[$idx]);
        if (not defined($returnValue)) {
            $returnValue = $singleCmp;
        } else {
            return undef unless ($singleCmp == $returnValue);
        }
    }

    return $returnValue;
}

# Method: types
#
#     Accessor to the simple types which consist of this composite
#     type
#
# Returns:
#
#     array ref - containing instances of <EBox::Types::Abstract>
#     class
#
sub types
{
    my ($self) = @_;

    return $self->{types};
}

# Method: showTypeName
#
#     Accessor to the property which determines whether to show the
#     printable type name or not just helping the viewer/setter to
#     make beautiful viewer
#
# Returns:
#
#     boolean - true if we want to show the type printable name, false
#     otherwise
#
sub showTypeName
{
    my ($self) = @_;

    return $self->{showTypeName};
}

# Protected Methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
{
    my ($self, $params) = @_;

    $self->_callTypeMethod('_setMemValue', $params);
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

    $self->_callTypeMethod('_restoreFromHash', $hash);
}

# Method: _storeInHash
#
# Overrides:
#
#      <EBox::Types::Text::_storeInHash>
#
sub _storeInHash
{
    my ($self, $hash) = @_;

    $self->_callTypeMethod('_storeInHash', $hash);
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    $self->_callTypeMethod('_paramIsValid', $params);

    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
# Returns:
#
#       true - if all simple types are set
#
#       false - otherwise
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    foreach my $type ( @{$self->types()} ) {
        my $isSet = $type->_paramIsSet($params);
        unless ( $isSet ) {
            return 0;
        }
    }

    return 1;
}

# Method: _setValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#       value - array ref containing a value for each type to set its
#       value using its own _setValue method
#
sub _setValue
{
    my ($self, $arrayValue) = @_;

    my @simpleTypes = @{$self->types()};
    for (my $idx; $idx < scalar(@simpleTypes); $idx++) {
        my $simpleValue = $arrayValue->[$idx];
        my $simpleType = $simpleTypes[$idx];
        $simpleType->_setValue($simpleValue);
    }
}

# Group: Private methods

# Call given method to every type which lives inside the Composite
# type
sub _callTypeMethod # (methodName, args)
{
    my ($self, $methodName, @args) = @_;

    foreach my $simpleType ( @{$self->types()} ) {
        $simpleType->setRow($self->row());
        $simpleType->$methodName(@args);
    }

    return;
}

1;
