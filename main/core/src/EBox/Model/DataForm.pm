# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

# Class: EBox::Model::DataForm
#
#       An specialized model from <EBox::Model::DataTable> which
#       stores just one row. In fact, the viewer and setter is
#       different.
use strict;
use warnings;

package EBox::Model::DataForm;

use base 'EBox::Model::DataTable';

use EBox::Model::Row;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

###################
# Dependencies
###################
use Perl6::Junction qw(any);
use NEXT;

# Core modules
use TryCatch;

my $ROW_ID = 'form';

# Group: Public methods

# Constructor: new
#
#       Create the <EBox::Model::DataForm> model instance
#
# Parameters:
#
#       confmodule - <EBox::Module::Config> the GConf eBox module which
#       gives the environment where to store data
#
#       directory - String the subdirectory within the environment
#       where the data will be stored
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);
    return $self;
}

# Method: ids
#
# Overrides <EBox::Model::DataTable::ids> to return only the single row in the form
#
sub ids
{
    return [ $ROW_ID ];
}

sub _ids
{
    return [ $ROW_ID ];
}

# Method: setValue
#
#       Set the value of a element and store the row
#
# Parameters:
#
#       element - String the element's name
#       value   - the value to set. The type depends on the element's type
#
sub setValue
{
    my ($self, $element, $value) = @_;

    my $row = $self->row();
    $row->elementByName($element)->setValue($value);
    $row->store();
}

# Method: value
#
#       Get the value of a element of the row
#
# Parameters:
#
#       element - String the element's name
#
# Returns:
#
#       the value. The type depends on the element's type
#
sub value
{
    my ($self, $element) = @_;
    return $self->row()->valueByName($element);
}

# Method: _checkTable
#
#  Method overriden to add some checks
#
#  Overrides:
#    EBox::Model::DataTable::_checkTable
sub _checkTable
{
    my ($self, $table) = @_;

    $self->SUPER::_checkTable($table);

    my @unallowedSuperParams = qw(sortedBy order);
    foreach my $param (@unallowedSuperParams) {
        if (exists $table->{$param}) {
            throw EBox::Exceptions::Internal(
                "$param is not allowed in description of " . $self->name()
            );
        }
    }
}

# Method: addRow
#
#       This method has no sense since it has just one row. To fill
#       the model instance it should be used
#       <EBox::Model::DataForm::setRow>.
#
# Overrides:
#
#       <EBox::Model::DataTable::addRow>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - throw since it is not possible
#       to add rows to an one-rowed table
#
sub addRow
{
    throw EBox::Exceptions::Internal('It is not possible to add a row to ' .
                                     'an one-rowed table');
}

# Method: addTypedRow
#
#       This method has no sense since it has just one row. To fill
#       the model instance it should be used
#       <EBox::Model::DataForm::setTypedRow>.
#
# Overrides:
#
#       <EBox::Model::DataTable::addTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - throw since it is not possible
#       to add rows to an one-rowed table
#
sub addTypedRow
{
    throw EBox::Exceptions::Internal('It is not possible to add a row to ' .
                                     'an one-rowed table');
}

# Method: row
#
#       Return the row. It ignores any additional parameter
#
# Overrides:
#
#       <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id) = @_;

    if ($self->_rowStored()) {
        return $self->SUPER::row($ROW_ID);
    } else {
        return $self->_defaultRow();
    }

}

sub _rowStored
{
    my ($self) = @_;
    my $rowDir = $self->{directory} . "/$ROW_ID";
    return defined $self->{'confmodule'}->get($rowDir);
}

# Method: moveRowRelative
#
#       Move a row  It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::moveRowRelative>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub moveRowRelative
{
    throw EBox::Exceptions::Internal('Cannot move up a row in an form');
}

# Method: removeRow
#
#       Remove a row. It makes no sense in an one-rowed table.
#
#       When the remove is forced, <EBox::Model::DataForm::removeAll>
#       is called.
#
# Overrides:
#
#       <EBox::Model::DataTable::removeRow>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table except when forcing.
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    if ($force) {
        $self->removeAll($force);
    } else {
        throw EBox::Exceptions::Internal('Cannot remove a row in a form. Use removeAll() instead.');
    }
}

