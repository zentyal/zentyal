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

package EBox::Types::Select;

use strict;
use warnings;

use base 'EBox::Types::Basic';

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Exceptions::Internal;

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
        $opts{'HTMLSetter'} ='/ajax/setter/selectSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
            $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
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

    unless ( $self->editable() ) {
        throw EBox::Exceptions::Internal(
                                         'Select ' . $self->fieldName() . ' should be ' .
                   'editable. If you want a read only field, use ' .
                   'text type instead.'
                                        );
    }
    if ( $self->optional()
             and not $self->isa('EBox::Types::InverseMatchSelect') ) {
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
            unless (exists $self->{'options'}) {
                my $populateFunc = $self->populate();
                $self->{'options'} = &$populateFunc();
            }
        }


    return $self->{'options'};
}

sub printableValue
{
    my ($self) = @_;

    # Cache the current options
    my $options = $self->options();
    return '' unless (defined($options));
    
    foreach my $option (@{$options}) {
        if ($option->{'value'} eq $self->{'value'}) {
            return $option->{'printableValue'};
        }
    }

}

sub value
{
    my ($self) = @_;

    return $self->{'value'};
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

# Group: Protected methods

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{
    my ($self, $gconfmod, $key) = @_;

    if ( defined ( $self->memValue() )) {
        $gconfmod->set_string("$key/" . $self->fieldName(), $self->memValue());
    } else {
        $gconfmod->unset("$key/" . $self->fieldName());
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
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    # Check whether value is within the values returned by
    # populate callback function
    my @allowedValues = map { $_->{value} } @{$self->options()};

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

    return $model->optionsFromForeignModel($field);
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
    my $rows = $model->rows();
    
    foreach my $row (@{$rows}) {
        push( @optionsAlreadyModel, $row->{valueHash}->{$field});
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

#  Method: cmp
#
#
#  Warning:
#  We compare printableValues bz it has more sense for the user (specially when
#  we have a foreignModel and the values are roe Ids). However there may be many
#  cases when this would not be appropiate
#
#  Overrides:
#  <EBox::Types::Abstract>
sub cmp
{
    my ($self, $other) = @_;

    if (ref($self) ne ref($other)) {
        return undef;
    }

    return ($self->printableValue() cmp $other->printableValue());

}


1;
