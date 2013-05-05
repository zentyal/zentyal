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

use strict;
use warnings;

package EBox::Types::MultiSelect;

use base 'EBox::Types::Select';

use EBox;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotImplemented;

##################
# Dependencies:
##################
use Perl6::Junction qw(any);

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/multiSelectSetter.mas';
    }

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: printableValue
#
# Overrides:
#
#     <EBox::Types::Abstract::printableValue>
#
sub printableValue
{
    my ($self) = @_;

    # Cache the current options
    my $options = $self->options();
    return '' unless (defined($options));

    my $value = $self->value();
    my @printableValues;
    foreach my $option (@{$options}) {
        if ($option->{'value'} eq any(@{$value})) {
            push( @printableValues, $option->{'printableValue'} );
        }
    }
    return join(', ', @printableValues);
}

# Method: fields
#
#    Get the list of fields of interest for the type
#
# Overrides:
#
#    <EBox::Types::Abstract::fields>
#
sub fields
{
    my ($self) = @_;

    return map { $self->fieldName() . "_" . $_->{'value'} }
        @{ $self->options() };
}

# Method: value
#
# Overrides:
#
#     <EBox::Types::Abstract::value>
#
sub value
{
    my ($self) = @_;

    if (defined($self->{'value'})) {
        return $self->{'value'};
    } else {
        return [];
    }
}

sub _setValue
{
    my ($self, $values) = @_;

    my $params;
    my @mappedValues;

    my $options = $self->options();
    foreach my $option ( @{$options} ) {
        if ( $option->{printableValue} eq any(@{$values}) or
             $option->{value} eq any(@{$values}) ) {
            push ( @mappedValues, $option->{value} );
        }
    }

    $params = { $self->fieldName() => \@mappedValues };
    $self->setMemValue($params);
}

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Basic::_setMemValue>
#
sub _setMemValue
{
    my ($self, $params) = @_;

    if ( $params->{ $self->fieldName() } ) {
        $self->{'value'} = $params->{$self->fieldName()};
    } else {
        my @values;
        foreach my $fieldName ( $self->fields() ) {
            if ( $params->{$fieldName} ) {
                push ( @values, $params->{$fieldName} );
            }
        }
        $self->{'value'} = \@values;
    }
}

#  Method: cmp
#
#
#  Warning:
#  We compare printableValues because it has more sense for the user
#  (especially when we have a foreignModel and the values are row Ids).
#  However there may be many cases when this would not be appropiate.
#
#  Overrides:
#  <EBox::Types::Abstract>
sub cmp
{
    my ($self, $other) = @_;

    if (ref($self) ne ref($other)) {
        return undef;
    }

    my $cmpContext = 0;
    if (defined $other->{cmpContext}) {
        $cmpContext = $self->{cmpContext} cmp $other->{cmpContext};
    }

    if ($cmpContext == 0) {
        # TODO: Compare sets of groups
        return ($self->printableValue() cmp $other->printableValue());
    } else {
        return $cmpContext;
    }
}

# Group: Protected methods

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Select::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;
    return 1;
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Select::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;
    return 1;
}

# Method: _storeInHash
#
# Overrides:
#
#       <EBox::Types::Basic::_storeInHash>
#
# TODO: It's currently used in LDAP-stored models, implement this if used in
# redis-stored models.
sub _storeInHash
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Basic::_restoreFromHash>
#
# TODO: It's currently used in LDAP-stored models, implement this if used in
# redis-stored models.
sub _restoreFromHash
{
    throw EBox::Exceptions::NotImplemented();
}

1;