# Method: removeAll
#
#       Remove all data from the form
#
# Overrides:
#
#       <EBox::Model::DataTable::removeAll>
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if the remove is not
#      forced
#
sub removeAll
{
    my ($self, $force) = @_;

    if ($force) {
        # Remove the data
        $self->{confmodule}->unset("$self->{directory}/form");
    } else {
        throw EBox::Exceptions::Internal('Cannot remove data unless force specified');
    }
}

# Method: warnIfIdUsed
#
#       Warn if the data is already in use. The overridden method must
#       ignore any additional parameter.
#
# Overrides:
#
#       <EBox::Model::DataTable::warnIfIdUsed>
#
sub warnIfIdUsed
{

}

# Method: setRow
#
#   Set an existing row. The unique row is set here. If there was
#   no row. It will be created.
#
#
# Overrides:
#
#       <EBox::Model::DataTable::setRow>
#
# Parameters:
#
#       force - boolean indicating whether the set is forced or not
#       params - hash named parameters containing the expected fields
#       for each row
#       - Positional parameters
#
sub setRow
{
    my ($self, $force, %params) = @_;
    $self->validateRow('update', \%params);

    # We can only set those types which have setters
    my @newValues = @{$self->setterTypes()};

    # Fetch field trigger names
    my $viewCustom = $self->viewCustomizer();
    my %triggerFields = %{$self->viewCustomizer()->onChangeFields()};
    # Fetch trigger values
    for my $name (keys %triggerFields) {
        $triggerFields{$name} = $params{$name};
    }

    my $changedData;
    for (my $i = 0; $i < @newValues ; $i++) {
        my $newData = $newValues[$i]->clone();
        my $fieldName = $newData->fieldName();
        # Skip fields that are hidden or disabled by the view customizer
        unless ($viewCustom->skipField($fieldName, \%triggerFields)) {
            $newData->setMemValue(\%params);
        }
        $changedData->{$fieldName} = $newData;
    }

    $self->setTypedRow($ROW_ID,
                       $changedData,
                       force => $force,
                       readOnly => $params{'readOnly'},
                       disabled => $params{'disabled'});
}

# Method: setTypedRow
#
#       Set an existing row using types to fill the fields. The unique
#       row is set here. If there was no row, it is created.
#
# Overrides:
#
#       <EBox::Model::DataTable::setTypedRow>
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    if (not $self->_rowStored()) {
        # first set the default row to be sure we have all the defaults
        my $row = $self->_defaultRow();
        $self->SUPER::addTypedRow(
                                  $row->{'valueHash'},
                                  id => $ROW_ID,
                                  noOrder => 1,
                                  noValidateRow => 1,
                                 );
    }

    $self->SUPER::setTypedRow($ROW_ID, $paramsRef, %optParams);
}

# Method: set
#
#      Set a value from the form
#
# Parameters:
#
#      There is a variable number of parameters following this
#      structure: fieldName => fieldValue. Check
#      <EBox::Types::Abstract::_setValue> for every type to know which
#      fieldValue is required to be passed
#
#      force - Boolean indicating if the update is forced or not
#      *(Optional)* Default value: false
#
#      readOnly - Boolean indicating if the row becomes a read only
#      kind one *(Optional)* Default value: false
#
#      disabled - Boolean indicating if the row is disabled in the UI
#                 *(Optional)* Default value: false
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if no params are
#     passed to set a value
sub set
{
    my ($self, %params) = @_;

    my $force = delete $params{force};
    $force = 0 unless defined($force);
    my $readOnly = delete $params{readOnly};
    $readOnly = 0 unless defined($readOnly);
    my $disabled = delete $params{disabled};
    $disabled = 0 unless defined ($disabled);

    unless ( keys %params > 0 ) {
        throw EBox::Exceptions::MissingArgument('Missing parameters to set their value');
    }

    my $typedParams = $self->_fillTypes(\%params, 1);

    $self->setTypedRow($ROW_ID, $typedParams, force => $force,
                       readOnly => $readOnly,
                       disabled => $disabled);
}

