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

use strict;
use warnings;

package EBox::Model::DataTable;

use base 'EBox::Model::Base';

use EBox;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Model::Row;
use EBox::View::Customizer;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::DeprecatedMethod;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Sudo;
use EBox::Types::Boolean;
use EBox::WebAdmin::UserConfiguration;

use Clone::Fast;
use Encode;
use TryCatch::Lite;
use POSIX qw(ceil INT_MAX);
use Perl6::Junction qw(all any);
use List::Util;
use Scalar::Util;

sub new
{
    my $class = shift;

    my %opts = @_;
    my $confmodule = delete $opts{'confmodule'};
    $confmodule or
        throw EBox::Exceptions::MissingArgument('confmodule');
    my $directory   = delete $opts{'directory'};
    $directory or
        throw EBox::Exceptions::MissingArgument('directory');

    my $self =
    {
        'confmodule' => $confmodule,
        'confdir' => $directory,
        'parent'  => $opts{'parent'},
        'directory' => "$directory/keys",
        'order' => "$directory/order",
        'table' => undef,
    };

    bless($self, $class);

    return $self;
}

# Method: table
#
#       Get the table description. It must NOT be overrided.
#
# Returns:
#
#       hash ref with the table description
#
sub table
{
    my ($self) = @_;

    # It's a singleton method
    unless( defined( $self->{'table'} ) and
            defined( $self->{'table'}->{'tableDescription'})) {
        $self->_setupTable();
    }

    return $self->{'table'};
}

sub _setupTable
{
    my ($self) = @_;

    my $table = $self->_table();
    $self->checkTable($table);
    $self->{'table'} = $table;

    # Set the needed controller and undef setters
    $self->_setControllers();
    # This is useful for submodels
    $self->{'table'}->{'confdir'} = $self->{'confdir'};
    # Add enabled field if desired
    if ( $self->isEnablePropertySet() ) {
        $self->_setEnabledAsFieldInTable();
    }
    # Make fields accessible by their names
    for my $field (@{$self->{'table'}->{'tableDescription'}}) {
        my $name = $field->fieldName();
        $name or throw EBox::Exceptions::Internal('empty field name in type object in tableDescription');

        if (exists $self->{'table'}->{'tableDescriptionByName'}->{$name}) {
            throw EBox::Exceptions::Internal(
                    "Repeated field  name in tableDescription: $name"
                    );
        }

        $self->{'table'}->{'tableDescriptionByName'}->{$name} = $field;
        # Set the model here to allow types have the model from the
        # addition as well
        $field->setModel($self);
    }

    # If all fields are volatile, then the model is volatile
    $self->_setIfVolatile();

    # Some default values
    unless (defined($self->{'table'}->{'class'})) {
        $self->{'table'}->{'class'} = 'dataTable';
    }

    $self->_setDefaultMessages();
}

# Method: checkTable
#
#  This method does some fast and general checks in the table specification
#
sub checkTable
{
    my ($self, $table) = @_;

    if (not exists $table->{tableDescription} and
            not exists $table->{customActions}) {
        throw EBox::Exceptions::Internal('Missing tableDescription in table definition');
    }
    elsif (@{ $table->{tableDescription} } == 0 and
            @{ $table->{customActions} } == 0) {
        throw EBox::Exceptions::Internal('tableDescription has not any field or custom action');
    }

    if (not $table->{tableName}) {
        throw EBox::Exceptions::Internal(
                'table description has not tableName field or has a empty one'
                );
    }

    if ((exists $table->{sortedBy}) and (exists $table->{order})) {
        if ($table->{sortedBy}and $table->{order}) {
            throw EBox::Exceptions::Internal(
             'sortedBy and order are incompatible options'
                                        );
        }
    }
}

# Method: _table
#
#    Override this method to describe your table.
#       This method is (PROTECTED)
#
# Returns:
#
#     table description. See example on <EBox::Network::Model::GatewayDataTable::_table>.
#
sub _table
{
    throw EBox::Exceptions::NotImplemented('_table');
}

# Method
#
#    Override this method to define sections for thsi model
#    XXX: define sections format
#
# Returns:
#
#    Sections description
#
sub sections
{
    return [];
}

# Method: modelName
#
#    Return the model name which is set by the key 'tableName' when
#    a model table is described
#
# Returns:
#
#    string containing the model name
#
sub modelName
{
    my ($self) = @_;
    return $self->table()->{'tableName'};
}

# XXX transitional method, this will be the future name() method
sub nameFromClass
{
    my ($self) = @_;
    my $class;
    if (ref $self) {
        $class = ref $self;
    }
    else {
        $class = $self;
    }

    my @parts = split '::', $class;
    my $name = pop @parts;

    return $name;
}

# DEPRECATED
sub index
{
  #throw EBox::Exceptions::MethodDeprecated();
    return '';
}

# DEPRECATED
sub printableIndex
{
  #throw EBox::Exceptions::MethodDeprecated();
  return '';
}

# Method: noDataMsg
#
#       Return the fail message to inform that there are no rows
#       in the table
#
# Returns:
#
#       String - the i18ned message to inform user that the table
#       is empty
#
#       Default value: empty string
#
sub noDataMsg
{
    my ($self) = @_;

    my $table = $self->{table};
    if ((exists $table->{noDataMsg}) and (defined $table->{noDataMsg})) {
        return $table->{noDataMsg};
    }

    my $rowName = $self->printableRowName();
    if (not $rowName) {
        $rowName = __('element');
    }
    return __x('There is not any {element}',
               element => $rowName,
              );
}

# Method: customFilter
#
#       Return whether a custom filter should be used or not.
#
#       If customFilter is enabled, filter searches on the rows have to
#       be carried out by the method customFilterIds.
#
#       When should I use this?
#
#       Use this option when you have model where you override ids() and row(),
#       and the amount of rows you can potentially have is big > ~ 4000 entries.
#
#       This is useful to speed up filter searches. If you don't this, the
#       automatic filter mechanism of models will be to slow.
#
#       This is also useful when you want to take advantage of the search system
#       of your backend data. For example, if you are mapping data from an LDAP,
#       you can use this feature to carry out searches using the LDAP protocol.
#
# Returns:
#
#       Boolean - true if a row may be enabled or not in the model
#
sub customFilter
{
    my ($self) = @_;

    return $self->{'table'}->{'customFilter'};
}

# Method: isEnablePropertySet
#
#       Return whether the row enabled is set or not
#
# Returns:
#
#       Boolean - true if a row may be enabled or not in the model
#
sub isEnablePropertySet
{
    my ($self) = @_;

    return $self->{'table'}->{'enableProperty'};
}

# Method: defaultEnabledValue
#
#      Get the default value for enabled field in a row if the Enable
#      property is set, check
#      <EBox::Model::DataTable::isEnablePropertySet>. If it is not set
#      the undef value is returned.
#
#      Default value is false.
#
# Returns:
#
#      boolean - true or false depending on the user defined option on
#      *defaultEnabledValue*
#
#      undef - if <EBox::Model::DataTable::isEnablePropertySet>
#      returns false
#
sub defaultEnabledValue
{
    my ($self) = @_;

    unless ( $self->isEnablePropertySet() ) {
        return undef;
    }
    if ( not defined ( $self->{'table'}->{'defaultEnabledValue'} )) {
        $self->{'table'}->{'defaultEnabledValue'} = 0;
    }
    return $self->{'table'}->{'defaultEnabledValue'};
}

# Method: sortedBy
#
#       Return the field name which is used by model to sort rows when
#       the model is not ordered
#
# Returns:
#
#       String - field name used to sort the rows
#
sub sortedBy
{
    my ($self) = @_;
    my $sortedBy = $self->table()->{'sortedBy'};
    return '' unless ( defined $sortedBy );
    return $sortedBy;
}

# Method: fieldHeader
#
#    Return the instanced type of a given header field
#
# Arguments:
#
#     fieldName - field's name
#
# Returns:
#
#    instance of a type derivated of <EBox::Types::Abstract>
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
#       <EBox::Exceptions::DataNotFound> - thrown if the given field
#       name does not exist in the table description
#
sub fieldHeader
{
    my ($self, $name) = @_;

    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('field name')
    }

    unless (exists ($self->table()->{'tableDescriptionByName'}->{$name})) {
        throw EBox::Exceptions::DataNotFound( data => __('field'),
                value => $name);
    }

    return $self->table()->{'tableDescriptionByName'}->{$name};
}

# Method: optionsFromForeignModel
#
#    This method is used to fetch an array of hashes containing
#    pairs of value and printableValue.
#
#    It's a convenience method to be used by <EBox::Types::Select> types
#    when using foreing modules.
#
#    It's implemented here, because it has to do some caching
#    due to performance reasons.
#
# Arguments:
#
#     field - field's name
#
# Returns:
#
#    Array ref of hashes containing:
#
#    value - row's id
#    printableValue - field's printableValue
#
#    Example:
#    [{ 'value' => 'obj001', 'printableValue' => 'administration'}]
sub optionsFromForeignModel
{
    my ($self, $field, %params) = @_;
    unless (defined($field)) {
        throw EBox::Exceptions::MissingArgument("field's name")
    }

    my $filter = $params{filter};
    my $idsMethod = $params{noSyncRows} ? '_ids' : 'ids';

    my @options;
    for my $id (@{$self->$idsMethod()}) {
        my $row = $self->row($id);
        if ($filter) {
            if (not $filter->($row)) {
                next;
            }
        }
        push (@options, {
            'value'          => $id,
            'printableValue' => $row->printableValueByName($field)
           });
    }
    return \@options;
}

# Method: selectOptions
#
#    Override this method to return your select options
#    for the given select.
#
#       This method is *deprecated*. Use <EBox::Types::Select::populate>
#       callback to fill the select options.
#
# Arguments:
#
#     select - select's name
#
# Returns:
#
#    Array ref containing hash ref with value, printable
#    value and selected status
#
#    example:
#
#    [
#      { value => '1', printableValue => '1'},
#         { value => '2', printableValue => '2'}
#    ]
#
sub selectOptions
{
    throw EBox::Exceptions::DeprecatedMethod();
}

# Method: validateRow
#
#    Override this method to add your custom checks for
#    the table fields. The parameters are passed just like they are
#    received from the CGI. If you want to check on typed data use
#    <EBox::Model::DataTable::validateTypedRow> instead.
#
#    It will be called whenever a row is added/updated.
#
# Arguments:
#
#     action - String containing the action to be performed
#               after validating this row.
#               Current options: 'add', 'update'
#     params - hash ref containing fields names and their values
#
# Returns:
#
#    Nothing
#
# Exceptions:
#
#     You must throw an exception whenever a field value does not
#     fulfill your requirements
#
sub validateRow
{

}

# Method: validateTypedRow
#
#   Override this method to add your custom checks for
#   the table fields. The parameters are passed like data types.
#
#   It will be called whenever a row is added/updated.
#
#
# Arguments:
#
#   action - String containing the action to be performed
#            after validating this row.
#            Current options: 'add', 'update'
#
#   changedFields - hash ref containing the typed parameters
#                   subclassing from <EBox::Types::Abstract>
#                   that has changed, the key will be the field's name
#                   Also a key 'id' with the id of the row
#
#   allFields - hash ref containing the typed parameters
#               subclassing from <EBox::Types::Abstract> including changed,
#               the key is the field's name
#               Also a key 'id' with the id of the row
#
# Returns:
#
#   Nothing
#
# Exceptions:
#
#   You must throw an exception whenever a field value does not
#   fulfill your requirements
#
sub validateTypedRow
{

}

# Method: validateRowRemoval
#
#    Override this method to add your custom checks when
#    a row is to be removed
#
#    It will be called just before the a row is removed
#
#
# Arguments:
#
#     row - Row to be removed
#     force - whether the removal is force
#
# Returns:
#
#    Nothing
#
# Exceptions:
#
#     You must throw an exception whenever you think the removal
#     is not valid; this will abort it
sub validateRowRemoval
{

}

# Method: addedRowNotify
#
#    Override this method to be notified whenever
#    a new row is added
#
# Arguments:
#
#     row - <EBox::Model::Row> the new row to add
#
sub addedRowNotify
{

}

# Method: deletedRowNotify
#
#    Override this method to be notified whenever
#    a new row is deleted
#
# Arguments:
#
#     row - hash ref containing fields and values of the deleted
#     row. The same structure as <EBox::Model::DataTable::row>
#     return value
#
#    force - boolean indicating whether the delete is forced or not
#
#
sub deletedRowNotify
{

}

# Method: updatedRowNotify
#
#    Override this method to be notified whenever
#    a row is updated
#
# Arguments:
#
#   row - <EBox::Model::Row> row containing fields and values of the
#         updated row
#
#   oldRow - <EBox::Model::Row> row containing fields and values of the
#            updated row before modification
#
#   force - boolean indicating whether the delete is forced or not
#
sub updatedRowNotify
{

}

# Method: notifyForeignModelAction
#
#    This method is used to let models know when other model has
#    taken an action.
#
#    To be notified your table description must contain:
#    an entry 'notifyAction' => [ ModelName1, ModelName2]
#    where ModelName is the model you are interested of receiving
#    notifications.
#
#    If you are interested on some action on a module you should
#    override this method to take the actions you need on response to
#    the foreign module action
#
# Parameters:
#
#   (POSITIONAL)
#
#   model - model name where the action took place
#   action - string represting the action:
#            [ add, del, edit ]
#
#   row  - row modified
#
# Returns:
#
#   String - any i18ned String to inform the user about something that
#   has happened when the foreign model action was done in the current
#   model
#
sub notifyForeignModelAction
{
    return '';
}

