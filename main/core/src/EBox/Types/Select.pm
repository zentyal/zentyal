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

use strict;
use warnings;

package EBox::Types::Select;

use base 'EBox::Types::Basic';

use EBox;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

##################
# Dependencies:
##################
use Perl6::Junction qw(any);

use constant ADD_NEW_MODAL_VALUE => '_addNew';

# Method: new
#
# Parameters:
#   - parent class parameters
#   - populate: function pointer which return the options of the select
#   - foreignModel: model from which it rows the select we get its options  (has priority over populate)
#   - foreignField : field of the foreign model which will be used as label for
#       the options
#   - foreignFilter: filter function for foreign model rows, it will be called with the foreign model row as argument
#        and if it return true the row wil l be included. If not present all rows will be included
#   - foreignNoSyncRows: don't call syncRows in the foreginModel when getting its rows
#   - foreignNextPageField: its presence signals for a 'Add new' popup for add a foreign element. Its value will be the field of the subModel of the
#                            foreign's row which will be edited after adding the new foreign item.
#   - disableCache: disable the options cache.
sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/selectSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/selectViewer.mas';
    }
    unless (exists $opts{'disableCache'}) {
        $opts{'disableCache'} = 0;
    }

    $opts{'type'} = 'select';
    my $self = $class->SUPER::new(%opts);

    # This doesn't check if the option method is implemented
    # unless ($self->{populate} or $self->{options} or $self->{foreignModel}) {
    # throw EBox::Exceptions::MissingArgument('populate or foreignModel');
    #}

    if ($self->{foreignModel} and (not $self->{foreignField})) {
        throw EBox::Exceptions::MissingArgument('foreignField');
    }

    if (scalar $self->{editable} and not $self->{editable}) {
        throw EBox::Exceptions::Internal(
                                         'Select ' . $self->fieldName() . ' should be ' .
                   'editable. If you want a read only field, use ' .
                   'text type instead.'
                                        );
    }
    if ($self->optional()
             and not $self->isa('EBox::Types::InverseMatchSelect')
             and not $self->isa('EBox::Types::MultiSelect')) {
        throw EBox::Exceptions::Internal('Select ' . $self->fieldName() .
                                         ' must be compulsory');
    }

    bless($self, $class);
    return $self;
}

sub size
{
    my ($self) = @_;

    return $self->{'size'};
}

# Method: disableCache
#
#   Return if we must disable the options cache.
#   For performance reasons, eBox caches the options given for a select type
#
# Returns:
#
#   boolean - true means it mustn't cache,  false it will cache
#             By default, it will return false
#
sub disableCache
{
    my ($self) = @_;

    return $self->{disableCache};
}

# Method: setDisableCache
#
#   Set if we must disable the options cache.
#   For performance reasons, eBox caches the options given for a select type
#   By default, it will cache
#
# Parameters:
#
#   boolean - true means it mustn't cache,  false it will cache
#
sub setDisableCache
{
    my ($self, $disable) = @_;

    $self->{disableCache} = $disable;
}

# Method: options
#
#      Get the options from the select. It gets dynamically from a
#      foreign model if <EBox::Types::Select::foreignModel> is defined
#      or from <EBox::Types::Select::populate> function defined in the
#      model template
#
# Returns:
#
#      array ref - containing a hash ref with the following fields:
#
#                  - value - the id which identifies the option
#                  - printableValue - the printable value for this option
#
sub options
{
    my ($self) = @_;

    if ( exists $self->{'foreignModel'}) {
        $self->{'options'} = $self->_optionsFromForeignModel();
    } else {
        if ((not exists $self->{'options'}) or $self->disableCache()) {
            my $populateFunc = $self->populate();
            $self->{'options'} = &$populateFunc($self->model());
        }
    }

    return $self->{'options'};
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
    foreach my $option (@{$options}) {
        if ($option->{'value'} eq $value) {
            if ($option->{'printableValue'}) {
                return $option->{'printableValue'};
            } else {
                return $value;
            }
        }
    }

    return $value;
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
        my @options = @{$self->options()};
        if (@options) {
            return $options[0]->{'value'};
        } else {
            return undef;
        }
    }
}

# Method: foreignModel
#
#       Return the foreignModel associated to the type
#
# Returns:
#
#       object - an instance of class <EBox::Model::DataTable>
sub foreignModel
{
    my ($self) = @_;
    my $foreignModel = $self->{'foreignModel'};

    return undef unless (defined($foreignModel));
    my $model = &$foreignModel($self);
    return $model;
}

# Method: foreignField
#
#       Return the field of the foreign model which will be used as label for
#       the options
#
sub foreignField
{
    my ($self) = @_;
    if (not exists $self->{foreignField}) {
        return undef;
    }
    return $self->{foreignField};
}