# Method: order
#
#       Get the keys order in an array ref. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::order>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub order
{
    throw EBox::Exceptions::Internal('It has no sense order in an one-rowed table');
}

# Method: sortedBy
#
#       Return the field name which is used by model to sort rows when
#       the model is not ordered. It makes no sense in an one-rowed table.
#
# Returns:
#
#       String - field name used to sort the rows
#
sub sortedBy
{
    throw EBox::Exceptions::Internal('It has no sense sortedBy in an one-rowed table');
}

# Method: rowUnique
#
# Since we have only one row we return false to disable
# row-uniqueness tests
#
# Overrides:
#
#       <EBox::Model::DataTable::rowUnique>
#
sub rowUnique
{
    return 0;
}

# Method: _checkFieldIsUnique
#
# Since we have only one row we return false to disable
# field uniqueness tests
#
# Overrides:
#
#       <EBox::Model::DataTable::_checkFieldIsUnique>
#
sub _checkFieldIsUnique
{
    return 0;
}

# Method: setFilter
#
#       Set the string used to filter the return of rows. It makes no
#       sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::setFilter>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub setFilter
{
    throw EBox::Exceptions::Internal('No filter is needed in an one-rowed table');
}

# Method: filter
#
#       Get the string used to filter the return of rows. It makes no
#       sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::filter>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub filter
{
    throw EBox::Exceptions::Internal('No filter is needed in an one-rowed table');
}

# Method: pages
#
#       Return the number of pages.
#
# Overrides:
#
#       <EBox::Model::DataTable::pages>
#
sub pages
{
    return 1;
}

# Method: automaticRemoveMsg
#
#       Get the i18ned string to show when an automatic remove is done
#       in a model
#
# Overrides:
#
#       <EBox::Model::DataTable::automaticRemoveMsg>
#
# Parameters:
#
#       nDeletedRows - Int the deleted row number
#
sub automaticRemoveMsg
{
    my ($self, $nDeletedRows) = @_;

    return __x('Remove data from {model}{br}',
               model   => $self->printableName(),
               br      => '<br>');
}

# Method: addedRowNotify
#
#  In some cases this is called instead of updateRowNotify/formSubmitted, so we overload
#  so all updates go to formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, @params) = @_;
    $self->formSubmitted(@params);
}

# Method: updatedRowNotify
#
# Overrides:
#
#       <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, @params) = @_;

    $self->formSubmitted(@params);
}

# Method: formSubmitted
#
#      Override this method to be notified whenever a form
#      is submitted
#
# Parameters:
#
#   row - <EBox::Model::Row> row containing fields and values of the
#         updated row
#
#   oldRow - <EBox::Model::Row> row containing fields and values of the updated
#            row before modification. Maybe undef it it was not previous row
#
#   force - boolean indicating whether the delete is forced or not
#
sub formSubmitted
{

}