# Method: addRow
#
#    Add a new row. This method should be used only by CGIs
#
# Parameters:
#
#    named parameters containing the expected fields for each row
#
# Returns:
#
#   just added row's id
#
sub addRow
{
    my ($self, %params) = @_;
    $self->validateRow('add', %params);

    my $userData = {};
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $data = $type->clone();
        $data->setMemValue(\%params);
        $userData->{$data->fieldName()} = $data;
    }

    return $self->addTypedRow($userData,
                              readOnly => $params{'readOnly'},
                              disabled => $params{'disabled'},
                              id => $params{'id'});
}

# Method: addTypedRow
#
#     Add a row with the instanced types as parameter
#
# Parameters:
#
#     params - hash ref containing subclasses from
#     <EBox::Types::Abstract> with content indexed by field name
#
#     readOnly - boolean indicating if the new row is read only or not
#     *(Optional)* Default value: false
#
#     disabled - boolean indicating if the new row is disabled or not
#     *(Optional)* Default value: false
#
#     id - String the possible identifier to set *(Optional)* Default
#     value: undef
#
# Returns:
#
#     String - the identifier for the given row
#
sub addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $dir = $self->{'directory'};
    my $confmod = $self->{'confmodule'};
    my $readOnly = delete $optParams{'readOnly'};
    $readOnly = 0 unless defined $readOnly;
    my $disabled = delete $optParams{'disabled'};
    $disabled = 0 unless defined $disabled;
    my $id = delete $optParams{'id'};

    unless (defined ($id) and length ($id) > 0) {
        $id = $self->_newId();
    }

    my $row = EBox::Model::Row->new(dir => $dir, confmodule => $confmod);
    $row->setReadOnly($readOnly);
    $row->setDisabled($disabled);
    $row->setModel($self);
    $row->setId($id);

    # Check compulsory fields
    $self->_checkCompulsoryFields($paramsRef);

    try {
        $self->_beginTransaction();

        my $checkRowUnique = $self->rowUnique();

        # Check field uniqueness if any
        my @userData = ();
        my $userData = {};
        while ( my ($paramName, $param) = each (%{$paramsRef})) {
            # Check uniqueness
            if ($param->unique()) {
                # No need to check if the entire row is unique if
                # any of the fields are already checked
                $checkRowUnique = 0;

                $self->_checkFieldIsUnique($param);
            }
            push(@userData, $param);
            $row->addElement($param);
        }

        unless ($optParams{noValidateRow}) {
            $self->validateTypedRow('add', $paramsRef, $paramsRef);
        }

        # Check if the new row is unique, only if needed
        if ($checkRowUnique) {
            $self->_checkRowIsUnique(undef, $paramsRef);
        }

        my $hash = {};
        foreach my $data (@userData) {
            $data->storeInHash($hash);
            $data = undef;
        }

        unless ($optParams{noOrder}) {
            # Insert the element in order
            if ($self->table()->{'order'}) {
                my $pos = 0;
                my $insertPos = $self->insertPosition();
                if (defined($insertPos)) {
                    if ( $insertPos eq 'front' ) {
                        $pos = 0;
                    } elsif ( $insertPos eq 'back' ) {
                        $pos = $#{$self->order()} + 1;
                    }
                }
                $self->_insertPos($id, $pos);
            } else {
                my $order = $confmod->get_list($self->{'order'});
                push (@{$order}, $id);
                $confmod->set($self->{'order'}, $order);
            }
        }

        if ($readOnly) {
            $hash->{readOnly} = 1;
        }
        if ($disabled) {
            $hash->{disabled} = 1;
        }

        $confmod->set("$dir/$id", $hash);

        my $newRow = $self->row($id);

        $self->setMessage($self->message('add'));
        $self->addedRowNotify($newRow);
        $self->_notifyManager('add', $newRow);

        $self->_commitTransaction();
    } catch ($e) {
        $self->_rollbackTransaction();
        if (Scalar::Util::blessed($e) and $e->isa('EBox::Exceptions::Base')) {
            $e->throw();
        } else {
            die $e;
        }
    }

    return $id;
}

# Method: row
#
#    Return a given row
#
# Parameters:
#
#     id - row id
#
# Returns:
#
#   An object of  <EBox::Model::Row>
#
sub row
{
    my ($self, $id)  = @_;

    my $dir = $self->{'directory'};
    my $confmod = $self->{'confmodule'};
    my $row = EBox::Model::Row->new(dir => $dir, confmodule => $confmod);

    unless (defined($id) and $self->_rowExists($id)) {
        return undef;
    }

    $self->{'cacheOptions'} = {};

    $row->setId($id);
    my $hash = $confmod->get_hash("$dir/$id");

    my $disabled = $hash->{'disabled'};
    $disabled = 0 unless defined $disabled;

    my $readOnly = $hash->{'readOnly'};
    $readOnly = 0 unless defined $readOnly;

    $row->setReadOnly($readOnly);
    $row->setDisabled($disabled);
    $row->setModel($self);

    # If element is volatile we set its value after the rest
    # of the table elements are set, as it's typical to have
    # volatile values calculated from other values of the row
    my @volatileElements;
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $element = $type->clone();
        if ($element->volatile()) {
            push (@volatileElements, $element);
        } else {
            _setRowElement($element, $row, $hash);
        }
        $row->addElement($element);
    }
    foreach my $element (@volatileElements) {
        _setRowElement($element, $row, $hash);
    }

    return $row;
}

sub _setRowElement
{
    my ($element, $row, $hash) = @_;

    $element->setRow($row);
    $element->restoreFromHash($hash);
    if ((not defined($element->value())) and $element->defaultValue()) {
        $element->setValue($element->defaultValue());
    }
}

# Method: isRowReadOnly
#
#     Given a row it returns if it is read-only or not
#
# Parameters:
#     (POSITIONAL)
#
#     id - row's id
#
# Returns:
#
#     boolean - true if it is read-only, otherwise false
#
sub isRowReadOnly
{
    my ($self, $id) = @_;

    my $row = $self->row($id);
    return undef unless ($row);

    return $row->{'readOnly'};
}

# Method: isRowDisabled
#
#   Given a row it returns if it is disabled or not
#
# Parameters:
#
#   id - The row id
#
# Returns:
#
#   boolean - true if the row is disabled, false otherwise
#
sub isRowDisabled
{
    my ($self, $id) = @_;

    my $row = $self->row($id);
    return undef unless $row;

    return $row->{'disabled'};
}

sub _selectOptions
{
    my ($self, $field) = @_;

    my $cached = $self->{'cacheOptions'}->{$field};

    $self->{'cacheOptions'}->{$field} = $self->selectOptions($field);
    return $self->{'cacheOptions'}->{$field};
}

# Method: moveRowRelative
#
#  Moves the row to the position specified either by the previous row or the
#  next one. If both positions are suppiled the previous row has priority
#
#  Parameters:
#     id - id of row to move
#     prevId - ID of the row directly after the new position, undef if unknow
#     nextId - ID of the row directly before the new position, undef if unknow
#
#    Returns:
#       - list reference contianing the old row position and the new one
#
sub moveRowRelative
{
    my ($self, $id, $prevId, $nextId) = @_;
    if ((not $prevId) and (not $nextId)) {
        throw EBox::Exceptions::MissingArgument("No changes were supplied");
    }
    if ($prevId) {
        if (($id eq $prevId)) {
            throw EBox::Exceptions::MissingArgument("id and prevId must be different ids (both were '$id')");
        } elsif ($nextId and ($prevId eq $nextId)) {
            throw EBox::Exceptions::MissingArgument("nextId and prevId must be different ids (both were '$nextId')");
        }
    }
    if ($nextId and ($id eq $nextId)) {
        throw EBox::Exceptions::MissingArgument("id and nextId must be different ids (both were '$id')");
    }

    my $oldPos = $self->removeIdFromOrder($id);
    # lokup new positions
    my $newPos;

    if (defined $prevId) {
         $newPos = $self->idPosition($prevId) + 1;
     } elsif (defined $nextId) {
         $newPos = $self->idPosition($nextId);
     }

    if (not defined $newPos) {
        $self->_insertPos($id, 0); # to not lose the element
        throw EBox::Exceptions::Internal("No new position was found for id $id between $prevId and $nextId");
    }

    $self->_insertPos($id, $newPos);

    $self->_notifyManager('move', $self->row($id));
    return [$oldPos => $newPos];
}

# Method: _removeRow
#
#    Removes a row in the configuration backend, override it when removing
#    a row stored in other places
#
# Parameters:
#
#     'id' - row id
#
sub _removeRow
{
    my ($self, $id) = @_;

    my $confmod = $self->{'confmodule'};
    $confmod->delete_dir("$self->{'directory'}/$id");
    $self->removeIdFromOrder($id);
}

# TODO Split into removeRow and removeRowForce
#

# Method: removeRow
#
#    Remove a row
#
# Parameters:
#
#    (POSITIONAL)
#
#     'id' - row id
#    'force' - boolean to skip integrations checks of the row to remove
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - throw if any mandatory
#       argument is missing
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove")
    }

    try {
        $self->_beginTransaction();

        # If force != true and automaticRemove is enabled it means
        # the model has to automatically check if the row which is
        # about to removed is referenced elsewhere. In that
        # case throw a DataInUse exceptions to iform the user about
        # the effects its actions will have.
        if ((not $force) and $self->table()->{'automaticRemove'}) {
            my $manager = EBox::Model::Manager->instance();
            $manager->warnIfIdIsUsed($self->contextName(), $id);
        }

        $self->_checkRowExist($id, '');
        my $row = $self->row($id);
        $self->validateRowRemoval($row, $force);

        $self->_removeRow($id);

        my $userMsg = $self->message('del');
        # Dependant models may return some message to inform the user
        my $depModelMsg = $self->_notifyManager('del', $row);
        $self->_notifyManager('del', $row);
        if (defined($depModelMsg) and $depModelMsg ne '' and $depModelMsg ne '<br><br>') {
            $userMsg .= "<br><br>$depModelMsg";
        }
        # If automaticRemove is enabled then remove all rows using referencing
        # this row in other models
        if ($self->table()->{'automaticRemove'}) {
            my $manager = EBox::Model::Manager->instance();
            $depModelMsg = $manager->removeRowsUsingId($self->contextName(),
                    $id);
            if (defined( $depModelMsg ) and $depModelMsg ne '' and $depModelMsg ne '<br><br>') {
                $userMsg .= "<br><br>$depModelMsg";
            }
        }

        $self->setMessage($userMsg);
        $self->deletedRowNotify($row, $force);

        $self->_commitTransaction();
    } catch ($e) {
        $self->_rollbackTransaction();
        $e->throw();
    }
}

# Method: removeAll
#
#       Remove every data inside a model
#
# Parameters:
#
#       force - boolean force the operation *(Optional)* Default value: false
#
sub removeAll
{
    my ($self, $force) = @_;
    $force = 0 unless defined ($force);

    foreach my $id (@{$self->_ids(1)}) {
        $self->removeRow($id, $force);
    }
}

# Method: warnIfIdUsed
#
#    This method must be overriden in case you want to warn the user
#    when a row is going to be deleted. Note that models manage this
#    situation automatically, this method is intended for situations
#    where the use of the model is done in a non-standard way.
#
#    Override this method and raise a <EBox::Exceptions::DataInUse>
#    excpetions to warn the user
#
# Parameters:
#
#    (POSITIONAL)
#
#       'modelName' - String the observable model's name
#     'id' - String row id
#
sub warnIfIdUsed
{

}

# Method: warnOnChangeOnId
#
#       This method must be overriden in case you want to advise the
#       Zentyal user about the change on a observable model. Note that
#       models manage this situation automatically if you are using
#       <EBox::Types::Select> or <EBox::Types::HasMany> types. This
#       method is intended to be used by models which use
#       'notifyActions' attribute to be warned on other model's
#       change.
#
# Parameters:
#
#    (NAMED)
#
#     'modelName' - String the observable model's name
#
#     'id' - String row id
#
#     'changedData' - hash ref of data types which are going to be
#                    changed
#
#     'oldRow' - <EBox::Model::Row> the old row content
#
# Returns:
#
#     A i18ned string explaining what happens if the requested action
#     takes place
sub warnOnChangeOnId
{

}

# Method: isIdUsed
#
#       This method must be overriden in any case you want to
#       notify you are using a row from another model. This is only
#       intended for those models that are using 'notifyactions'
#       in the module schema. In any other case, the framework
#       is in charge
#
# Positional parameters:
#
#    modelName - String model's name
#    id        - String the row id
#
# Returns:
#
#    Boolean - indicating whether the id from that model is used or not
#
sub isIdUsed
{
    return 0;
}

# Method: setRow
#
#    Set an existing row. It should be used only by CGIs
#
# Parameters:
#
#    named parameters containing the expected fields for each row
sub setRow
{
    my ($self, $force, %params) = @_;

    my $id = delete $params{'id'};
    $self->_checkRowExist($id, '');

    $self->validateRow('update', @_);

    # We can only set those types which have setters
    my @newValues = @{$self->setterTypes()};

    my $changedData;
    for (my $i = 0; $i < @newValues ; $i++) {
        my $newData = $newValues[$i]->clone();
        $newData->setMemValue(\%params);

        $changedData->{$newData->fieldName()} = $newData;
    }

    $self->setTypedRow( $id, $changedData,
                        force => $force,
                        readOnly => $params{'readOnly'},
                        disabled => $params{'disabled'});
}