sub foreignNextPageField
{
    my ($self) = @_;
    if (not exists $self->{foreignNextPageField}) {
        return undef;
    }
    return $self->{foreignNextPageField};
}

# Method: populate
#
#       Get the function pointer which populate options within the
#       select
#
# Return:
#
#       function ref - the function which returns an array ref. This
#       array elements are the same that are returned by
#       <EBox::Types::Select::options>.
#
sub populate
{

    my ($self) = @_;

    unless ( defined ( $self->{'populate'} )) {
        throw EBox::Exceptions::Internal('No populate function has been ' .
                                         'defined and it is required to fill ' .
                                         'the select options');
    }

    return $self->{'populate'};

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
        return ($self->printableValue() cmp $other->printableValue());
    } else {
        return $cmpContext;
    }
}

# Method: isValueSet
#
#   Check if the type has been set. You can't use value to do this because
#   it always defaults to the first value of options
#
# Return:
#
#   boolean  - true is set otherwise false
#
sub isValueSet
{
    my ($self) = @_;

    return (defined($self->{'value'}));
}

# Group: Protected methods

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};
    # Check whether value is within the values returned by
    # populate callback function
    my @allowedValues = map { $_->{value} } @{$self->options()};
    if (not @allowedValues) {
        if ($value eq ADD_NEW_MODAL_VALUE) {
            throw EBox::Exceptions::External(
                __x(q|{name} empty. You can add and select a new {name} with the 'add new' button|,
                     name => $self->printableName(),
                   )
               );
        } else {
            throw EBox::Exceptions::External(
                __x(q|{name} has not selectable values|,
                     name => lcfirst $self->printableName(),
                   )
               );
        }
    }

    # We're assuming the options value are always strings
    unless ( grep { $_ eq $value } @allowedValues ) {
        throw EBox::Exceptions::InvalidData( data   => $self->printableName(),
                                             value  => $value,
                                             advice =>
                      __x('Choose a value within the value set: {set}',
                                 set => join(', ', @allowedValues))
                                           );
    }

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

    # Check if the parameter exist
    my $param =  $params->{$self->fieldName()};

    return defined ( $params->{$self->fieldName()} );
}

# Method: _setValue
#
#       Set the value for the select. It allows to the select not only
#       use default options using populate function but also a field
#       from the foreign model indicating the printable value or the
#       row identifier
#
# Overrides:
#
#       <EBox::Types::Abstract::_setValue>
#
sub _setValue
{
    my ($self, $value) = @_;

    my $params;
    my $mappedValue = $value;
    if ( defined($self->foreignModel()) ) {
        # Map the given printable value to the real value to store in
        # GConf
        my $options = $self->_optionsFromForeignModel();
        foreach my $option (@{$options}) {
            if ( $option->{printableValue} eq $value ) {
                $mappedValue = $option->{value};
                last;
            } elsif ( $option->{value} eq $value ) {
                last;
            }
        }
    }
    $params = { $self->fieldName() => $mappedValue };

    $self->setMemValue($params);
}

# Group: Private helper functions

# Method: _optionsFromForeignModel
#
#   (PRIVATE)
#
#   This method is used to fetch options values from a foreign model
#
#

sub _optionsFromForeignModel
{
    my ($self) = @_;

    my $model = $self->foreignModel();
    my $field = $self->{'foreignField'};

    return unless (defined($model) and defined($field));

    my @params = ();
    if ($self->{foreignFilter}) {
        push @params, filter => $self->{foreignFilter};
    }
    if ($self->{foreignNoSyncRows}) {
        push @params, noSyncRows => $self->{foreignNoSyncRows};
    }

    return $model->optionsFromForeignModel($field, @params);
}

# Method: _filterOptions
#
#   Given a set of available options, returns the ones which the user
#   may use. This method is done at selectSetter.mas due to deep
#   recursion using rows here.
#
sub _filterOptions
{
    my ($self, $options) = @_;

    my $model = $self->model();

    return $options unless defined ( $model );

    my $field  = $self->fieldName();

    my @optionsAlreadyModel = ();

    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push( @optionsAlreadyModel, $row->valueByName($field));
    }

    # Difference among optionsAlreadyModel and options arrays
    my @filteredOptions = grep { $_->{value} ne any(@optionsAlreadyModel) } @{$options};

    # Add the current value if the action is an edition
    if ( $self->value() ) {
        push ( @filteredOptions, {
                                  value => $self->value(),
                                  printableValue => $self->printableValue(),
                                 }
             );
    }

    return \@filteredOptions;
}

1;