# Method: AUTOLOAD
#
#      This method will intercept any call done to undefined
#      methods. It is used to return the value, printableValue or Type
#      from an attribute which belongs to the form.
#
#      So, a form which contains a boolean attribute called enabled
#      may have this four methods:
#
#        - enabledValue() - return the value from the attribute
#        enabled
#
#        - enabledPrintableValue() - return the printable value
#        from the attribute enabled
#
#        - enabledType() - return the type from the attribute
#        enabled, that is, a instance of <EBox::Types::Boolean> class.
#
#        - enabled() - the same as enabledValue()
#
# Returns:
#
#     - the value if it ends with Value() or it is just the attribute name
#     - String - the printable value if it ends with PrintableValue()
#     - <EBox::Types::Abstract> - the type if it ends with Type()
#
# Exceptions:
#
#     <EBox::Exceptions::Internal> - thrown if no attribute exists or
#     it is not finished correctly
#
sub AUTOLOAD
{
    my ($self, @params) = @_;
    my $methodName = our $AUTOLOAD;

    $methodName =~ s/.*:://;

    # Ignore DESTROY callings (the Perl destructor)
    if ( $methodName eq 'DESTROY' ) {
        return;
    }

    unless ( UNIVERSAL::can($self, 'row') ) {
        use Devel::StackTrace;
        my $trace = new Devel::StackTrace();
        EBox::debug($trace->as_string());
        throw EBox::Exceptions::Internal("Not valid autoload method $methodName since "
                                         . "$self is not a EBox::Model::DataForm");
    }

    my $row = $self->row();

    # Get the attribute and its suffix if any <attr>(Value|PrintableValue|Type|)
    my ($attr, $suffix) = $methodName =~ m/^(.+?)(Value|PrintableValue|Type|)$/;

    unless ( any( keys ( %{$row->hashElements()} ) ) eq $attr ) {
        # Try with the parent autoload
        return $self->NEXT::ACTUAL::AUTOLOAD(@params);
    }

    # If no suffix is given used
    unless ( $suffix ) {
        # Use the default value
        $suffix = 'Value';
    }

    if ( $suffix eq 'Value' ) {
        return $row->valueByName($attr);
    } elsif ( $suffix eq 'PrintableValue' ) {
        return $row->printableValueByName($attr);
    } elsif ( $suffix eq 'Type' ) {
        return $row->elementByName($attr);
    }
}

# Group: Protected methods

# Method: _setDefaultMessages
#
# Overrides:
#
#      <EBox::Model::DataTable::_setDefaultMessages>
#
sub _setDefaultMessages
{
    my ($self) = @_;

    unless (exists $self->table()->{'messages'}->{'update'}) {
        $self->table()->{'messages'}->{'update'} = __('Done');
    }
}

# Group: Class methods

# Method: Viewer
#
# Overrides:
#
#        <EBox::Model::DataTable::Viewer>
#
sub Viewer
{
    return '/ajax/form.mas';
}

# Group: Private methods

# Return a row with only default values
sub _defaultRow
{
    my ($self) = @_;

    my $dir = $self->{'directory'};
    my $confmod = $self->{'confmodule'};
    my $row = EBox::Model::Row->new(dir => $dir, confmodule => $confmod);
    $row->setModel($self);
    $row->setId($ROW_ID);

    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $element = $type->clone();
        $row->addElement($element);
    }
    return $row;
}

# Method: clone
#
# Overrides: EBox::Model::DataTable::clone
#
# Adaptation of the overriden method to DataForm class
sub clone
{
    my ($self, $srcDir, $dstDir) = @_;
    my $origDir = $self->directory();

    try {
        $self->setDirectory($srcDir);
        my $srcRow = $self->row();
        my $srcHashElements = $srcRow->hashElements();

        $self->setDirectory($dstDir);
        my $dstRow = $self->row();
        while (my ($name, $srcElement) = each %{ $srcHashElements }) {
            $dstRow->elementByName($name)->setValue($srcElement->value());
        }

        $dstRow->store();
        $dstRow->cloneSubModelsFrom($srcRow)
    } catch ($e) {
        $self->setDirectory($origDir);
        $e->throw();
    }
    $self->setDirectory($origDir);
}

sub formSubmitJS
{
    my ($self, $editId) = @_;

    my  $function = "Zentyal.TableHelper.formSubmit('%s','%s',%s,'%s','%s')";

    my $table = $self->table();
    my $tablename = $table->{'tableName'};
    my $actionUrl = $table->{'actions'}->{'editField'};
    unless (defined($actionUrl)) {
        $actionUrl = "";
    }
    my $fields = $self->_paramsWithSetterJS();
    return sprintf ($function,
                    $actionUrl,
                    $tablename,
                    $fields,
                    $table->{'confdir'},
                    $editId);
}

1;