# Method: setTypedRow
#
#      Set the values for a single existing row using typed parameters
#
# Parameters:
#
#      id - String the row identifier
#
#      paramsRef - hash ref Containing the parameter to set. You can
#      update your selected values. Indexed by field name.
#
#      force - Boolean indicating if the update is forced or not
#      *(Optional)* Default value: false
#
#      readOnly - Boolean indicating if the row becomes a read only
#      kind one *(Optional)* Default value: false
#
#      disabled - Boolean indicating if the row is disabled in the UI.
#                 *(Optional)* Default value: false
#
#     - Optional parameters are NAMED
#
# Exceptions:
#
#      <EBox::Exceptions::Base> - thrown if the update cannot be done
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $force = delete $optParams{'force'};
    my $readOnly = delete $optParams{'readOnly'};
    $readOnly = 0 unless defined $readOnly;
    my $disabled = delete $optParams{'disabled'};
    $disabled = 0 unless defined $disabled;

    $self->_checkRowExist($id, '');

    my $dir = $self->{'directory'};
    my $confmod = $self->{'confmodule'};

    my @setterTypes = @{$self->setterTypes()};

    try {
        $self->_beginTransaction();

        my $checkRowUnique = $self->rowUnique();

        my $row = $self->row($id);
        my $oldRow = $self->_cloneRow($row);
        my $allHashElements = $row->hashElements();
        my $changedElements = {};
        my @changedElements = ();
        foreach my $paramName (keys %{$paramsRef}) {
            unless ($paramName ne any(@setterTypes)) {
                throw EBox::Exceptions::Internal('Trying to update a non setter type');
            }

            my $paramData = $paramsRef->{$paramName};
            if ($row->elementByName($paramName)->isEqualTo($paramsRef->{$paramName})) {
                next;
            }

            if ($paramData->unique()) {
                # No need to check if the entire row is unique if
                # any of the fields are already checked
                $checkRowUnique = 0;
                $self->_checkFieldIsUnique($paramData);
            }

            $paramData->setRow($row);
            $changedElements->{$paramName} = $paramData;
            push (@changedElements, $paramData);
            $allHashElements->{$paramName} = $paramData;
        }

        # Check if the new row is unique if needed
        if ($checkRowUnique and (keys %{$paramsRef} > 0)) {
            $self->_checkRowIsUnique($id, $allHashElements);
        }

        # add ids parameters for call to validateTypedRow
        $changedElements->{id} = $id;
        $allHashElements->{id} = $id;
        $self->validateTypedRow('update', $changedElements, $allHashElements, $force);
        # remove ids after call to validateTypedRow
        delete $changedElements->{id};
        delete $allHashElements->{id};

        # If force != true automaticRemove is enabled it means
        # the model has to automatically check if the row which is
        # about to be changed is referenced elsewhere and this change
        # produces an inconsistent state
        if ((not $force) and $self->table()->{'automaticRemove'}) {
            my $manager = EBox::Model::Manager->instance();
            my $contextName = $self->contextName();
            # remove begining and trailing '/' for context name
            $contextName =~ s{^/}{};
            $contextName =~ s{/$}{};
            $manager->warnOnChangeOnId($contextName, $id, $changedElements, $oldRow);
        }

        my $key = "$dir/$id";
        my $hash = $confmod->get_hash($key);

        my $modified = @changedElements;
        for my $data (@changedElements) {
            $data->storeInHash($hash);
        }

        # update readonly if change
        my $oldRO = $hash->{readOnly};
        if (defined ($readOnly) and $readOnly) {
            $hash->{readOnly} = 1;
        } else {
            delete $hash->{readOnly};
        }

        # Update disabled if change
        my $oldDisabled = $hash->{disabled};
        if (defined $disabled and $disabled) {
            $hash->{disabled} = 1;
        } else {
            delete $hash->{disabled};
        }

        # Update row hash if needed
        if ($modified or ($hash->{readOnly} xor $oldRO) or
            ($hash->{disabled} xor $oldDisabled)) {
            $confmod->set($key, $hash);
        }

        $self->setMessage($self->message('update'));
        # Dependant models may return some message to inform the user
        my $depModelMsg = $self->_notifyManager('update', $row);
        if (defined ($depModelMsg)
                and ($depModelMsg ne '' and $depModelMsg ne '<br><br>')) {
            $self->setMessage($self->message('update') . '<br><br>' . $depModelMsg);
        }
        $self->_notifyManager('update', $row);
        $self->updatedRowNotify($row, $oldRow, $force);

        $self->_commitTransaction();
    } catch ($e) {
        $self->_rollbackTransaction();
        throw $e;
    }
}

# Method: enabledRows
#
#       Returns those row ids that are enabled, that is, those whose
#       field 'enabled' is set to true. If there is no enabled field,
#       all rows are returned.
#
# Returns:
#
#       Array ref containing the row ids
#
sub enabledRows
{
    my ($self) = @_;

    my $fields = $self->fields();
    unless (grep { $_ eq 'enabled' } @{$fields}) {
        return $self->ids();
    }

    my @rows = @{$self->ids()};
    @rows = grep { $self->row($_)->valueByName('enabled') } @rows;
    return \@rows;
}

# Method: size
#
#      Determine the size (in number of rows) from a model
#
# Returns:
#
#      Int - the number of rows which the model contains
#
sub size
{
    my ($self) = @_;

    return scalar(@{$self->ids()});
}

# Method: syncRows
#
#   This method might be useful to add or remove rows before they
#   are presented. In that case you must override this method.
#
#   Warning: You should never call <EBox::Model::DataTable::ids>
#   within this function or you will enter into a deep recursion
#
# Parameters:
#
#   (POSITIONAL)
#
#   currentIds - array ref containing the current row indentifiers
#
# Returns:
#
#   boolean - true if the current rows have been modified, i.e: there's
#   been a row addition or row removal
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    return 0;
}

# Method: ids
#
#
#   Return an array containing the identifiers of each  table row.
#   The ids are ordered by the field specified by the model.
#
#   This method will call <EBox::Model::DataTable::syncRows>
#
# Returns:
#
#   array ref - containing the ids
#
sub ids
{
    my ($self) = @_;

    my $currentIds = $self->_ids();
    my $changed = 0;

    unless ($self->{'confmodule'}->isReadOnly()) {
        my $modAlreadyChanged = $self->{'confmodule'}->changed();

        try {
            $self->_beginTransaction();

            my $msgBeforeSyncRows = $self->message();
            $changed = $self->syncRows($currentIds);
            if ($changed) {
                # restore any previous message, hiding any message caused by
                # sync Rows
                $self->setMessage($msgBeforeSyncRows);

                if (not $modAlreadyChanged) {
                    # save changes but don't mark it as changed
                    $self->{confmodule}->_saveConfig();
                    $self->{confmodule}->setAsChanged(0);
                }
            }

            $self->_commitTransaction();
        } catch ($e) {
            $self->_rollbackTransaction();
            $e->throw();
        }
    }

    if ($changed) {
        return $self->_ids();
    } else {
        return $currentIds;
    }
}

# Method: customFilterIds
#
#       Return Ids filtered by the string that is passed
#
#       You must enable the 'customFilter' property in your table description.
#
#       When should I use this?
#
#       Use this option when you have model where you override ids() and row(),
#       and the amount of rows you can potentially have is big > ~ 4000 entries.
#
#       This is useful to speed up filter searches. If you don't this, the
#       automatic filter mechanism of models will be to slow.
#
#       This is also useful when you want to take advantage of the search system
#       of your backend data. For example, if you are mapping data from an LDAP,
#       you can use this feature to carry out searches using the LDAP protocol.
#
# Parameters:
#
#   filter string
#
# Returns:
#
#   Array ref of ids
sub customFilterIds
{
    throw EBox::Exceptions::NotImplemented('customFilterIds');
}

# Method: _ids
#
#   (PROTECTED)
#
#   Return an array containing the identifiers of each  table row.
#   The ids are ordered by the field specified by the model
#
# Returns:
#
#   array ref - containing the ids
#
sub _ids
{
    my ($self, $notOrder) =  @_;
    my $confmod = $self->{'confmodule'};

    my $ids = $confmod->get_list($self->{'order'});

    unless ($notOrder) {
        my $sortedBy = $self->sortedBy();
        if (@{$ids} and $sortedBy) {
            my %idsToOrder;
            for my $id (@{$ids}) {
                $idsToOrder{$id} = $self->row($id)->printableValueByName($sortedBy);
            }
            $ids = [
                sort {
                    (lc $idsToOrder{$a} cmp lc $idsToOrder{$b}) or
                     ($idsToOrder{$a} cmp $idsToOrder{$b})
                } keys %idsToOrder

               ];

            my $global = EBox::Global->getInstance();
            my $modChanged = $global->modIsChanged($confmod->name());
            if (not $confmod->isReadOnly() and (@{$ids} and $modChanged)) {
                $confmod->set_list($self->{'order'}, 'string', $ids);
            }
        }
    }
    return $ids;
}

sub _rows
{
    my ($self) = @_;

    my @rows = map { $self->row($_) } @{$self->_ids()};
    return \@rows;
}

# Method: setTableName
#
#    Use this method to set the current table name. This method
#    comes in handy to manage several tables with same model
#
# Parameters:
#
#     tablename - string containing the name
#
sub setTableName
{
    my ($self, $name) = @_;

    unless ($name) {
        throw Exceptions::MissingArgument('name');
    }

    $self->{'tablename'} = $name;
}

# Method: setDirectory
#
#    Use this method to set the current directory. This method
#    comes in handy to manage several tables with same model
#
# Parameters:
#
#     directory - string containing the name
#
sub setDirectory
{
    my ($self, $dir) = @_;

    unless ($dir) {
        throw EBox::Exceptions::MissingArgument('dir');
    }

    my $olddir = $self->{'confdir'};
    if (defined $olddir and ($dir eq $olddir)) {
        # no changes
        return;
    }

    $self->{'confdir'} = $dir;
    $self->{'directory'} = "$dir/keys";
    $self->{'order'} = "$dir/order";
    $self->{'table'}->{'confdir'} = $dir;
}

# Method: tableName
#
#        Get the table name associated to this model
#
# Returns:
#
#        String - containing the table name
#
sub tableName
{
    my ($self) = @_;

    return $self->table()->{'tableName'};
}

# Method: printableModelName
#
#       Get the i18ned model name
#
# Returns:
#
#       String - the localisated model name
#
sub printableModelName
{
    my ($self) = @_;

    return $self->table()->{'printableTableName'};
}

# Method: pageTitle
#
#       Get the i18ned name of the page where the model is contained, if any
#
# Returns:
#
#   string
#
sub pageTitle
{
    my ($self) = @_;

    return $self->table()->{'pageTitle'};
}

# Method: directory
#
#        Get the current directory. This method is handy to manage
#        several tables with the same model
#
# Returns:
#
#        String - Containing the directory
#
sub directory
{
    my ($self) = @_;

    return $self->{'confdir'};
}

# Method: order
#
#     Get the keys order in an array ref
#
# Returns:
#
#     array ref - the key order where each element is the key
#     identifier
#
sub order
{
    my ($self) = @_;

    return $self->{'confmodule'}->get_list( $self->{'order'} );
}

# Method: insertPosition
#
#     Get the insert order position. It makes sense only if the table
#     is ordered, that is, the order field is set.
#
#     Default value: front
#
# Returns:
#
#     'back' - if the element is inserted at the end of the model
#
#     'front' - so the element is inserted at the beginning of the model
#
sub insertPosition
{
    my ($self) = @_;

    return $self->table()->{'insertPosition'};
}

# Method: rowUnique
#
#     Get if the model must have each row different
#
# Returns:
#
#     true  - if each row is unique
#     false - otherwise
#
sub rowUnique
{
    my ($self) = @_;

    return $self->table()->{'rowUnique'};
}

# Method: action
#
#       Accessor to the URLs where the actions are published to be
#       run.
#
# Parameters:
#
#       actionName - String the action name
#
# Returns:
#
#       String - URL where the action will be called
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - thrown if the action name
#       has not defined action
#
sub action
{
    my ($self, $actionName) = @_;

    my $actionsRef = $self->table()->{actions};

    if ( exists ($actionsRef->{$actionName}) ){
        return $actionsRef->{$actionName};
    } else {
        throw EBox::Exceptions::DataNotFound( data => __('Action'),
                value => $actionName);
    }
}

sub _setupCustomActions
{
    my ($self, $id) = @_;

    my $customActions = $self->{'table'}->{'customActions'};
    if ($customActions) {
        # Store the custom actions in a list to access in order
        my @customActionsList = map { $_->action($id) } @{ $customActions };
        # Store the custom actions in a hash to access by name
        my %customActionsHash = map { $_->name() => $_ } @customActionsList;
        $self->{'customActionsList'} = \@customActionsList;
        $self->{'customActionsHash'} = \%customActionsHash;
        $self->_setCustomMessages(\@customActionsList, $id);
    }
}

# Method: customActions
#
#       Obtains the definition of the custom actions
#
# Returns:
#
#       Array ref - List of <EBox::Types::Action>
#
sub customActions
{
    my ($self, $action, $id) = @_;

    $self->_setupCustomActions($id);

    if ($action) {
        return undef unless $self->{table}->{customActions};
        return $self->{customActionsHash}->{$action};
    } else {
        return [] unless $self->{table}->{customActions};
        return $self->{customActionsList};
    }
}

