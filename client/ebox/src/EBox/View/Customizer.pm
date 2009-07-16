# Copyright (C) 2009 eBox technologies S.L.
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
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA

# Class: EBox::View::Customizer
#
#   This class is used to customize default views. It helps to change the
#   behaviour and layout of a view using Perl code.
#
package EBox::View::Customizer;

use strict;
use warnings;

# Dependencies
use EBox::Config;

# External dependencies
use HTML::Mason::Interp;
use JSON; # objToJson
use Error qw(:try);

# EBox exceptions
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

# Group: Public methods

# Method: new
#
#      Constructor for <EBox::View::Customizer>
sub new
{
    my $class = shift;
    my $self = { };
    bless ($self, $class);
    return $self;
}

# Method: setModel
#
#   Set the model this class is customizing
#
# Parameters:
#       (Positional)
#
#        model - An instance of <EBox::Model::DataTable>
#
sub setModel
{
    my ($self, $model) = @_;

    unless (defined($model)) {
        throw EBox::Exceptions::MissingArgument('model');
    }

    $self->{model} = $model;
}

# Method: model
#
#   Return the model this class is customizing
#
#
sub model
{
    my ($self) = @_;

    return $self->{model};
}

# Method: setOnChangeActions
#
#   This method is used to set the actions -hide/show or enable/disable- that will take
#   place on the UI whenever there is a change on one field value.
#
# Parameters:
#
#   A hash ref containing any number of:
#
#   fieldName =>
#       {
#           [ value1, value2 ] => {
#                   disable => [ fieldName2, fieldName3 ],
#                   enable => [ fieldName4, fieldName5]    }
#       }
#
#  Where
#       fieldName: is the name of the watched field
#       value1, value2: are the values of the watched field that trigger
#                       hide/show actions
#       fieldName2, fieldName3: name of fields that need to be showed or hidden
#
#  Example:
#
#       Let's say we have two fields. One is called 'Protocol', and
#       it's a select that  can take 'TCP','UDP', or 'GRE'.
#       The other field is called 'Port', and
#       it's only used if the protocol is either 'TCP' or 'UDP'.
#
#       Protocol =>
#           {
#                GRE  => { disable => [ Port ] },
#                TCP => { enable => [ Port ] },
#                UDP => { enable => [ Port ] }
#           }
#
#
#       Note that you will have to use 'on' and 'off' for boolean values
sub setOnChangeActions
{
    my ($self, $onChangeActions) = @_;

    # TODO Make sanity checks

    $self->{onChangeActions} = $onChangeActions
}

# Method: onChangeActions
#
#   Return the  actions -hide or show- that will take place
#   on the UI whenever there is a change on one field value.
#
sub onChangeActions
{
    my ($self) = @_;

    return $self->{onChangeActions};
}

# Method: onChangeActionOnFieldJS
#
#   It returns the JS code to run when there is a change on a field
#
# Parameters:
#   (Positional)
#
#   fieldName - field name
#
# Returns:
#
#    A string containing js code or an empty string in case this field
#    doesn't need to trigger anything
#
sub  onChangeActionOnFieldJS
{
    my ($self, $fieldName) = @_;

    unless (defined($fieldName)) {
        throw EBox::Exceptions::MissingArgument('fieldName');
    }

    my $onChangeActions = $self->onChangeActions();
    my $actions = $onChangeActions->{$fieldName};
    return '' unless (defined($actions));

    my $filename = EBox::Config::templates . '/js/onchange.mas';
    my $output;
    my $interp = HTML::Mason::Interp->new(comp_root =>
                        EBox::Config::templates,
                        out_method => \$output);
    my $comp = $interp->make_component(comp_file => $filename);
    my @params = ();
    push(@params, tableName => $self->_modelName(),
        JSONActions => objToJson($actions),
        fieldName => $fieldName);

    $interp->exec($comp, @params);
    return $output;
}

# Method: onChangeActionsJS
#
#   It returns all the JS functions that are run when
#   there is a change on some fields
#
# Returns:
#
#    A string containing js code or an empty string in case this field
#    doesn't need to trigger anything
#
sub  onChangeActionsJS
{
    my ($self) = @_;

    my $jsCode;
    for my $fieldName (@{$self->model()->fields()}) {
        $jsCode .= $self->onChangeActionOnFieldJS($fieldName);
    }
    return $jsCode;
}

# Method: initHTMLStateField
#
#   Given a field, it returns if the field has to be shown. hidden, or disabled
#
# Parameters:
#
#    (Positional)
#
#   fieldName - string containing the field name
#   fields - array ref of instancied types with their current values
#
# Returns:
#
#   One of these strings:
#
#          show
#          hide
#          disable
#
sub initHTMLStateField
{
    my ($self, $fieldName, $fields) = @_;

    unless (defined($fieldName)) {
        throw EBox::Exceptions::MissingArgument('fieldName');
    }
    unless (defined($fields)) {
        throw EBox::Exceptions::MissingArgument('fields');
    }

    my $actions = $self->onChangeActions();
    return 'show' unless (defined($actions));

    for my $trigger (keys %{$actions}) {
        next if ($trigger eq $fieldName);
        for my $value (keys %{$actions->{$trigger}}) {
            for my $action (keys %{$actions->{$trigger}->{$value}}) {
                next if ($action eq 'show');
                for my $field (@{$actions->{$trigger}->{$value}->{$action}}) {
                    if ($field eq $fieldName) {
                        for my $f (@{$fields}) {
			    if ($f->fieldName() eq $trigger and
				$self->_hasTriggerValue($f, $value)) {
				return $action;
			    }
                         }
                    }
                }
            }
        }
    }

    return 'show';
}


# Group: Private methods
sub _hasTriggerValue
{
	my ($self, $field, $value) = @_;

	if ($field->isa('EBox::Types::Boolean')) {
		 my $bool = new EBox::Types::Boolean(
				fieldName => 'dummy',
				defaultValue => $value eq 'on');
		return $field->isEqualTo($bool);
	}

	return  ( $field->value() eq $value );
}

sub _modelName
{
    my ($self) = @_;

    my $model = $self->model();
    unless ($model) {
        throw EBox::Exceptions::Internal('model is not set');
    }

    return $model->tableName();
}

1;
