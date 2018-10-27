# Copyright (C) 2009-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::View::Customizer;

# Dependencies
use EBox::Config;
use EBox::Types::Boolean;

# External dependencies
use HTML::Mason::Interp;
use JSON;
use List::Util; # first
use TryCatch;

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
    my $self = {};
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

# Method: setPermanentMessage
#
#   Set a message that will be always shown on top of the form as in opposed to
#   flash messages that are shown when an action takes place
#
# Parameters:
#
#   string - string to show
#   type - (Optional) note, ad, warning
#
sub setPermanentMessage
{
    my ($self, $msg, $type) = @_;

    defined($type) or $type = 'note';

    $self->{permanentMessage} = $msg;
    $self->{permanentMessageType} = $type;
}

# Method: permanentMessage
#
#   Return a message that will be always shown on top of the form as in opposed to
#   flash messages that are shown when an action takes place
#
#
# Returns:
#
#   string - string to show
#
sub permanentMessage
{
    my ($self) = @_;

    my $msg = $self->{permanentMessage};
    if ((not $msg) and defined ($self->{model})) {
        $msg = $self->{model}->permanentMessage();
    }

    return $msg;
}

# Method: permanentMessageType
#
#   Return the type for the defined permanent message
#
# Returns:
#
#   string - note, ad or warning
#
sub permanentMessageType
{
    my ($self) = @_;

    my $type = $self->{permanentMessageType};
    if ((not $type) and defined ($self->{model})) {
        $type = $self->{model}->permanentMessageType();
    }

    return $type;
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

# Method: onChangeFields
#
#   Return a hash name containing the field names that
#   trigger a show or hide action
#
sub onChangeFields
{
    my ($self) = @_;

    my $actions = $self->{onChangeActions};
    if ($actions) {
        return {map {$_ => undef} keys %$actions};
    } else {
        return {};
    }
}

# Method: skipField
#
# Parameters:
#
#   (POSITIONAL)
#
#   fieldName - string
#   onChangeValues - hash ref containing the field names
#                    that trigger actions and their actual
#                    values
# Returns:
#
#   boolean - true skip, otherwise false
#
sub skipField
{
    my ($self, $field, $values) = @_;

    return 0 unless ($field);
    return 0 unless ($values);
    return 0 unless (%$values);

    my $actions = $self->{onChangeActions};
    for my $triggerField (keys %$values) {
        my $actualValue = $values->{$triggerField};
        next unless defined ($actualValue);
        my $actionTriggered = $actions->{$triggerField}->{$actualValue};
        my $disable = $actionTriggered->{disable};
        my $hide = $actionTriggered->{hide};
        my @ignore;
        push (@ignore, @{$disable}) if ($disable);
        push (@ignore, @{$hide}) if ($hide);
        if (@ignore) {
            if (List::Util::first { $_ eq $field } @ignore) {
                return 1;
            }
        }
    }

    return 0;
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
my $interp;
my $output;
sub onChangeActionOnFieldJS
{
    my ($self, $tableName, $fieldName) = @_;

    unless (defined($fieldName)) {
        throw EBox::Exceptions::MissingArgument('fieldName');
    }

    my $onChangeActions = $self->onChangeActions();
    my $actions = $onChangeActions->{$fieldName};
    return '' unless (defined($actions));

    my $filename = EBox::Config::templates . '/js/onchange.mas';
    # cannot use EBox::Html::makeHtml here
    $output = '';
    if (not $interp) {
        $interp = HTML::Mason::Interp->new(
            comp_root => EBox::Config::templates,
            out_method => \$output
        );
    }

    my $comp = $interp->make_component(comp_file => $filename);
    my @params = ();
    push(@params, tableName => $tableName,
                  JSONActions => to_json($actions),
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
sub onChangeActionsJS
{
    my ($self) = @_;
    my $tableName = $self->model()->table()->{'tableName'};

    my $jsCode;
    for my $fieldName (@{$self->model()->fields()}) {
        $jsCode .= $self->onChangeActionOnFieldJS($tableName, $fieldName);
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

    my @triggers = @{ $self->initHTMLStateOrder() };
    if (not @triggers) {
        @triggers = keys %{$actions};
    }

    for my $trigger (@triggers) {
        next if ($trigger eq $fieldName);
        for my $value (keys %{$actions->{$trigger}}) {
            for my $action (keys %{$actions->{$trigger}->{$value}}) {
                for my $field (@{$actions->{$trigger}->{$value}->{$action}}) {
                    if ($field eq $fieldName) {
                        for my $f (@{$fields}) {
                            if (($f->fieldName() eq $trigger) and
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

sub initHTMLStateOrder
{
    my ($self) = @_;
    my $order = $self->{initHTMLStateOrder};
    return (defined ($order) ? $order : []);
}

sub setInitHTMLStateOrder
{
    my ($self, $order) = @_;
    $self->{initHTMLStateOrder} = $order;
}

sub setHTMLTitle
{
    my ($self, $title) = @_;
    $self->{htmlTitle} = $title;
}

# Method: HTMLTitle
#
#   Return the data structure that is used to
#   create the page title.
#
#   This structure is used to make up a breadcrumb header, if needed.
#
# Returns:
#
#   Array ref of hash ref containing the page title.
#   Each hash represents a component of the title. For example:
#
#          Services >> Pop 3
#
#   For every component you need its text and its link. So every hash
#   contains the following keys:
#
#       title
#       link
sub HTMLTitle
{
    my ($self) = @_;

    if ($self->{htmlTitle}) {
        return $self->{htmlTitle};
    }
    my @crumbs;
    my $model = $self->model();
    while (1) {
        if ( $model->HTTPLink() or $model->pageTitle() ) {
            my $titleName = $model->printableName();
            $titleName = $model->pageTitle() if ($model->pageTitle());
            unshift (@crumbs, { title => $titleName,
                                link  => $model->HTTPLink() }
                    );
        }
        if ($model->parentRow()) {
            $model = $model->parentRow()->model()
        } else {
            last;
        }
    }

    return \@crumbs;
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