# Method: printableRowName
#
#     Get the printable row name
#
# Returns:
#
#     String - containing the i18n name for the row
#
sub printableRowName
{
    my ($self) = @_;

    return $self->table()->{'printableRowName'};
}

# Method: menuNamespace
#
#    Fetch the menu namespace which this model belongs to
#
# Returns:
#
#        String - Containing namespace
#
sub menuNamespace
{
    my ($self) = @_;

    if (exists $self->table()->{'menuNamespace'}) {
        return $self->table()->{'menuNamespace'};
    } elsif (defined ($self->modelDomain())) {
        # This is autogenerated menuNamespace got from the model
        # domain and the table name
        my $menuNamespace = $self->modelDomain() . '/View/' . $self->modelName();
        return $menuNamespace;
    } else {
        return undef;
    }
}

# Method: help
#
#     Get the help message from the model
#
# Returns:
#
#     String - containing the i18n help message
#
sub help
{
    my ($self) = @_;

    return $self->table()->{'help'};
}

# Method: message
#
#     Get a message depending on the action parameter
#
#     Current actions are:
#
#      add - when a row is added
#      del - when a row is deleted
#      update - when a row is updated
#
# Parameters:
#
#     action - String the action from where to get the message. There
#     are one default message per action. If the action is undef
#     returns the current message to show. *(Optional)* Default value:
#     undef
#
# Returns:
#
#     String - the message to show
#
sub message
{
    my ($self, $action) = @_;

    if ( defined ( $action ) ) {
        return $self->table()->{'messages'}->{$action};
    } else {
        return $self->table()->{'message'};
    }
}

sub messageClass
{
    my ($self, $action) = @_;
    return $self->table()->{'messageClass'} or 'note';
}

# Method: popMessage
#
#     Get the message to show and *delete* it afterwards.
#
# Returns:
#
#     String - the message to show
#
sub popMessage
{
    my ($self) = @_;

    my $msg = $self->message();
    $self->setMessage('');

    return $msg;
}

# Method: setMessage
#
#     Set the message to show the user
#
# Parameters:
#
#     newMessage - String the new message to show
#
sub setMessage
{
    my ($self, $newMessage, $messageClass) = @_;

    $self->table()->{'message'} = $newMessage;
    $self->table()->{'messageClass'} = $messageClass if ($messageClass);
}

# Method: modelDomain
#
#     Get the domain where the model is handled. That is, the eBox
#     module which the model belongs to
#
# Returns:
#
#     String - the model domain, the first letter is upper-case
#
sub modelDomain
{
    my ($self) = @_;

    return $self->{'table'}->{'modelDomain'};
}

# Method: fields
#
#     Return a list containing the fields which compose each row
#
# Returns:
#
#    Array ref containing the fields
sub fields
{
    my ($self) = @_;

    if ($self->{'fields'}) {
        return $self->{'fields'};
    }

    unless (defined($self->table()->{'tableDescription'})) {
        throw EBox::Exceptions::Internal('Table description not defined');
    }

    my @tableHead = @{$self->table()->{'tableDescription'}};
    my @tableFields = map { $_->{'fieldName'} } @tableHead;

    $self->{'fields'} = \@tableFields;

    return \@tableFields;
}

# Method: fieldsWithUndefSetter
#
#    Return a hash containing the fields which compose each row
#    and dont have a defined Setter
#
# Returns:
#
#    Hash ref containing the field names as keys
#
sub fieldsWithUndefSetter
{
    my ($self) = @_;

    unless (defined($self->table()->{'tableDescription'})) {
        throw Excepetions::Internal('table description not defined');
    }

    my @tableHead = @{$self->table()->{'tableDescription'}};
    my %tableFields;
    for my $type (@tableHead) {
        $tableFields{$type->fieldName()} = 1 unless $type->HTMLSetter();
    }

    return \%tableFields;
}

# Method: setterTypes
#
#     Return a list containing those fields which have defined setters
#
# Returns:
#
#    Array ref containing the fields
sub setterTypes
{
    my ($self) = @_ ;

    unless (defined($self->table()->{'tableDescription'})) {
        throw Exceptions::Internal('table description not defined');
    }

    my @tableHead = @{$self->table()->{'tableDescription'}};
    my @types =  grep { defined($_->HTMLSetter) } @tableHead;

    return \@types;
}

# Method: setFilter
#
#     Set the the string used to filter the return of rows
#
# Parameters:
#    (POSITIONAL)
#    filter - string containing the filter
#
sub setFilter
{
    my ($self, $filter) = @_;
    $self->{'filter'} = $filter;
}

# Method: filter
#
#    Return the string used to filter the return of rows
#
# Returns:
#
#    string - containing the value
sub filter
{
    my ($self) = @_;
    return $self->{'filter'};
}

# Method: find
#
#    Return the first row which matches the value of the given
#    field against the data returned by the method printableValue()
#
#    If you want to match against value use
#    <EBox::Model::DataTable::findValue>
#
# Parameters:
#
#     fieldName => value
#
#     Example:
#
#     find('default' => 1);
#
# Returns:
#
#     <EBox::Model::Row> - The matched row
#
#     undef - if there was not any match
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub find
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name");
    }

    my @matched = @{$self->_find({ $fieldName => $value }, undef, 'printableValue')};

    if (@matched) {
        return $self->row($matched[0]);
    } else {
        return undef;
    }
}

# Method: findAll
#
#    Return all the id rows that match the value of the given
#    field against the data returned by the method printableValue()
#
#    If you want to match against value use
#    <EBox::Model::DataTable::findValue>
#
# Parameters:
#
#     fieldName => value
#
#     Example:
#
#     findAll('default' => 1);
#
# Returns:
#
#     Array ref of ids which reference to the matched
#     rows (<EBox::Model::Row>)
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findAll
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name");
    }

    my @matched = @{$self->_find({ $fieldName => $value }, 1, 'printableValue')};

    return \@matched;
}

# Method: findValue
#
#    Return the first row that matches the value of the given
#    field against the data returned by the method value()
#
#    If you want to match against printable value use
#    <EBox::Model::DataTable::find>
# Parameters:
#
#     fieldName => value
#
#     Example:
#
#     findValue('default' => 1);
#
# Returns:
#
#     <EBox::Model::Row> - the matched row
#
#     undef if there was not any match
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findValue
{
    my ($self, $fieldName, $value, $nosync) = @_;

    $self->findValueMultipleFields({ $fieldName => $value }, $nosync);
}

# Method: findValueMultipleFields
#
#    Return the first row that matches the value of the given
#    fields against the data returned by the method value()
#
#    If you want to match against printable value use
#    <EBox::Model::DataTable::find>
# Parameters:
#
#     fields     - hash ref with the fields and values to look for
#
#     Example:
#
#     findValueMultipleFields({'default' => 1});
#
# Returns:
#
#     <EBox::Model::Row> - the matched row
#
#     undef if there was not any match
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findValueMultipleFields
{
    my ($self, $fields, $nosync) = @_;

    my @matched = @{$self->_find($fields, undef, 'value', $nosync)};

    if (@matched) {
        return $self->row($matched[0]);
    } else {
        return undef;
    }
}

# Method: findAllValue
#
#    Return all the rows that match the value of the given
#    field against the data returned by the method value()
#
#    If you want to match against printable value use
#    <EBox::Model::DataTable::find>
#
#
# Parameters:
#
#     fieldName => value
#
#     Example:
#
#     findAllValue('default' => 1);
#
# Returns:
#
#     An array ref of ids that reference matched rows
#     (<EBox::Model::Row>)
#
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findAllValue
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name");
    }

    my @matched = @{$self->_find({ $fieldName => $value }, 1, 'value')};

    return \@matched;
}

# Method: findId
#
#    Return the first row identifier which matches the value of the
#    given field against the data returned by the method value() or
#    the method printableValue()
#
# Parameters:
#
#    fieldName => value
#
#    Example:
#
#    findId('default' => 1);
#
# Returns:
#
#    String - the row identifier from the first matched rule
#
#    undef - if there was not any match
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findId
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name");
    }

    my $values = { $fieldName => $value };
    my @matched = @{$self->_find($values, undef, 'value')};
    if (@matched) {
        return $matched[0];
    } else {
        @matched = @{$self->_find($values, undef, 'printableValue')};
        return @matched ? $matched[0] : undef;
    }
}

# Method: findRow
#
#    Return the first row that matches the value of the given field
#    against the data returned by the method printableValue() or
#    method value()
#
# Parameters:
#
#     fieldName => value
#
#     Example:
#
#     findRow('default' => 1);
#
# Returns:
#
#    <EBox::Model::Row> - the row from the first matched rule
#
#    undef - if there was not any match
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub findRow
{
    my ($self, $fieldName, $value) = @_;

    unless (defined($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name");
    }

    my $id = $self->findId($fieldName, $value);

    if ( defined($id) ) {
        return $self->row($id);
    } else {
        return undef;
    }
}

# Method: _HTTPUrlView
#
#   Returns the HTTP URL base used to get the view for this model
#
sub _HTTPUrlView
{
    my ($self) = @_;

    return $self->table()->{'HTTPUrlView'};
}

# Method: HTTPLink
#
#   The HTTP URL base + directory parameter to get the view for this
#   model
#
# Returns:
#
#   String - the URL to link
#
#   '' - if the _HTTPUrlView is not defined to a non-zero string
#
sub HTTPLink
{
    my ($self) = @_;

    if ( $self->_HTTPUrlView() ) {
        my $link = '/' . $self->_HTTPUrlView();
        my $parentRow = $self->parentRow();
        if ($parentRow) {
            $link .= '?directory=' . $self->directory();
        }
        return $link;
    } else {
        return "";
    }
}

sub DESTROY { ; }

# Method: AUTOLOAD
#
#       Autoload function called whenever a method is undefined for
#       this class.
#
#       We use it to generate an automatic add/del/set/get methods to
#       data models. The methods will follow these patterns:
#
#       - Addition
#
#          - add[<tableName>]( property1 => value1,
#                            property2 => value2,.. )
#
#          - add<submodelFieldName>To<tableName>( indexValue, property1 => value1, property2 =>
#          value2,.. )
#
#          - add<submodel2FieldName>To<submodel1FieldName>To<tableName> (
#          indexValue, indexSubModel1, property1 => value1, property2 =>
#          value2,.. )
#
#       - Removal
#
#          - del[<tableName>]( indexValue )
#
#          - del<subModelFieldName>To<tableName>( indexValue,
#          indexSubModel1 );
#
#          - del<subModel2FieldName>To<subModel1FieldName>To<tableName>( indexValue,
#          indexSubModel1, indexSubModel2 );
#
#       - Access
#
#          - get[<tableName>]( indexValue[, [ field1, field2, ... ]]);
#
#          - get<subModelFieldName>To<tableName>( indexValue,
#          indexSubModel1[, [ field1, field2, ... ]]);
#
#          - get<subModel2FieldName>To<subModel1FieldName>To<tableName>( indexValue,
#          indexSubModel1, indexSubModel2[, [ field1, field2, ... ]]);
#
#          All methods return the same data as
#          <EBox::Model::DataTable::row> method does except if one
#          field is requested when just one type is returned. In order
#          to make queries about multiple rows, use
#          <EBox::Model::DataTable::ids>,
#          <EBox::Model::DataTable::findAll> methods or similars.
#
#       - Update
#
#          - set[<tableName>] ( indexValue, property1 => value1,
#          property2 => value2, ... );
#
#          - set<subModelFieldName>To<tableName>( indexValue,
#          indexSubModel1, property1 => value1, property2 => value2,
#          ...);
#
#          - set<subModel2FieldName>To<subModel1FieldName>To<tableName>(
#          indexValue, indexSubModel1, indexSubModel2, property1 =>
#          value1, property2 => value2, ...);
#
#    The indexes are unique fields from the data models. If there is
#    none, the identifier may be used. The values can be multiple
#    using array references.
#
# Returns:
#
#    String - the newly added row identifier if the AUTOLOAD method is
#             an addition
#
#    <EBox::Model::Row> - if the AUTOLOAD method is a getter and it
#    returns a single row
#
#    <EBox::Types::Abstract> - if the AUTOLOAD method is a getter and
#    it returns a single field from a row
#
#    Array ref - if the AUTOLOAD method is a getter and it returns
#    more than one row. Each component is a <EBox::Model::Row>.
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if no valid pattern was
#    used
#
#    <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#    argument is missing
#
sub AUTOLOAD
{
    my ($self, @params) = @_;

    my $methodName = our $AUTOLOAD;

    $methodName =~ s/.*:://;

    unless ( UNIVERSAL::can($self, '_autoloadAdd') ) {
        use Devel::StackTrace;
        my $trace = new Devel::StackTrace();
        EBox::debug($trace->as_string());
        throw EBox::Exceptions::Internal("Not valid autoload method $methodName since "
                                         . "$self is not a EBox::Model::DataTable");
    }

    # Depending on the method name beginning, the action to be
    # performed is selected
    if ( $methodName =~ m/^add/ ) {
        return $self->_autoloadAdd($methodName, \@params);
    } elsif ( $methodName =~ m/^del/ ) {
        return $self->_autoloadDel($methodName, \@params);
    } elsif ( $methodName =~ m/^get/ ) {
        return $self->_autoloadGet($methodName, \@params);
    } elsif ( $methodName =~ m/^set/ ) {
        return $self->_autoloadSet($methodName, \@params);
    } else {
        use Devel::StackTrace;
        my $trace = new Devel::StackTrace();
        EBox::debug($trace->as_string());
        throw EBox::Exceptions::Internal("Not valid autoload method $methodName for " .
                ref($self) . ' class');
    }
}

# Method: Viewer
#
#       Method to return the viewer from this model. This method
#       can be overriden
#
# Returns:
#
#       String - the path to the Mason template which acts as the
#       viewer from this kind of model.
#
sub Viewer
{
    return '/ajax/tableBody.mas';
}

sub modalViewer
{
    my ($self) = @_;
    # for the moment only we have modal for adding elements out of their page
    return '/ajax/modal/addElement.mas';
}

# Method: automaticRemoveMsg
#
#       Get the i18ned string to show when an automatic remove is done
#       in a model
#
# Parameters:
#
#       nDeletedRows - Int the deleted row number
#
sub automaticRemoveMsg
{
    my ($self, $nDeletedRows) = @_;

    return __x('Remove {num} rows of {rowName} from {model}{br}',
            num     => $nDeletedRows,
            rowName => $self->printableRowName(),
            model   => $self->printableContextName(),
            br      => '<br>');
}

# Method: showFilterForm
#
# Returns:
#
#   Boolean - whether to show the filter form or not
#
sub showFilterForm
{
    my ($self) = @_;

    my $table = $self->table();
    if (defined($table->{'showFilterForm'})) {
        return $table->{'showFilterForm'};
    }

    return 1;
}

# Method: showPaginationForm
#
# Returns:
#
#   Boolean - whether to show the form navigation or not
#
sub showPaginationForm
{
    my ($self) = @_;

    my $table = $self->table();
    if (defined($table->{'showPaginationForm'})) {
        return $table->{'showPaginationForm'};
    }

    return 1;
}




# Method: pageSize
#
#     Return the number of rows per page
#
# Parameters:
#
#     user - String the user name
#
# Returns:
#
#    int page size or '_all' for 'All pages' option
sub pageSize
{
    my ($self, $user) = @_;

    if ($user) {
        my $pageSize = EBox::WebAdmin::UserConfiguration::get($user, $self->contextName() .'pageSize');
        if ($pageSize) {
            return $pageSize;
        }
    }

    return $self->defaultPageSize();
}

# Method: pageSizeIntValue
#
#  return the exact maximum number of rows which should be displayed in each
#  page
sub pageSizeIntValue
{
    my ($self, $user) = @_;

    my $pageSize = $self->pageSize($user);
    if ($pageSize eq '_all') {
        return INT_MAX;
    }
    return $pageSize;
}


# Method: defaultPageSize
#
#     Return the default number of rows per page. This value must be defined in
#     the table description. If it is not defined it defaults to 10
#
# Returns:
#
#    int - default page size
sub defaultPageSize
{
    my ($self) = @_;

    my $table = $self->table();
    if (exists $table->{'pageSize'} ) {
        return $table->{'pageSize'};
    }

    # fallback to default value of 10
    return 10;
}

# Method: setPageSize
#
#     set the number of rows per page
#
# Parameters:
#
#     user - The user that requested this page size
#     rows - number of rows per page, '_all' for all elements or
#            a zero for the default page size
#
# Returns:
#
#    int - page size
sub setPageSize
{
    my ($self, $user, $rows) = @_;

    unless (defined ($user)) {
        throw EBox::Exceptions::MissingArgument("Missing user");
    }
    unless (defined ($rows)) {
        throw EBox::Exceptions::MissingArgument("Missing field rows");
    }

    if (($rows ne '_all') and ($rows < 0)) {
        throw EBox::Exceptions::InvalidData(
            data => __('Page size'),
            value => $rows,
            advice => __('Must be either a positive number or "_all" for all elements')
        );
    }
    EBox::WebAdmin::UserConfiguration::set($user, $self->contextName() . 'pageSize', $rows);
}

# Method: changeViewJS
#
#     Return the javascript function to change view to
#     add a row
#
# Parameters:
#
#    (NAMED)
#    changeType - changeAdd or changeList
#    editId - edit id
#     page - page number
#       isFilter - boolean indicating if comes from filtering
#
#
# Returns:
#
#     string - holding a javascript funcion
sub changeViewJS
{
    my ($self, %args) = @_;

    my ($type, $editId, $page, $isFilter) = ($args{changeType},
            $args{editId},
            $args{page},
            $args{isFilter},
            );

    my $function = "Zentyal.TableHelper.changeView('%s','%s','%s','%s','%s', %s, %s)";

    my $table = $self->table();
    return sprintf ($function,
                    $table->{'actions'}->{'changeView'},
                    $table->{'tableName'},
                    $table->{'confdir'},
                    $type,
                    $editId,
                    $page,
                    $isFilter);
}

# Method: showChangeRowFormJS
#
#     Return the javascript function to change view to
#     add a row
#
# Parameters:
#
#    (NAMED)
#    changeType - changeAdd or changeList
#    editId - edit id
#     page - page number
#       isFilter - boolean indicating if comes from filtering
#
#
# Returns:
#
#     string - holding a javascript funcion
sub showChangeRowFormJS
{
    my ($self, %args) = @_;

    my ($type, $editId, $page, $isFilter) = ($args{changeType},
            $args{editId},
            $args{page},
            $args{isFilter},
            );

    my $function = "Zentyal.TableHelper.showChangeRowForm('%s','%s','%s','%s','%s', %s, %s)";

    my $table = $self->table();
    return sprintf ($function,
                    $table->{'actions'}->{'changeView'},
                    $table->{'tableName'},
                    $table->{'confdir'},
                    $type,
                    $editId,
                    $page,
                    $isFilter);
}


# Method: modalChangeViewJS
#
#     Return the javascript function to change view
#
# Parameters:
#
#    (NAMED)
#    changeType - changeAdd or changeList
#    editId - edit id
#     page - page number
#       isFilter - boolean indicating if comes from filtering
#
#
# Returns:
#
#     string - holding a javascript funcion
sub modalChangeViewJS
{
    my ($self, %args) = @_;
    my $actionType = delete $args{changeType};
    my $editId     = delete $args{editId};
    if (not $args{title}) {
        $args{title} = __x('New {name}',
                           name => $self->printableRowName()
                          );
    }

    my $extraParamsJS = _paramsToJSON(%args);

    my  $function = "Zentyal.TableHelper.modalChangeView('%s','%s','%s','%s','%s', %s)";

    my $table = $self->table();
    my $url = $table->{'actions'}->{'changeView'}; # url
    $url =~ s/Controller/ModalController/;
    my $tableId = $table->{'tableName'};

    my $js =  sprintf ($function,
            $url,
            $tableId,
            $table->{'confdir'},
            $actionType,
            $editId,
            $extraParamsJS,
            );

    return $js;
}

sub modalCancelAddJS
{
    my ($self, %params) = @_;
    my $table   = $self->table();
    my $tableId = $table->{'tableName'};

    my $url = $table->{'actions'}->{'changeView'};
    $url    =~ s/Controller/ModalController/;

    my $directory = $self->directory();
    my $selectCallerId = $params{selectCallerId};

    my  $function = "Zentyal.TableHelper.modalCancelAddRow('%s', '%s', this, '%s', '%s')";
    my $js =  sprintf ($function,
                       $url,
                       $tableId,
                       $directory,
                       $selectCallerId
                      );

    return $js;
}

# Method: addNewRowJS
#
#     Return the javascript function for addNewRow
#
# Parameters:
#
#    (POSITIONAL)
#     page - page number
#
# Returns:
#
#     string - holding a javascript funcion
sub addNewRowJS
{
    my ($self, $page, %params) = @_;
    my $cloneId = $params{cloneId};

    my  $function = "Zentyal.TableHelper.addNewRow('%s','%s',%s,'%s',%s)";

    my $table = $self->table();
    my @extraFields;
    push @extraFields, 'cloneId' if $cloneId;

    my $fields = $self->_paramsWithSetterJS(@extraFields);
    return  sprintf ($function,
            $table->{'actions'}->{'add'},
            $table->{'tableName'},
            $fields,
            $table->{'confdir'},
            $page);
}

sub modalAddNewRowJS
{
    my ($self, $page, $nextPage, @extraParams) = @_;
    $nextPage or
        $nextPage = '';

    my  $function = "Zentyal.TableHelper.modalAddNewRow('%s','%s',%s,'%s', '%s', %s)";

    my $table = $self->table();
    my $url = $table->{'actions'}->{'add'};
    $url =~ s/Controller/ModalController/;

    my $extraParamsJS = _paramsToJSON(@extraParams);

    my $tableId = $table->{'tableName'};

    my $fields = $self->_paramsWithSetterJS();
    return sprintf ($function,
                    $url,
                    $tableId,
                    $fields,
                    $table->{'confdir'},
                    $nextPage,
                    $extraParamsJS);
}

# Method: changeRowJS
#
#     Return the javascript function for changeRow
#
# Parameters:
#
#    (POSITIONAL)
#    editId - row id to edit
#     page - page number
#
# Returns:
#
#     string - holding a javascript funcion
sub changeRowJS
{
    my ($self, $editId, $page) = @_;

    my  $function = "Zentyal.TableHelper.changeRow('%s','%s',%s,'%s','%s',%s, %s)";

    my $table = $self->table();
    my $tablename =  $table->{'tableName'};
    my $actionUrl =  $table->{'actions'}->{'editField'};

    my $force =0;
    my $fields = $self->_paramsWithSetterJS();
    return sprintf ($function,
                    $actionUrl,
                    $tablename,
                    $fields,
                    $table->{'confdir'},
                    $editId,
                    $page,
                    $force);
}

sub _paramsToJSON
{
    my (%params) = @_;
    my $paramString = '{';
    while (my ($name, $value) = each %params) {
        $paramString .= "'$name'" . ': '  . "'$value'" . ', ';
    }
    $paramString .= '}';
    return $paramString;
}

# Method: deleteActionClickedJS
#
#     Return the javascript function for click on delete action
#
# Parameters:
#
#    id - row to remove
#    page - page number
#
# Returns:
#
#     string - holding a javascript funcion
sub deleteActionClickedJS
{
    my ($self, $id, $page) = @_;
    my $action = 'del';
    my $function = "Zentyal.TableHelper.deleteActionClicked('%s','%s','%s','%s',%s)";


    my $table = $self->table();
    my $actionUrl = $table->{'actions'}->{$action};
    my $tablename = $table->{'tableName'};

    my $fields = $self->_paramsWithSetterJS();
    return sprintf ($function,
                    $actionUrl,
                    $tablename,
                    $id,
                    $table->{'confdir'},
                    $page);
}

sub actionHandlerUrl
{
    my ($self) = @_;
    return $self->_mainController();
}

# Method: customActionClickedJS
#
#     Return the javascript function for customActionClicked
#
# Parameters:
#
#     TODO
#
# Returns:
#
#     string - holding a javascript funcion
sub customActionClickedJS
{
    my ($self, $action, $id, $page) = @_;

    unless ( $self->customActions($action, $id) ) {
        throw EBox::Exceptions::Internal("Wrong custom action $action");
    }

    my $function = "Zentyal.TableHelper.customActionClicked('%s','%s','%s',%s,'%s','%s',%s)";

    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();
    $page = 0 unless $page;
    return sprintf ($function,
                    $action,
                    $self->actionHandlerUrl(),
                    $table->{'tableName'},
                    $fields,
                    $table->{'confdir'},
                    $id,
                    $page);
}

# Method: reloadTable
#
#     This method is intended to reload the information from the table
#     description. It is useful when the table description may change
#     on the fly due to some state
#
# Returns:
#
#     <EBox::Model::DataTable> - the same info that
#     <EBox::Model::DataTable::table> returned value
#
sub reloadTable
{
    my ($self) = @_;

    undef $self->{'table'};
    undef $self->{'fields'};
    return $self->table();
}

# Group: Protected methods

# Method: _prepareRow
#
#     Returns a new row instance with all its elements cloned
#     and ready to be set
#
sub _prepareRow
{
    my ($self) = @_;

    my $row = EBox::Model::Row->new(dir => $self->directory(),
                                    confmodule => $self->{confmodule});
    $row->setModel($self);
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $data = $type->clone();
        $row->addElement($data);
    }
    return $row;
}

# Method: _cloneRow
#
#     Returns a new row instance with all its elements cloned
#     from the given row
#
sub _cloneRow
{
    my ($self, $other) = @_;

    my $row = EBox::Model::Row->new(dir => $self->directory(),
                                    confmodule => $self->{confmodule});
    $row->setModel($self);
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $element = $other->elementByName($type->{fieldName});
        my $newElement = $element->clone();
        $row->addElement($newElement);
    }
    return $row;
}

# Method: _setValueRow
#
#     Returns a new row instance with all its elements cloned
#     and set to the passed value.
#
# Parameters:
#
#   (NAMED)
#
#     Hash containing field names as keys, and values that will
#     be passed to setValue for every element.
#
sub _setValueRow
{
    my ($self, %values) = @_;

    my $row = $self->_prepareRow();
    while (my ($key, $value) = each %values) {
        $row->elementByName($key)->setValue($value);
    }
    return $row;
}

# Method: _setDefaultMessages
#
#      Set the default messages done by possible actions
#
sub _setDefaultMessages
{
    my ($self) = @_;

    # Table is already defined
    my $table = $self->{'table'};

    $table->{'messages'} = {} unless ( $table->{'messages'} );
    my $rowName = $self->printableRowName();

    my %defaultMessages =
      (
       'add'       => __x('{row} added', row => $rowName),
       'del'       => __x('{row} deleted', row => $rowName),
       'update'    => __x('{row} updated', row => $rowName),
      );

    foreach my $action (keys (%defaultMessages)) {
        unless ( exists $table->{'messages'}->{$action} ) {
            $table->{'messages'}->{$action} = $defaultMessages{$action};
        }
    }
}

# Method: _setCustomMessages
#
#      Set the custom messages based on possibel custom actions
#
sub _setCustomMessages
{
    my ($self, $actions, $id) = @_;

    my $table = $self->{'table'};
    $table->{'messages'} = {} unless ( $table->{'messages'} );

    for my $customAction ( @{$actions} ) {
        my $action = $customAction->name($id);
        my $message = $customAction->message($id);
        $table->{messages}->{$action} = $message;
    }
}

# Method: _volatile
#
#       Check if this model is volatile. That is, the data is not
#       stored in disk but it is done by the storer and restored by
#       the acquirer. Every type must be volatile in order to have a
#       model as volatile
#
# Returns:
#
#       Boolean - indicating if the table is volatile or not
#
sub _volatile
{
    my ($self) = @_;

    return $self->{'volatile'};
}

# Group: Private helper functions

# Method: _find
#
#    (PRIVATE)
#
#    Used by find* methods to find rows in a table matching the given fields values
#
# Parameters:
#
#    (POSITIONAL)
#
#    values     - hash ref with the fields and values to look for
#
#    allMatches - 1 or undef to tell the method to return just the
#                 first match or all of them
#
#    kind       - *(Optional)* String if 'printableValue' match against
#                 printableValue, if 'value' against value
#                 Default value: 'value'
#
#    nosync     - *(Optional)* don't call to syncRows to avoid recursion
#
# Example:
#
#     _find({'default' => 1}, undef, 'printableValue');
#
# Returns:
#
#    An array of ids which references those rows that match with the
#    given filter
#
sub _find
{
    my ($self, $values, $allMatches, $kind, $nosync) = @_;

    unless (defined ($values) and (ref ($values) eq 'HASH')) {
        throw EBox::Exceptions::MissingArgument("Missing values or invalid hash ref");
    }

    my @fields = keys (%{$values});

    unless (@fields) {
        throw EBox::Exceptions::InvalidData("No fields/values provided");
    }

    my $conf = $self->{confmodule};

    $kind = 'value' unless defined ($kind);

    my @rows = @{$nosync ? $self->_ids(1) : $self->ids()};

    my @matched;
    foreach my $id (@rows) {
        my $row = $self->row($id);
        my $matches = 0;
        foreach my $field (@fields) {
            my $element = $row->elementByName($field);
            if (defined ($element)) {
                my $eValue;
                if ($kind eq 'printableValue') {
                    $eValue = $element->printableValue();
                } else {
                    $eValue = $element->value();
                }
                if ((defined $eValue) and ($eValue eq $values->{$field})) {
                    $matches++;
                }
            }
        }

        if ($matches == @fields) {
            if ($allMatches) {
                push (@matched, $id);
            } else {
                return [ $id ];
            }
        }
    }

    return \@matched;
}

sub _checkFieldIsUnique
{
    my ($self, $newData) = @_;

    if ($newData->optional() and not defined($newData->value())) {
        return 0;
    }
    my $printableValue = $newData->printableValue();
    my @matched =
        @{$self->_find({ $newData->fieldName() => $printableValue }, undef, 'printableValue', 1)};

    if (@matched) {
        throw EBox::Exceptions::DataExists(
            'data'  => $newData->printableName(),
            'value' => $printableValue,
        );
    }
    return 0;
}

# Check the new row to add/set is unique, it ignores enabled parameter
# is any
# rowId can be undef if the call comes from an addition
# A hash ref of types is passing in
# throw <EBox::Exceptions::DataExists> if not unique
sub _checkRowIsUnique # (rowId, row_ref)
{
    my ($self, $rowId, $row_ref) = @_;

    # Call _rows instead of rows because of deep recursion
    my $rows = $self->_rows();

    my $fields = $self->fields();
    # Exclude 'enabled' field if isEnablePropertySet
    if ( $self->isEnablePropertySet() ) {
        my @fieldsWithoutEnabled = grep { $_ ne 'enabled' } @{$fields};
        $fields = \@fieldsWithoutEnabled;
    }

    foreach my $id (@{$self->_ids()}) {
        my $row = $self->row($id);
        next unless ( defined($row) );
        # Compare if the row identifier is different
        next if ( defined($rowId) and $row->{'id'} eq $rowId);
        my $nEqual = 0;
        foreach my $fieldName (@{$fields}) {
            if ( defined($row_ref->{$fieldName}) ) {
                if ( $row_ref->{$fieldName}->isEqualTo($row->elementByName($fieldName)) ) {
                    $nEqual++;
                }
            }
            # If not defined, then the field is optional and the comparation here is useless
            else {
                $nEqual++;
            }
        }
        next unless ( $nEqual == scalar(@{$fields}) );
        throw EBox::Exceptions::DataExists(
                                           'data'  => $self->printableRowName(),
                                           'value' => ''
                                           );
    }
}

# FIXME: Deprecated?
sub _checkAllFieldsExist
{
    my ($self, $params) = @_;

    my $types = $self->table()->{'tableDescription'};

    foreach my $field (@{$types}) {

        unless ($field->paramExist($params)) {
            throw Exceptions::MissingArgument($field->printableName());
        }
    }
}

# Method to check if compulsory are given when adding
sub _checkCompulsoryFields
{
    my ($self, $paramsRef) = @_;

    my @compulsoryFields = @{$self->_compulsoryFields()};

    foreach my $compulsoryField (@compulsoryFields) {
        my $found = 0;
        foreach my $userField (keys %{$paramsRef}) {
            $found = $userField eq $compulsoryField;
            last if ( $found );
        }
        unless ( $found ) {
            my $missingField = $self->fieldHeader($compulsoryField);
            throw EBox::Exceptions::DataMissing(data => $missingField->printableName());
        }
    }
}

# Gives back the compulsory field names
sub _compulsoryFields
{
    my ($self) = @_;

    my @compulsory = ();
    foreach my $fieldName (@{$self->fields()}) {
        my $field = $self->fieldHeader($fieldName);
        unless ($field->optional() or $field->hidden()) {
            push (@compulsory, $fieldName);
        }
    }

    return \@compulsory;
}

sub _checkRowExist
{
    my ($self, $id, $text) = @_;

    unless ($self->_rowExists($id)) {
        throw EBox::Exceptions::DataNotFound(
                data => $text,
                value => $id);
    }
}

sub _rowExists
{
    my ($self, $id) = @_;

    # TODO: is it worth implementing this with redis ZSET to get O(1)
    #       and easy ordering ?
    foreach my $row (@{$self->_ids(1)}) {
        if ($row eq $id) {
            return 1;
        }
    }
    return 0;
}

sub _newId
{
    my ($self) = @_;

    my $model = $self->modelName();
    my $leadingText = lc ($model);
    my $firstLetter = substr ($leadingText, 0, 1);
    my $rest = substr ($leadingText, 1, length ($leadingText) - 1);
    $rest =~ tr/aeiou//d;
    $leadingText = $firstLetter . $rest;
    $leadingText = substr($leadingText, 0, length ($leadingText) / 2);

    my $id = 1;
    my $maxId = $self->{confmodule}->get("$model/max_id");
    if ($maxId) {
        $id = $maxId + 1;
    }
    $self->{confmodule}->set("$model/max_id", $id);

    return $leadingText . $id;
}

sub _idsOrderList
{
    my ($self) = @_;
    my $confmod = $self->{'confmodule'};
    return $confmod->get_list($self->{'order'});
}

sub _setIdsOrderList
{
    my ($self, $order) = @_;
    $self->{confmodule}->set_list($self->{'order'}, 'string', $order);
}

# Insert the id element in selected position, if the position is the
# last + 1 is inserted after the last one
sub _insertPos #(id, position)
{
    my ($self, $id, $pos) = @_;
    my @order = @{$self->_idsOrderList()};

    if ($pos == 0) {
        unshift @order , $id;
    } elsif ($pos >= @order) {
        push @order, $id;
    } else {
        splice(@order, $pos, 0, $id);
    }

    $self->_setIdsOrderList(\@order);
}

# return the old postion in order
sub removeIdFromOrder
{
    my ($self, $id) = @_;
    my @order = @{ $self->_idsOrderList() };
    for (my $i=0; $i < @order; $i++) {
        if ($id eq $order[$i]) {
            splice @order, $i, 1;
            $self->_setIdsOrderList(\@order);
            return $i;
        }
    }
    throw EBox::Exceptions::Internal("Id to remove '$id' not found");
}

sub idPosition
{
    my ($self, $id) = @_;
    my $confmod = $self->{'confmodule'};
    my @order = @{$self->_idsOrderList()};
    for (my $i =0 ; $i < @order; $i++) {
        if ($order[$i] eq $id) {
            return $i;
        }
    }
    return undef;
}

sub _orderHash
{
    my $self = shift;

    my  %order;
    if ($self->table()->{'order'}) {
        my @order = @{$self->_idsOrderList()};
        my $i = 0;
        foreach my $id (@order) {
            $order{$id} = $i;
            $i++;
        }
    }

    return %order;
}

sub _rowOrder
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        return;
    }

    my %order = $self->_orderHash();

    return $order{$id};
}

# Method: _notifyManager
#
#     Notify to the model manager that an action has been performed on
#     this model
#
sub _notifyManager
{
    my ($self, $action, $row) = @_;

    my $manager = EBox::Model::Manager->instance();

    my $contextName = $self->contextName();
    # remove begining and trailing '/' for context name
    $contextName =~ s{^/}{};
    $contextName =~ s{/$}{};
    return $manager->modelActionTaken($contextName, $action, $row);
}

sub _mainController
{
    my ($self) = @_;

    my $table = $self->{'table'};

    my $defAction = $table->{'defaultController'};
    if ( (not defined ( $defAction )) and defined ( $self->modelDomain() )) {
        # If it is not a defaultController, we try to guess it from
        # the model domain and its name
        $defAction = '/' . $self->modelDomain() . '/Controller/' .
            $self->{'table'}->{'tableName'};
    }
    return $defAction;
}

# Set the default controller to that actions which do not have a
# custom controller
sub _setControllers
{
    my ($self) = @_;

    # Tree is already defined
    my $table = $self->{'table'};
    my $defAction = $self->_mainController();
    if ($defAction) {
        foreach my $action (@{$table->{'defaultActions'}}) {
            # Do not overwrite existing actions
            unless ( exists ( $table->{'actions'}->{$action} )) {
                $table->{'actions'}->{$action} = $defAction;
            }
        }
    }
}

sub adaptRowFilter
{
    my ($self, $filter) = @_;
    my $compiled;
    # allow starting '*'
    if ($filter =~ m/^\*/) {
        $filter = '.' . $filter;
    }
    eval {  $compiled = qr/$filter/ };
    if ($@) {
        throw EBox::Exceptions::InvalidData(
            data => __('Search rows term'),
            value => $filter,
            advice => __('Must be a valid regular expression'),
           );
    }
    return $compiled;
}

# Method: _paramsWithSetterJS
#
#      Return the string which defines an array with that parameters
#      which have a setter defined
#
# Returns:
#
#      String - the string ready to print on a JavaScript file
#
sub _paramsWithSetterJS
{
    my ($self, @additionalParams) = @_;

    my $table = $self->table();
    my @parameters;
    foreach my $type ( @{$table->{'tableDescription'}}) {
        push ( @parameters, $type->fields());
    }

    my $fieldsWithOutSetter = $self->fieldsWithUndefSetter();
    my @paramsWithSetter = grep {!$fieldsWithOutSetter->{$_}} @parameters;
    push (@paramsWithSetter, 'filter', 'page');
    push @paramsWithSetter, @additionalParams;
    my $paramsArray = '[' . "'" . pop(@paramsWithSetter) . "'";
    foreach my $param (@paramsWithSetter) {
        $paramsArray .= ', ' . "'" . $param . "'";
    }
    $paramsArray .= ']';

    return $paramsArray;
}

######################################
# AUTOLOAD helper private functions
######################################

# Method: _autoloadAdd
#
#     This method implements the addition autoload. This method parses
#     the method name,
#
# Parameters:
#
#     methodName - String the method name begins with 'add'
#     paramsRef  - array ref the undefined method parameters
#
# Returns:
#
#     String - the newly created row identifier (it does not matter if
#     the addition is done in a model or any submodel)
#
sub _autoloadAdd
{
    my ($self, $methodName, $paramsRef) = @_;

    # It will possibly launch an internal exception
    $self->_checkMethodSignature( 'add', $methodName, $paramsRef);

    if ( $self->_actionAppliedToModel( 'add', $methodName) ) {
        # Convert array ref to hash ref
        my %params = @{$paramsRef};
        $paramsRef = \%params;
        # Simple add (add a new row to a model including submodels...)
        my $instancedTypes = $self->_fillTypes($paramsRef, 1);
        my $addedId = $self->addTypedRow($instancedTypes);

        my $subModels = $self->_subModelFields();
        foreach my $subModel (@{$subModels}) {
            if ( exists $paramsRef->{$subModel} ) {
                $self->_autoloadAddSubModel($subModel, $paramsRef->{$subModel}, $addedId);
            }
        }
        return $addedId;
    } else {
        # An addition to one of the submodels
        return $self->_autoloadActionSubModel('add', $methodName, $paramsRef);
    }
}

# Method: _autoloadDel
#
#     This method implements the remove autoload. This method parses
#     the method name,
#
# Parameters:
#
#     methodName - String the method name begins with 'del'
#     paramsRef  - array ref the undefined method parameters
#
# Returns:
#
#     true - if the removal was successful
#
# Exceptions:
#
#     <EBox::Exceptions::Base> - thrown if the removal cannot be done
#
sub _autoloadDel
{
    my ($self, $methodName, $paramsRef) = @_;

    # It will possibly launch an internal exception
    $self->_checkMethodSignature( 'del', $methodName, $paramsRef);

    if ( $self->_actionAppliedToModel( 'del', $methodName) ) {
        # Get the identifier
        my $removeId = $self->_autoloadGetId($self, $paramsRef);
        # Simple del (del a row to a model)
        $self->removeRow($removeId, 1);
        return 1;
    } else {
        # A removal to one of the submodels
        return $self->_autoloadActionSubModel('del', $methodName, $paramsRef);
    }
}

# Method: _autoloadGet
#
#     This method implements the accessor methods
#
# Parameters:
#
#     methodName - String the method name begins with 'get'
#     paramsRef  - array ref the undefined method parameters
#
# Returns:
#
#     hash ref - the same as <EBox::Model::DataTable::row> return
#     value if the answer has more that one field
#     <EBox::Types::Abstract> - if the answer just return a single
#     field
#
# Exceptions:
#
#     <EBox::Exceptions::Base> - thrown if the access cannot be done
#
sub _autoloadGet
{
    my ($self, $methodName, $paramsRef) = @_;

    # It will possibly launch an internal exception
    $self->_checkMethodSignature( 'get', $methodName, $paramsRef);

    if ($self->_actionAppliedToModel( 'get', $methodName)) {
        # Get the identifier
        my $getId = $self->_autoloadGetId($self, $paramsRef);
        # Simple del (del a row to a model)
        my $row = $self->row($getId);
        my $fieldNames = undef;
        # Get the field names if any
        $fieldNames = $paramsRef->[$#$paramsRef] if ( scalar(@{$paramsRef}) % 2 == 0 );
        return $self->_filterFields($row, $fieldNames);
    } else {
        # A removal to one of the submodels
        return $self->_autoloadActionSubModel('get', $methodName, $paramsRef);
    }
}

# Method: _autoloadSet
#
#     This method implements the update autoload
#
# Parameters:
#
#     methodName - String the method name begins with 'set'
#     paramsRef  - array ref the undefined method parameters
#
# Exceptions:
#
#     <EBox::Exceptions::Base> - thrown if the update cannot be done
#
sub _autoloadSet
{
    my ($self, $methodName, $paramsRef) = @_;

    # It will possibly launch an internal exception
    $self->_checkMethodSignature('set', $methodName, $paramsRef);

    if ( $self->_actionAppliedToModel('set', $methodName) ) {
        my $updateId = $self->_autoloadGetId($self, $paramsRef);
        # Remove the id from the params
        shift ( @{$paramsRef} );
        # Convert array ref to hash ref
        my %params = @{$paramsRef};

        my $force  = delete $params{force};
        defined $force or
            $force = 0;

        $paramsRef = \%params;
        # Simple add (add a new row to a model including submodels...)
        my $instancedTypes = $self->_fillTypes($paramsRef);
        $self->setTypedRow($updateId, $instancedTypes, force => $force);

        my $subModels = $self->_subModelFields();
        foreach my $subModel (@{$subModels}) {
            if ( exists $paramsRef->{$subModel} ) {
                $self->_autoloadSetSubModel($subModel, $paramsRef->{$subModel}, $updateId);
            }
        }
    } else {
        # An update to one of the submodels
        $self->_autoloadActionSubModel('set', $methodName, $paramsRef);
    }
}

#############################################################
# Protected helper methods to help autoload helper functions
#############################################################

# Method: _checkMethodSignature
#
#      Check the method name and parameters from the autoloads
#
# Parameters:
#
#      action - String the action to run (add, del, set or get)
#
#      methodName - String the method name to check
#
#      paramsRef - array ref the parameters to check all parameters
#      are set correctly
#
sub _checkMethodSignature # (action, methodName, paramsRef)
{
    my ($self, $action, $methodName, $oldParamsRef) = @_;

    my $paramsRef = Clone::Fast::clone($oldParamsRef);

    # Delete the action from the name
    my $first = ( $methodName =~ s/^$action// );
    my @modelNames = split ( 'To', $methodName);
    my $tableNameInModel = $modelNames[$#modelNames];
    my $subModelInMethod = $modelNames[$#modelNames - 1] unless ( $#modelNames == 0 );
    my $submodels = $self->_subModelFields();

    if ( defined ( $subModelInMethod ) and defined ( $submodels )) {
        # Turn into lower case the first letter
        $subModelInMethod = lcfirst($subModelInMethod);
        if ( $subModelInMethod eq any(@{$submodels}) ) {
        # Remove one parameter, since the index is used
            shift ( @{$paramsRef} );
            # newMethodName goes to the recursion
            my $newMethodName = $methodName;
            $newMethodName =~ s/To$tableNameInModel$//;
            my $foreignModelName =
                $self->fieldHeader($subModelInMethod)->foreignModel();
            my $manager = EBox::Model::Manager->instance();
            my $foreignModel = $manager->model($foreignModelName);
            # In order to decrease the number of calls
            if ( scalar ( @modelNames ) > 2 ) {
                # Call recursively to the submodel
                $foreignModel->_checkMethodSignature($action, $newMethodName, $paramsRef);
            }
        } else {
            throw EBox::Exceptions::Internal('Illegal sub model field name. It ' .
                    'should be one of the following: ' .
                    join(' ', @{$submodels}) );
        }
    } else {
        # The final recursion is reached
        # If the action is an addition, there is no identifier
        my $nParams = scalar( @{$paramsRef} );
        unless ( $action eq 'add') {
            $nParams--;
        }
        if ( $action eq 'get' ) {
            if ( $nParams > 0 ) {
                # Check the final get parameter is an array ref if any
                unless ( ref ( $paramsRef->[$#$paramsRef] ) eq 'ARRAY' ) {
                    throw EBox::Exceptions::Internal('If you use a field selector, it must be ' .
                            'an array reference');
                }
            }
        } else {
            # Check the number of parameters are even
            unless ( $nParams % 2 == 0 ) {
                throw EBox::Exceptions::Internal('The number of parameters is odd. Some ' .
                        'index argument is missing. Remember the ' .
                        'indexes are positional and the model arguments ' .
                        'are named');
            }
        }
    }

    # If the iteration is the first one, check the table name or nothing
    if ( $first ) {
        # Check only simple cases (add[<tableName>])
        if ( $methodName and not defined ( $subModelInMethod )) {
            unless ( $methodName eq $self->tableName() ) {
                throw EBox::Exceptions::Internal(
                    "Method $_[2] does not exist, May you have mispelled it?");
            }
        }
    }
}

# Function: _actionAppliedToModel
#
#      Determine whether the action is only applied to a single row on
#      a model or refers to a submodel. No matter how deep the
#      submodel to apply the action is placed
#
# Parameters:
#
#      action - String the action name
#      methodName - String the method name which describes the action
#
# Returns:
#
#      boolean - true if the action is applied to the model itself,
#      false if the action is applied only to one of the submodels
#
sub _actionAppliedToModel
{
    my ($self, $action, $methodName) = @_;

    $methodName =~ s/^$action//;

    my $tableName = $self->tableName();
    if ( $methodName =~ m/.+To$tableName/ ) {
        return 0;
    } else {
        return 1;
    }
}

# Get the fields which contains a HasMany type
sub _subModelFields
{
    my ($self) = @_;

    my @subModelFields = ();
    foreach my $fieldName (@{$self->fields()}) {
        my $type = $self->fieldHeader($fieldName);
        if ( $type->isa('EBox::Types::HasMany') ) {
            push ( @subModelFields, $fieldName );
        }
    }
    return \@subModelFields;
}

# Method: _fillTypes
#
#     Fill the types with the given parameters, it returns a list
#     containing the types with the defining types.
#
# Parameters:
#
#     params - hash ref containing the name and the values for each
#     type to fill
#
#     fillDefault - boolean indicating if there are any field which is
#     not provided in params parameter, it will feed with its default
#     value if any *(Optional)* Default value: false
#
# Returns:
#
#     hash ref - the types instanced with a value set indexed by field
#     name
#
# Exceptions:
#
#     <EBox::Exceptions::External> - thrown if any error setting the
#     types is done
#
sub _fillTypes
{
    my ($self, $params, $fillDefault) = @_;

    $fillDefault = '' unless defined($fillDefault);

    # Check all given fields to fill are in the table description
    foreach my $paramName (keys %{$params}) {
        unless ( $paramName eq any(@{$self->fields()}) ) {
            throw EBox::Exceptions::Internal("$paramName does not exist in the " .
                    'model ' . $self->name() . ' description');
        }
    }

    my $filledTypes = {};
    foreach my $fieldName (@{$self->fields()}) {
        my $field = $self->fieldHeader($fieldName);
        if ( exists $params->{$fieldName} ) {
            my $paramValue = $params->{$fieldName};
            my $newType = $field->clone();
            $newType->setValue($paramValue);
            $filledTypes->{$fieldName} = $newType;
        } elsif ( $fillDefault and defined($field->defaultValue())
                  and (not $field->optional())) {
            # New should set default value
            my $newType = $field->clone();
            $filledTypes->{$fieldName} = $newType;
        }
    }

    return $filledTypes;
}

# Method: _autoloadAddSubModel
#
#       Add every row to a submodel in the bulk addition
#
# Parameters:
#
#       subModelFieldName - String the submodel (HasMany) field name
#
#       subModelRows - array ref the submodel rows to add having the scheme as
#       <EBox::Model::DataTable::AUTOLOAD> addition has
#
#       id - String the identifier which determines where to
#       store the data within this submodel
#
sub _autoloadAddSubModel # (subModelFieldName, rows, id)
{
    my ($self, $subModelFieldName, $subModelRows, $id) = @_;

    my $hasManyField = $self->fieldHeader($subModelFieldName);
    my $userField = $hasManyField->clone();
    my $directory = $self->directory() . "/keys/$id/$subModelFieldName";
    my $foreignModelName = $userField->foreignModel();
    my $submodel = EBox::Model::Manager->instance()->model(
            $foreignModelName
            );
    $submodel->setDirectory($directory);

    # Addition to a submodel
    foreach my $subModelRow (@{$subModelRows}) {
        my $instancedTypes = $submodel->_fillTypes($subModelRow, 1);
        my $addedId = $submodel->addTypedRow($instancedTypes);

        my $subSubModels = $submodel->_subModelFields();
        foreach my $subSubModel (@{$subSubModels}) {
            if ( exists $subModelRow->{$subSubModel} ) {
                $submodel->_autoloadAddSubModel($subSubModel,
                        $subModelRow->{$subSubModel},
                        $addedId);
            }
        }

    }
}

# Method: _autoloadSetSubModel
#
#       Update every row to a submodel in the bulk update
#
# Parameters:
#
#       subModelFieldName - String the submodel (HasMany) field name
#
#       subModelRows - array ref the submodel rows to set having the scheme as
#       <EBox::Model::DataTable::AUTOLOAD> addition has
#
#       id - String the identifier which determines where to
#       store the data within this submodel
#
sub _autoloadSetSubModel # (subModelFieldName, rows, id)
{
    my ($self, $subModelFieldName, $subModelRows, $id) = @_;

    my $hasManyField = $self->fieldHeader($subModelFieldName);
    my $userField = $hasManyField->clone();
    my $directory = $self->directory() . "/keys/$id/$subModelFieldName";
    my $foreignModelName = $userField->foreignModel();
    my $submodel = EBox::Model::Manager->instance()->model(
            $foreignModelName
            );
    $submodel->setDirectory($directory);
    # Addition to a submodel
    foreach my $subModelRowKey (keys %{$subModelRows}) {
        my $updateId = $self->_autoloadGetId($submodel, [ $subModelRowKey ] );
        unless ( defined ( $updateId )) {
            throw EBox::Exceptions::DataNotFound( data  => 'submodel row identifier',
                    value => $subModelRowKey);
        }
        my $instancedTypes = $submodel->_fillTypes($subModelRows->{$subModelRowKey});
        $submodel->setTypedRow($updateId, $instancedTypes, force => 1);
    }
}

# Method: _autoloadActionSubModel
#
#       Action performed to a single row from a submodel in a model
#
# Parameters:
#
#       action - String the action name (add, del, get or set) are
#       possible
#
#       methodName - String the method name
#
#       paramsRef  - array ref the undefined method parameters
#
sub _autoloadActionSubModel # (action, methodName, paramsRef)
{
    my ($self, $action, $methodName, $origParamsRef) = @_;

    my $paramsRef = Clone::Fast::clone($origParamsRef);

    $methodName =~ s/^$action//;

    my @modelNames = split ( 'To', $methodName);
    @modelNames = reverse ( @modelNames );

    # Let's go along the method name delTableToTableToTable
    my $model = $self;
    foreach my $subModelField (@modelNames[1 .. @modelNames - 1]) {
        # Turn to lower case the first letter
        $subModelField = lcfirst($subModelField);
        # Get the has many field
        my $hasManyField = $model->fieldHeader($subModelField);
        my $userField = $hasManyField->clone();
        # Get the identifier to set the directory
        my $id = $self->_autoloadGetId($model, $paramsRef);
        # Remove an index to get the model
        shift ( @{$paramsRef} );
        my $directory = $model->directory() . "/keys/$id/$subModelField";
        my $foreignModelName = $userField->foreignModel();
        $model = EBox::Model::Manager->instance()->model(
                $foreignModelName,
                );
        $model->setDirectory($directory);
    }

    # Change from lower case to upper case the first letter
    my $UCAction = ucfirst ( $action );
    my $methodAutoload = "_autoload$UCAction";
    # Action performed in a row in a submodel
    $model->$methodAutoload(
            $action . $model->tableName(),
            $paramsRef,
            );
}

# Method: pushRedirection
#
#   Push a redirection to be used by the controller
#
# Parameters:
#
#   redirect - URL containing the redirect, should be something like:
#              /zentyal/Controller/Foo
sub pushRedirection
{
    my ($self, $redirect) = @_;

    $self->{redirection} = $redirect;
}

# Method: popRedirection
#
#   Pop a redirection to be used by the controller
#
# Returns:
#
#   redirect - URL containing the redirect, should be something like:
#              /zentyal/Controller/Foo
sub popRedirection
{
    my ($self) = @_;

    my $redirection = $self->{redirection};
    $self->{redirection} = undef;

    return $redirection;
}

# Method: printableActionName
#
#      Get the i18ned action name for the form.
#
# Returns:
#
#      String - the i18ned action name. Default value: 'Change'
#
sub printableActionName
{
    my ($self) = @_;

    unless (defined ( $self->table()->{'printableActionName'})) {
        $self->table()->{'printableActionName'} = __('Change');
    }

    return $self->table()->{'printableActionName'};
}

# Method: disableAutocomplete
#
#       Return if the autocompletion in the add/edit forms
#       must be disabled
#
# Returns:
#
#       boolean - true if autocompletion is disabled, false otherwise
#
sub disableAutocomplete
{
    my ($self) = @_;

    return $self->{table}->{'disableAutocomplete'};
}

# Method: viewCustomizer
#
#   Returns EBox::View::Customizer for this model.
#   By default it creates an empty object.
#
# Returns:
#
#   An instance of <EBox::View::Customizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    unless ($self->{viewCustomizer}) {
        my $viewCustom = new EBox::View::Customizer();
        $viewCustom->setModel($self);
        $self->{viewCustomizer} = $viewCustom;
    }
    return $self->{viewCustomizer};
}


# Method: _autoloadGetId
#
#      Get the identifier which will be used to set the directory to
#      that model
#
# Parameters:
#
#      model - <EBox::Model::DataTable> the model to get the row
#      identifier
#
#      paramsRef - array ref the method parameters
#
# Returns:
#
#      String - the identifier if found
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the identifier is
#      not found
#
sub _autoloadGetId
{
    my ($self, $model, $paramsRef) = @_;

    # Get the first element to get the identifier from
    my $id;

    # index field is the field to be used to sort by. It MUST be unique
    if ( defined ( $model->indexField() )) {
        $id = $model->findId( $model->indexField() => $paramsRef->[0] );
        unless ( defined ( $id )) {
            unless ( defined ( $model->row($paramsRef->[0] ))) {
                throw EBox::Exceptions::DataNotFound( data => 'identifier',
                        value => $paramsRef->[0]);
            }
            $id = $paramsRef->[0];
        }
    } else {
        # Check if it a valid identifier
        $id = $paramsRef->[0];
        unless ( defined ( $model->row($paramsRef->[0]) )) {
            # the given id is a number (position)
            if ( $paramsRef->[0] =~ m/^\d+$/ ) {
                my @ids = @{$model->ids()};
                if ( exists ( $ids[$paramsRef->[0]] )) {
                    $id =  $ids[$paramsRef->[0]];
                }
            }
        }
    }

    return $id;
}

# Method: _filterFields
#
#     Giving a result in a row structure, it will only return the
#     field names given in the array ref. If any of the given fields
#     does not exist in the model, it will rise an exception.
#
# Parameters:
#
#     row - hash ref the row to filter the fields to return
#
#     fieldNames - array ref containing the requested fields to return
#
# Returns:
#
#     hash ref - the filtered row comprising the fields requested at
#     fieldNames array
#
#     <EBox::Types::Abstract> - if the fieldNames array consist only
#     of one element
#
# Exceptions:
#
#     <EBox::Exceptions::Internal> - thrown if any of the fields does
#     not correspond from any of the model fields
#
sub _filterFields
{
    my ($self, $row, $fieldNames) = @_;

    unless ( defined ( $fieldNames ) ){
        return $row;
    }

    my $newRow = EBox::Model::Row->new(dir => $row->dir(),
                                       confmodule => $row->configModule());
    $newRow->setId($row->id());
    $newRow->setOrder($row->order());

    my @modelFields = @{$self->fields()};
    my $anyModelFields = any(@modelFields);
    foreach my $fieldName ( @{$fieldNames} ) {
        unless ($fieldName eq $anyModelFields) {
            throw EBox::Exceptions::Internal(
                    'Trying to get a field which does exist in this model. These fields ' .
                    'are available: ' . join ( ', ', @modelFields));
        }
        # Put it the new one
        $newRow->addElement($row->elementByName($fieldName));
    }

    if ($newRow->size() == 1) {
        return $newRow->elementByIndex(0);
    }

    return $newRow;
}

# Method: _setEnabledAsFieldInTable
#
#       Set the enabled field (a boolean type) in the current model
#       with name 'Enabled'
#
sub _setEnabledAsFieldInTable
{
    my ($self) = @_;

    # Check if enabled field already exists
    if ( exists $self->{'table'}->{'tableDescriptionByName'}->{'enabled'} ) {
        return;
    }

    my $tableDesc = $self->{'table'}->{'tableDescription'};

    my $enabledType = new EBox::Types::Boolean(fieldName     => 'enabled',
            printableName => __('Enabled'),
            editable      => 1,
            defaultValue  => $self->defaultEnabledValue());
    unshift (@{$tableDesc}, $enabledType);
}

# Set the table as volatile if all its fields are so
sub _setIfVolatile
{
    my ($self) = @_;

    my $desc = $self->{table}->{tableDescription};
    foreach my $field (@{$desc}) {
        return if ( not $field->volatile());
    }
    $self->{volatile} = 1;
}

# Method: keywords
#
# Overrides:
#
#   <EBox::Model::Component::keywords>
#
sub keywords
{
    my ($self) = @_;

    my @words = ();

    push(@words, $self->_extract_keywords($self->pageTitle()));
    push(@words, $self->_extract_keywords($self->headTitle()));
    push(@words, $self->_extract_keywords($self->printableName()));
    push(@words, $self->_extract_keywords($self->printableModelName()));
    push(@words, $self->_extract_keywords($self->printableRowName()));
    push(@words, $self->_extract_keywords($self->help()));

    for my $fieldName (@{$self->fields()}) {
        my $field = $self->fieldHeader($fieldName);
        push(@words, $self->_extract_keywords($field->printableName()));
        push(@words, $self->_extract_keywords($field->help()));
    }
    return \@words;
}

sub _beginTransaction
{
    my ($self) = @_;

    $self->parentModule()->{redis}->begin();
}

sub _commitTransaction
{
    my ($self) = @_;

    $self->parentModule()->{redis}->commit();
}

sub _rollbackTransaction
{
    my ($self) = @_;

    $self->parentModule()->{redis}->rollback();
}

# Method: clone
#
#    clone the contents on one DataTable into another. Due to
#    the impossibilit of having two instances with different directories
#    the databases are reffered as directories. This must called on a DataTable
#    instance of the same class as the source and the destination.
#
#
# Parameters:
#
#       srcDir - conf directory of the datatable to be clone.
#       dstDir - conf directory of the datatable to receive the clone
#
# Returns:
#      nothing

sub clone
{
    my ($self, $srcDir, $dstDir) = @_;
    my $selfDir = $self->directory();

    try {
        $self->setDirectory($srcDir);

        my @srcRows = map {
            $self->row($_)
        } @{$self->ids()};

        $self->setDirectory($dstDir);
        $self->removeAll(1);
        foreach my $srcRow (@srcRows) {
            my $newId = $self->addTypedRow($srcRow->hashElements());

            my $newRow = $self->row($newId);
            $newRow->cloneSubModelsFrom($srcRow)
        }
    } catch ($e) {
        $self->setDirectory($selfDir);
        $e->throw();
    }
    $self->setDirectory($selfDir);
}

# Method: setAll
#
#   set the specified field in all rows to the fiven value
#
#  Parameters:
#       fieldName - field to set
#       value     - value to set
sub setAll
{
    my ($self, $fieldName, $value) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $field = $row->elementByName($fieldName);
        if (not $field) {
            throw EBox::Exceptions::Internal(
                  "Field $field is not present in table " .  $self->name(),
            );
        }

        $field->setValue($value);
        $row->store();
    }
}

# Method: checkAllProperty
#
#  return the value of the 'checkAll' property
#
#  This property should be set to the name of a checkbox field to enable it
#   or to undef to not use the check all option (default: disabled)
sub checkAllProperty
{
    my ($self) = @_;
    return $self->{'table'}->{'checkAll'};
}

# Method: checkAllControls
#
# return a hash with all the 'check all' controls of the table, indexed by
# their field
sub checkAllControls
{
    my ($self) = @_;
    my %checkAllControls;
    my $checkAllProperty = $self->checkAllProperty();
    if ($checkAllProperty) {
        my $table = $self->table();
        %checkAllControls = map {
            my $field = $_;
            my $id =  $table->{tableName} . '_'. $field . '_CheckAll';
            ( $field => $id)
        } @{ $checkAllProperty } ;
    }
    return \%checkAllControls;
}

sub checkAllControlValue
{
    my ($self, $fieldName) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        if (not $row->valueByName($fieldName)) {
            return 0;
        }
    }

    return 1;
}

sub checkAllJS
{
    my ($self, $fieldName) = @_;
    my $table = $self->table();
    my $function = "Zentyal.TableHelper.checkAll('%s', '%s', '%s', '%s', this.checked)";
    my $call =  sprintf ($function,
                    $table->{'actions'}->{'changeView'},
                    $table->{'tableName'},
                    $table->{'confdir'},
                    $fieldName
                    );
    return $call;
}

sub _confirmationDialogForAction
{
    my ($self, $action, $params_r) = @_;
    exists  $self->{'table'}->{'confirmationDialog'} or
        return 1;
    exists $self->{'table'}->{'confirmationDialog'}->{$action} or
        return 1;
    return $self->{'table'}->{'confirmationDialog'}->{$action}->($self, $params_r);
}

sub confirmationJS
{
    my ($self, $action, $goAheadJS) = @_;
    my $table = $self->table();
    exists  $table->{'confirmationDialog'} or
        return $goAheadJS;
    exists $table->{'confirmationDialog'}->{$action} or
        return $goAheadJS;

    my $actionUrl =  $table->{'actions'}->{'editField'};

    my @elements = grep {
        not $_-> hidden()
    } @{  $table->{tableDescription} };
    my @elementNames = map {
        my $element = $_;
        my @fields = map {
            qq{'$_'}
        } $element->fields();
        @fields;
    } @elements;
    my $elementsArrayJS = '['. join(',', @elementNames) . ']' ;

    my $function = "Zentyal.TableHelper.confirmationDialog('%s', '%s','%s', '%s', %s)";

    my $call =  sprintf ($function,
                    $self->_mainController(),
                    $table->{'tableName'},
                    $table->{'confdir'},
                    $action,
                    $elementsArrayJS
                    );

    my $js =<< "ENDJS";
       this.disable = true;
       var specs = $call;
       this.disable = false;
       if (specs.abort) {
           return false;
       }
       if (specs.wantDialog) {
           Zentyal.TableHelper.showConfirmationDialog(specs, function(){
               $goAheadJS
           });
       } else {
          $goAheadJS ;
       }
       return false;
ENDJS

    return $js;
}

sub setSortableTableJS
{
    my ($self) = @_;
    my $table = $self->table();
    my $function = "Zentyal.TableHelper.setSortableTable('%s', '%s', '%s')";
    my $call =  sprintf ($function,
                    $self->_mainController(),
                    $table->{'tableName'},
                    $table->{'confdir'},
                    );
    return $call;
}

# Method: movableRows
#
#  Returns:
#    - whether the rows of this data table can be moved by the user
sub movableRows
{
    my ($self, $filter) = @_;
    if ($filter) {
        # we can only move rows if they are unfiltered,
        return 0;
    } else {
        my $table = $self->table();
        if (exists $table->{'order'} and ($table->{'order'} == 1)) {
            return 1;
        }
    }

    return 0;
}

# Method: pageNumbersText
#
#  returns the localized string used in the pager.
sub pageNumbersText
{
    my ($self, $page, $nPages) = @_;
   if ($nPages == 1) {
        return __('Page 1');
   } else {
        return __x('Page {i} of {n}', i => $page + 1, n => $nPages);
   }
}

# Method: auditable
#
#  whether changes in this component should be audited
#
sub auditable
{
    return 1;
}
1;
