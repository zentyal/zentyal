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

package EBox::Model::DataTable;

use EBox;
use EBox::Model::CompositeManager;
use EBox::Model::ModelManager;
use EBox::Model::Row;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::NotImplemented;

use EBox::Types::Boolean;

# Dependencies
use Clone;
use Error qw(:try);
use POSIX qw(ceil);
use Perl6::Junction qw(all any);

use strict;
use warnings;

use base 'EBox::Model::Component';

# TODO
#     
#    Factor findValue, find, findAll and findAllValue
#
#     Use EBox::Model::Row all over the place
#
#    Fix issue with values and printableValues fetched
#    from foreign tables


#
# Caching:
#     
#     To speed up the process of returning rows, the access to the
#     data stored in gconf is now cached. To keep data coherence amongst
#     the several apache processes, we add a mark in the gconf structure
#     whenever a write operation takes place. This mark is fetched by
#     a process returning its rows, if it has changed then it has
#     a old copy, otherwise its cached data can be returned.
#
#     Note that this caching process is very basic. Next step could be
#     caching at row level, and keeping coherence at that level, modifying
#     just the affected rows in the memory stored structure.
#

sub new
{
        my $class = shift;
        my %opts = @_;
        my $gconfmodule = delete $opts{'gconfmodule'};
        $gconfmodule or
            throw EBox::Exceptions::MissingArgument('gconfmodule');
        my $directory   = delete $opts{'directory'};
        $directory or
            throw EBox::Exceptions::MissingArgument('directory');
        my $domain      = delete $opts{'domain'};

        my $self =
        {
            'gconfmodule' => $gconfmodule,
            'gconfdir' => $directory,
            'directory' => "$directory/keys",
            'order' => "$directory/order", 
            'table' => undef,
            'cachedVersion' => undef,
            'domain' => $domain,
            'pageSize' => 10
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
      $self->_setDomain();
      $self->{'table'} = $self->_table();
      $self->_restoreDomain();
      # Set the needed controller and undef setters
      $self->_setControllers();
      # This is useful for submodels
      $self->{'table'}->{'gconfdir'} = $self->{'gconfdir'};
      # Add enabled field if desired
      if ( $self->isEnablePropertySet() ) {
          $self->_setEnabledAsFieldInTable();
      }
       # Make fields accessible by their names
      for my $field (@{$self->{'table'}->{'tableDescription'}}) {
          my $name = $field->fieldName();
          $self->{'table'}->{'tableDescriptionByName'}->{$name} = $field;
        # Set the model here to allow types have the model from the
        # addition as well
        $field->setModel($self);
      }
      # Some default values
      unless (defined($self->{'table'}->{'class'})) {
          $self->{'table'}->{'class'} = 'dataTable';
      }
      $self->_setDefaultMessages();
    }

    return $self->{'table'};

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

    throw EBox::Exceptions::NotImplemented();

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

# Method: name
#
#       Return the same that <EBox::Model::DataTable::modelName>
#
sub name
  {

      my ($self) = @_;

      return $self->modelName();

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



# Method: contextName
#
#      The context name which is used as a way to know exactly which
#      module this model belongs to and the runtime parameters from
#      which was instanciated
#
# Returns:
#
#      String - following this pattern:
#      '/moduleName/modelName/[param1/param2..]
#
sub contextName
{

    my ($self) = @_;

    my $path = '/' . $self->{'gconfmodule'}->name() . '/' .
      $self->name() . '/';

    $path .= $self->index();

    return $path;

}

# Method: printableContextName
#
#       Localisated version of <EBox::Model::DataTable::contextName>
#       method to be shown on the user
#
# Returns:
#
#       String - the localisated version of context name
#
sub printableContextName
{

    my ($self) = @_;
    my $printableContextName = __x( '{model} in {module} module',
                                    model  => $self->printableName(),
                                    module => $self->{'gconfmodule'}->printableName());
    if ( $self->index() ) {
        $printableContextName .= ' ' . __('at') . ' ';
        if ( $self->printableIndex() ) {
            $printableContextName .= $self->printableIndex();
        } else {
            $printableContextName .= $self->index();
        }
    }

    return $printableContextName;

}

# Method: index
#
#       Get the index from the model instance will be distinguised
#       from the other ones with the same model template. Compulsory
#       to be overriden by child classes if the same model template
#       will be instanciated more than once.
#
#       By default, it returns an empty string ''.
#
# Returns:
#
#       String - the unique index string from this instance within the
#       model template
#
sub index
{

    return '';

}

# Method: printableIndex
#
#       Printable version to <EBox::Model::DataTable::index> method to
#       be printed.
#
# Returns:
#
#       String - the i18ned string to be used to show index
#
sub printableIndex
{

    return '';

}

# Method: parent
#
#   Return model's parent
#
# Returns:
#
#      
#   An instance of a class implementing <EBox::Model::DataTable>
#   or undef if it's not set
#
sub parent
{
    my ($self) = @_;

    return $self->{'parent'};
}

# Method: setParent
#
#   Set model's parent
#
# Parameters:
#
#   An instance of a class implementing <EBox::Model::DataTable>
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidType>
sub setParent 
{
    my ($self, $parent) = @_;

    my $type = 'EBox::Model::DataTable';
    if (defined($parent) and (not $parent->isa($type))) {
        throw EBox::Exceptions::InvalidType( 'argument' => 'parent', 
                                             'type' => $type);
    }

    $self->{'parent'} = $parent;
}

# Method: precondition
#
#       Check if the model has enough data to be manipulated, that
#       is, this precondition constraint is accomplished.
#
#       This method must be override by those models which requires
#       any precondition to work correctly. Associated to the
#       precondition there is a fail message which displays what it is
#       required to make model work using method
#       <EBox::Model::DataTable::preconditionFailMsg>
#
# Returns:
#
#       Boolean - true if the precondition is accomplished, false
#       otherwise
#       Default value: true
sub precondition
{
    return 1;
}

# Method: preconditionFailMsg
#
#       Return the fail message to inform why the precondition to
#       manage this model is not accomplished. This method is related
#       to <EBox::Model::DataTable::precondition>.
#
# Returns:
#
#       String - the i18ned message to inform user why this model
#       cannot be handled
#
#       Default value: empty string
#
sub preconditionFailMsg
{
    return '';
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
        throw EBox::Exceptions::MissingArgument(
                "field's name")
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
    my ($self, $field) = @_;

    unless (defined($field)) {
        throw EBox::Exceptions::MissingArgument("field's name")
    }

    my $cache = $self->{'optionsCache'};
    if ($self->_isOptionsCacheDirty($field)) {
        my @options;
        for my $row (@{$self->rows()}) {
            push (@options, {
                    'value' => $row->id(),
                    'printableValue' => $row->printableValueByName($field)
                    });
        }
        $cache->{$field}->{'values'} = \@options;
        $cache->{$field}->{'cachedVersion'} = $self->_cachedVersion();
    }

    return $cache->{$field}->{'values'};
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
#    Override this method to add your custom checks for
#    the table fields. The parameters are passed like data types.
#
#    It will be called whenever a row is added/updated.
#
#
# Arguments:
#
#     action - String containing the action to be performed
#              after validating this row.
#              Current options: 'add', 'update'
#
#    changedFields - hash ref containing the typed parameters
#                    subclassing from <EBox::Types::Abstract> 
#                    that has changed, the key will be the field's name
#
#    allFields - hash ref containing the typed parameters
#                subclassing from <EBox::Types::Abstract> including changed,
#                the key is the field's name
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
sub validateTypedRow
{

}

# Method: addedRowNotify
#    
#    Override this method to be notified whenever
#    a new row is added
#
# Arguments:
#
#     row - hash ref containing fields and values of the new
#     row
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

# Method: movedUpRowNotify
#    
#    Override this method to be notified whenever
#    a  row is moved up 
#
# Arguments:
#
#     row - hash ref containing fields and values of the moved row
#
sub movedUpRowNotify 
{

}

# Method: movedDownRowNotify
#    
#    Override this method to be notified whenever
#    a  row is moved down
#
# Arguments:
#
#     row - hash ref containing fields and values of the moved row
#
sub movedDownRowNotify 
{

}

# Method: updatedRowNotify
#
#    Override this method to be notified whenever
#    a row is updated
#
# Arguments:
#
#     row - <EBox::Model::Row> row containing fields and values of the
#           updated row
#
#     oldRow - <EBox::Model::Row> row containing the values of the old
#              row
#
#     force - boolean indicating whether the delete is forced or not
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
#            [ add, del, edit, moveUp, moveDown ]
#
#   row  - row modified 
#
# Returns:
#
#   String - any i18ned String to inform the user about something that
#   has happened when the foreign model action was done in the current
#   model
#
sub notifyForeingModelAction
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
sub addRow
{
    my $self = shift;
    my %params = @_;

    $self->validateRow('add', @_);

    my $userData = {};
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $data = $type->clone();
        $data->setMemValue(\%params);
        $userData->{$data->fieldName()} = $data;
    }

    return $self->addTypedRow($userData,
            readOnly => $params{'readOnly'},
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

      my $tableName = $self->tableName();
      my $dir = $self->{'directory'};
      my $gconfmod = $self->{'gconfmodule'};
      my $readOnly = delete $optParams{'readOnly'};
      my $id = delete $optParams{'id'};

      my $leadingText = substr( $tableName, 0, 4);
      # Changing text to be lowercase
      $leadingText = "\L$leadingText";

      unless (defined ($id) and length ($id) > 0) {
          $id = $gconfmod->get_unique_id( $leadingText, $dir);
      }

      my $row = EBox::Model::Row->new(dir => $dir, gconfmodule => $gconfmod);
      $row->setReadOnly($readOnly);
      $row->setModel($self);
      $row->setId($id);

      # Check compulsory fields
      $self->_checkCompulsoryFields($paramsRef);

      # Check field uniqueness if any
      my @userData = ();
      my $userData = {};
      while ( my ($paramName, $param) = each (%{$paramsRef})) {
          # Check uniqueness
          if ( $param->unique() ) {
              $self->_checkFieldIsUnique($param);
          }
          push(@userData, $param);
          $row->addElement($param);
      }

      $self->validateTypedRow('add', $paramsRef, $paramsRef);

      # Check if the new row is unique
      if ( $self->rowUnique() ) {
          $self->_checkRowIsUnique(undef, $paramsRef);
      }

      foreach my $data (@userData) {
          $data->storeInGConf($gconfmod, "$dir/$id");
          $data = undef;
      }

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
      }

      $gconfmod->set_bool("$dir/$id/readOnly", $readOnly);

      $self->setMessage($self->message('add'));
      $self->addedRowNotify($self->row($id));
      $self->_notifyModelManager('add', $self->row($id));
      $self->_notifyCompositeManager('add', $self->row($id));

      $self->_setCacheDirty();

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
    my $gconfmod = $self->{'gconfmodule'};
    my $row = EBox::Model::Row->new(dir => $dir, gconfmodule => $gconfmod);

    unless (defined($id)) {
        return undef;
    }

    unless ($gconfmod->dir_exists("$dir/$id")) {
        return undef;
    }

    $self->{'cacheOptions'} = {};

    my $gconfData = $gconfmod->hash_from_dir("$dir/$id");

    $row->setId($id);
    $row->setReadOnly($gconfData->{'readOnly'});
    $row->setModel($self);
    $row->setOrder($self->_rowOrder($id));    
    
    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $element = $type->clone();
	$element->setRow($row);
        $element->restoreFromHash($gconfData);
        $row->addElement($element);
    }

    return $row;
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

sub _selectOptions
{
    my ($self, $field) = @_;

    my $cached = $self->{'cacheOptions'}->{$field};

    $self->{'cacheOptions'}->{$field} = $self->selectOptions($field);
    return $self->{'cacheOptions'}->{$field};

}

sub moveUp
{
    my ($self, $id) = @_;

    my %order = $self->_orderHash();

    my $pos = $order{$id};
    if ($order{$id} == 0) {
        return;
    }

    $self->_swapPos($pos, $pos - 1);

    $self->setMessage($self->message('moveUp'));
    $self->movedUpRowNotify($self->row($id));
    $self->_notifyModelManager('moveUp', $self->row($id));
    $self->_notifyCompositeManager('moveUp', $self->row($id));

}

sub moveDown
{
    my ($self, $id) = @_;

    my %order = $self->_orderHash();
    my $numOrder = keys %order;

    my $pos = $order{$id};
    if ($order{$id} == $numOrder -1) {
        return;
    }

    $self->_swapPos($pos, $pos + 1);

    $self->setMessage($self->message('moveDown'));
    $self->movedDownRowNotify($self->row($id));
    $self->_notifyModelManager('moveDown', $self->row($id));
    $self->_notifyCompositeManager('moveDown', $self->row($id));

}

sub _reorderCachedRows
{
    my ($self, $posa, $posb) = @_;


    unless ($self->{'cachedRows'})  {
        return;
    }

    my $storedVersion = $self->_storedVersion();
    if ($self->{'cachedVersion'} + 1  != $storedVersion) {
        return;
    }

    my $rows = $self->{'cachedRows'};

    my $auxrow = @{$rows}[$posa];
    my $ordera = @{$rows}[$posa]->{'order'};
    $auxrow->{'order'} = @{$rows}[$posb]->{'order'};
    @{$rows}[$posb]->{'order'} = $ordera;
    @{$rows}[$posa] = @{$rows}[$posb];
    @{$rows}[$posb] = $auxrow;

    $self->{'cachedRows'} = $rows;
    $self->{'cachedVersion'} = $storedVersion;
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

    # If force != true and automaticRemove is enabled it means
    # the model has to automatically check if the row which is 
    # about to removed is referenced elsewhere. In that
    # case throw a DataInUse exceptions to iform the user about
    # the effects its actions will have.
    if ((not $force) and $self->table()->{'automaticRemove'}) {
        my $manager = EBox::Model::ModelManager->instance();
        $manager->warnIfIdIsUsed($self->contextName(), $id);
#            $self->warnIfIdUsed($id);
    }

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove")
    }

    $self->_checkRowExist($id, '');
    my $row = $self->row($id);

    # Workaround: It seems that deleting a dir in gconf doesn't work
    # ok sometimes and it keeps available after deleting it for a while.
    # To workaround this issue we mark the row with "removed"
    $self->{'gconfmodule'}->set_bool("$self->{'directory'}/$id/removed", 1);

    $self->{'gconfmodule'}->delete_dir("$self->{'directory'}/$id");
    $self->_setCacheDirty();



    if ($self->table()->{'order'}) {
        $self->_removeOrderId($id);
    }

    my $userMsg = $self->message('del');
    # Dependant models may return some message to inform the user
    my $depModelMsg = $self->_notifyModelManager('del', $row);
    $self->_notifyCompositeManager('del', $row);
    if ( defined( $depModelMsg ) and $depModelMsg ne ''
       and $depModelMsg ne '<br><br>') {
        $userMsg .= "<br><br>$depModelMsg";
    }
    # If automaticRemove is enabled then remove all rows using referencing
    # this row in other models
    if ($self->table()->{'automaticRemove'}) {
        my $manager = EBox::Model::ModelManager->instance();
        $depModelMsg = $manager->removeRowsUsingId($self->contextName(),
                                                   $id);
        if ( defined( $depModelMsg ) and $depModelMsg ne ''
           and $depModelMsg ne '<br><br>') {
            $userMsg .= "<br><br>$depModelMsg";
        }
    }
    $self->setMessage($userMsg);
    $self->deletedRowNotify($row, $force);

    $self->_setCacheDirty();

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

    $force = 0 unless defined ( $force );

    my @ids = @{$self->{'gconfmodule'}->all_dirs_base($self->{'directory'})};
    foreach my $id (@ids) {
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
#       eBox user about the change on a observable model. Note that
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
#       'modelName' - String the observable model's name
#
#     'id' - String row id
#
#    'changeData' - hash ref of data types which are going to be
#    changed
#
#       'oldRow' - hash ref the same content as
#       <EBox::Model::DataTable::row> using old row content
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
#    TODO
#
#    (POSITIONAL)
#    
#    'modelName' - model's name
#     'id' - row id
sub isIdUsed
{

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
                            readOnly => $params{'readOnly'});

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

      $self->_checkRowExist($id, '');

      my $dir = $self->{'directory'};
      my $gconfmod = $self->{'gconfmodule'};

      my $oldRow = $self->row($id);

      my @setterTypes = @{$self->setterTypes()};

      my $changedElements = { };
      my @changedElements = ();
      my $allHashElements = $oldRow->hashElements();
      foreach my $paramName (keys %{$paramsRef}) {
          unless ( $paramName ne any(@setterTypes) ) {
              throw EBox::Exceptions::Internal('Trying to update a non setter type');
          }

          my $paramData = $paramsRef->{$paramName};
          if ( $oldRow->elementByName($paramName)->isEqualTo($paramsRef->{$paramName})) {
              next;
          }

          if ( $paramData->unique() ) {
              $self->_checkFieldIsUnique($paramData);
          }

          $paramData->setRow($oldRow);
          $changedElements->{$paramName} = $paramData;
          push ( @changedElements, $paramData);
          $allHashElements->{$paramName} = $paramData;
      }

      # Check if the new row is unique
      if ( $self->rowUnique() ) {
          $self->_checkRowIsUnique($id, $allHashElements);
      }

      $changedElements->{id} = $id;
      $self->validateTypedRow('update', $changedElements, $allHashElements);

      # If force != true automaticRemove is enabled it means
      # the model has to automatically check if the row which is 
      # about to be changed is referenced elsewhere and this change
      # produces an inconsistent state
      if ((not $force) and $self->table()->{'automaticRemove'}) {
          my $manager = EBox::Model::ModelManager->instance();
          $manager->warnOnChangeOnId($self->tableName(), $id, $changedElements, $oldRow);
      }

      my $modified = undef;
      for my $data (@changedElements) {
          $data->storeInGConf($gconfmod, "$dir/$id");
          $modified = 1;
      }

      # update readonly if change
      my $rdOnlyKey = "$dir/$id/readOnly";
      if (defined ( $readOnly )
          and ($readOnly xor $gconfmod->get_bool("$rdOnlyKey"))) {

          $gconfmod->set_bool("$rdOnlyKey", $readOnly);

      }

      if ($modified) {
          $self->_setCacheDirty();
          $self->setMessage($self->message('update'));
          # Dependant models may return some message to inform the user
          my $depModelMsg = $self->_notifyModelManager('update', $self->row($id));
          if ( defined ($depModelMsg)
               and ( $depModelMsg ne '' and $depModelMsg ne '<br><br>' )) {
              $self->setMessage($self->message('update') . '<br><br>' . $depModelMsg);
          }
          $self->_notifyCompositeManager('update', $self->row($id));
          $self->updatedRowNotify($self->row($id), $oldRow, $force);
      }

  }

sub _storedVersion
{
    my ($self) = @_;

    my $gconfmod = $self->{'gconfmodule'};
    my $storedVerKey = $self->{'directory'} . '/version';

    return ($gconfmod->get_int($storedVerKey));
}

sub _cachedVersion
{
    my ($self) = @_;

    return $self->{'cachedVersion'};
}


# Method: rows
#
#     Return a list containing the table rows     
#
# Parameters:
#
#     filter - string to filter result
#       page   - int the page to show the result from
#     
# Returns:
#
#    Array ref containing the rows 
sub rows
{
    my ($self, $filter, $page)  = @_;

    # The method which takes care of loading the rows
    # from gconf is _rows(). 
    #
    # rows() tries to cache the data to avoid extra access
    # to gconf
    my $gconfmod = $self->{'gconfmodule'};
    my $storedVersion = $self->_storedVersion();
    my $cachedVersion = $self->_cachedVersion();;

    if (not defined($storedVersion)) {
        $storedVersion = 0;
    }

    if (not defined($cachedVersion)) {
        $self->{'cachedRows'} = $self->_rows();
        $self->{'cachedVersion'} = 0;
    } else {
        if ($storedVersion != $cachedVersion) {
            $self->{'cachedRows'} = $self->_rows();
            $self->{'cachedVersion'} = $storedVersion;
        }
    }

    if ( $self->order() == 1) {
        return $self->_filterRows($self->{'cachedRows'}, $filter, 
                $page);
    } else {
        return $self->_filterRows(
                $self->_tailoredOrder($self->{'cachedRows'}),
                $filter, $page);
    }
}


# Method: enabledRows
#
#       Returns those rows which are enabled, that is, those whose
#       field 'enabled' is set to true. If there is no enabled field,
#       all rows are returned.
#
# Returns:
#
#       The same as <EBox::Model::DataTable::rows> but only including
#       those are enabled.
#
sub enabledRows
{
    my ($self) = @_;

    my $fields = $self->fields();
    unless ( grep { $_ eq 'enabled' } @{$fields}) {
        return $self->rows();
    }
    return $self->_find('enabled' => 1, 1, 'row');

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

      return scalar( @{ $self->{'gconfmodule'}->all_dirs_base($self->{'directory'})});

  }

sub _rows
{
    my $self = shift;
    my $gconfmod = $self->{'gconfmodule'};

    my  %order;
    if ($self->table()->{'order'}) {
        my @order = @{$gconfmod->get_list($self->{'order'})};    
        my $i = 0;
        foreach my $id (@order) {
            $order{$id} = $i;
            $i++;
        }
    }

    my @rows;
    for my $id (@{$gconfmod->all_dirs_base($self->{'directory'})}) {
        my $hash = $gconfmod->hash_from_dir("$self->{'directory'}/$id");
    # Workaround: It seems that deleting a dir in gconf 
    # doesn't work  ok sometimes and it keeps available after 
    # deleting it for a while.
    # To workaround this issue we skip those rows marked with
    # "removed" key
        next if (exists $hash->{'removed'});

        my $row = $self->row($id);
        if (%order) {
            $hash->{'order'} = $order{$id};
            $rows[$order{$id}] = $row;
        } else {
            push(@rows, $row);
        }
    }


    return \@rows;
}

sub _setCacheDirty
{
    my $self = shift;

    my $gconfmod = $self->{'gconfmodule'};
    my $storedVerKey = $self->{'directory'} . '/version';
    my $storedVersion = $gconfmod->get_int($storedVerKey);
    my $newVersion;

    if (defined($storedVersion)) {
        $newVersion = $storedVersion + 1;
    } else {
        $newVersion = 1;
    }

    $gconfmod->set_int($storedVerKey, $newVersion);
}

sub _increaseStoredAndCachedVersion
{
    my $self = shift;

    my $gconfmod = $self->{'gconfmodule'};
    my $storedVerKey = $self->{'directory'} . '/version';
    my $storedVersion = $gconfmod->get_int($storedVerKey);
    my $newVersion;

    if (defined($storedVersion)) {
        $newVersion = $storedVersion + 1;
    } else {
        $newVersion = 1;
    }

    $gconfmod->set_int($storedVerKey, $newVersion);
    $self->{'cachedVersion'} = $newVersion;
}

# Method: _tailoredOrder
#
#       Function to be overriden by the subclasses in order to do
#       ordering in a different way as normal order is done.  It's
#       functional if only if <EBox::Model::DataTable::order> is set
#       to 0.
#
# Parameters:
#
#       rows - an array ref with the hashes with the rows to order
#
# Returns:
#
#       an array ref with the order from the current model with a
#       hash ref of every row
#
sub _tailoredOrder # (rows)
{
    my ($self, $rows) = @_;

    # Sorted by sortedBy field element if it's given
    my $fieldName = $self->sortedBy();
    if ( $fieldName ) {
        if ( $self->fieldHeader($fieldName) ) {
            my @sortedRows =
              sort {
                  $a->elementByName($fieldName)->cmp($b->elementByName($fieldName))
              } @{$rows};
            return \@sortedRows;
        }
    }
    return $_[1];

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

    my $olddir = $self->{'gconfdir'};
    return if ($dir eq $olddir);

# If there's a directory change we try to keep cached the last
# directory as it is likely we are asked again for it
    my $cachePerDir = $self->{'cachePerDirectory'};
    $cachePerDir->{$olddir}->{'cachedRows'} = $self->{'cachedRows'};
    $cachePerDir->{$olddir}->{'cachedVersion'} = $self->{'cachedVersion'};

    if ($cachePerDir->{$dir}) {
        $self->{'cachedRows'} = $cachePerDir->{$dir}->{'cachedRows'};
        $self->{'cachedVersion'} =
            $cachePerDir->{$dir}->{'cachedVersion'};
    } else {
        $self->{'cachedRows'} = undef;
        $self->{'cachedVersion'} = undef;
    }

    $self->{'gconfdir'} = $dir;
    $self->{'directory'} = "$dir/keys";
    $self->{'order'} = "$dir/order";
    $self->{'table'}->{'gconfdir'} = $dir;

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

# Method: printableName
#
#       Get the i18ned name
#
# Returns:
#
#       What <EBox::Model::DataTable::printableModelName> returns
#
sub printableName
  {

      my ($self) = @_;

      return $self->printableModelName();

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

# Method: headTitle
#
#       Get the i18ned name of the page where the model is contained, if any
#
# Returns:
#
#   string
#
sub headTitle 
  {

      my ($self) = @_;

      return $self->printableModelName();

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

    return $self->{'gconfdir'};

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
    } elsif ( defined ( $self->modelDomain() )) {
        # This is autogenerated menuNamespace got from the model
        # domain and the table name
        my $menuNamespace = $self->modelDomain() . '/View/' . $self->tableName();
        if ( $self->index() ) {
            return $menuNamespace . '/' . $self->index();
        } else {
            return $menuNamespace;
        }
    } else {
        return undef;
    }
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

    return $self->{'gconfmodule'}->get_list( $self->{'order'} );

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

# Method: indexField
#
#       Get the index field name used to index the model, if any
#
# Returns:
#
#       String - the field name used as index, or undef if it is not
#       defined
#
sub indexField
{

    my ($self) = @_;

    my $indexField = $self->table()->{'index'};
    if ( defined ( $indexField )) {
        # Check the index field name exists
        my $fieldType = $self->fieldHeader($indexField);
        # Check if it is unique
        unless ( $fieldType->unique() ) {
            throw EBox::Exceptions::Internal('Declared index field ' .
                    $indexField . ' is not unique.' .
                    'Please, declare an index which ' .
                    'is unique at ' . $self->tableName() . 
                    'description');
        }
    }
    return $indexField;

}

# Method: setIndexField
#
#      Set the index field name used to index the model, if any
#
# Parameters:
#
#       indexField - String the field name used as index
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - thrown if the selected field is
#       not in the model description
#
#       <EBox::Exceptions::Internal> - thrown if the selected field is
#       not unique
#
sub setIndexField
{

    my ($self, $indexField) = @_;

    $self->table()->{'index'} = $indexField;
    $self->indexField();

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
#      moveUp - when a row is moved up
#      moveDown - when a row is moved down
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
    my ($self, $action) = @_;

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

    my ($self, $newMessage) = @_;

    $self->table()->{'message'} = $newMessage;

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
    my $self = shift;

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
#     Return a hash containing the fields which compose each row    
#    and dont have a defined Setter
#
# Returns:
#
#    Hash ref containing the field names as keys
#
sub fieldsWithUndefSetter
{
    my $self = shift;

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

# Method: pages 
#
#    Return the number of pages
#
# Parameters:
#
#     $rows - hash ref containing the rows, if undef it will use
#         those returned by rows()
# Returns:
#
#    integer - containing the value
sub pages 
{
    my ($self, $filter) = @_;

    my $pageSize = $self->pageSize();
    unless (defined($pageSize) and ($pageSize =~ /^\d+/) and ($pageSize > 0)) {
        return 1;
    }

    my $rows = $self->rows($filter);

    my $nrows = @{$rows};

    if ($nrows == 0) {
        return 0;
    } else {
        return  ceil($nrows / $pageSize) - 1;
    }

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
#     Hash ref - containing the printable values of the matched row
#
#     undef - if there was not any match
#     
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub find
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, undef, 'printableValue')};

    if (@matched) {
        return $matched[0];
    } else {
        return undef;
    }
}

# Method: findAll
#
#    Return all the rows which matches the value of the given
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
#     Array ref of <EBox::Model::Row> 
#     
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findAll
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, 1, 'printableValue')};

    return \@matched;

}

# Method: findValue
#
#    Return the first row which matches the value of the given
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
#     find('default' => 1);
#
# Returns:
#
#    An object of <EBox::Model::Row>
#    
#    undef if there was not any match
#     
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findValue
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, undef, 'value')};

    if (@matched) {
        return $matched[0];
    } else {
        return undef;
    }
}

# Method: findAllValue
#
#    Return all the rows which matches the value of the given
#    field against the data returned by the method value()
#
#    If you want to match against value use
#    <EBox::Model::DataTable::find>
#
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
#   An array ref of <EBox::Model::Row> objects
#     
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findAllValue
{
    my ($self, $fieldName, $value) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, 1, 'value')};

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
#     fieldName => value
#
#     Example:
#
#     findId('default' => 1);
#
# Returns:
#
#       String - the row identifier from the first matched rule
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

    my $rows = $self->rows();

    foreach my $row (@{$rows}) {
        my $element = $row->elementByName($fieldName);
        my $plainValue = $element->value(); 
        my $printableValue = $element->printableValue();
        if ((defined($plainValue) and $plainValue eq $value) 
            or (defined($printableValue) and $printableValue eq $value)) {

            return $row->id();
        }
    }

    return undef;

}

# Method: findRow
#
#    Return the first row which matches the value of the given field
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
#          <EBox::Model::DataTable::rows>,
#          <EBox::Model::DataTable::printableValueRows> and
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

    if ( $methodName eq 'domain' ) {
        return $self->{gconfmodule}->domain();
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
#       Class method to return the viewer from this model. This method
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

# Method: pageSize
#     
#     Return the number of rows per page
#
# Returns:
#    
#    int - page size
sub pageSize
{
    my ($self) = @_;

    return $self->{'pageSize'}
}

# Method: setPageSize
#     
#     set the number of rows per page
#
# Parameters:
#
#     rows - number of rows per page
#     
# Returns:
#    
#    int - page size
sub setPageSize
{
    my ($self, $rows) = @_;

    unless (defined ($rows)) {
        throw EBox::Exceptions::MissingArgument("Missing field rows"); 
    }

    $self->{'pageSize'} = $rows;

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

    my  $function = 'changeView("%s", "%s", "%s", "%s",'.
            '"%s", %s, %s)';

    my $table = $self->table();
    return  sprintf ($function, 
            $table->{'actions'}->{'changeView'},
            $table->{'tableName'},
            $table->{'gconfdir'},
            $type,
            $editId,
            $page,
            $isFilter
            );
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
    my ($self, $page) = @_;

    my  $function = 'addNewRow("%s", "%s", %s, "%s", %s)';

    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();
    $fields =~ s/'/\"/g;
    return  sprintf ($function, 
            $table->{'actions'}->{'add'},
            $table->{'tableName'},
            $fields,
            $table->{'gconfdir'},
            $page);
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

    my  $function = 'changeRow("%s", "%s", %s, "%s",'.
            '"%s", %s)';

    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();
    $fields =~ s/'/\"/g;
    return  sprintf ($function, 
            $table->{'actions'}->{'editField'},
            $table->{'tableName'},
            $fields,
            $table->{'gconfdir'},
            $editId,
            $page);
}

# Method: actionClicked 
#
#     Return the javascript function for actionClicked
#
# Parameters:
#    
#    (POSITIONAL)
#    action - move or del
#    editId - row id to edit
#    direction - up or down
#     page - page number
#
# Returns:
#
#     string - holding a javascript funcion
sub actionClickedJS
{
    my ($self, $action, $editId, $direction, $page) = @_;

    unless ($action eq 'move' or $action eq 'del') {
        throw EBox::Exceptions::External("Wrong action $action");
    }

    if ($action eq 'move' 
            and not ($direction eq 'up' or $direction eq 'down')) {

        throw EBox::Exceptions::External("Wrong action $direction");
    }

    my  $function = 'actionClicked("%s", "%s", "%s", "%s",'.
            '"%s", "%s", %s)';

    if ($direction) {
        $direction = "dir=$direction";
    } else {
        $direction = "";
    }    

    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();
    $fields =~ s/'/\"/g;
    return  sprintf ($function, 
            $table->{'actions'}->{$action},
            $table->{'tableName'},
            $action,
            $editId,
            $direction,
            $table->{'gconfdir'},
            $page);
}

# Group: Protected methods

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
       'moveUp'    => __x('{row} moved up', row => $rowName),
       'moveDown'  => __x('{row} moved down', row => $rowName),
      );

    foreach my $action (keys (%defaultMessages)) {
        unless ( exists $table->{'messages'}->{$action} ) {
            $table->{'messages'}->{$action} = $defaultMessages{$action};
        }
    }

}

# Group: Private helper functions

# Method: _find
#
#    (PRIVATE)
#    
#    Used by find and findAll to find rows in a table    
#
# Parameters:
#
#    (POSITIONAL)
#    
#    fieldName - the name of the field to match
#    value - value we want to match
#    allMatches -   1 or undef to tell the method to return just the
#        first match or all of them
#
#    kind - String if 'printableValue' match against
#    printableValue, if 'value' against value, 'row' match against
#    value returning the row *(Optional)* Default value: 'value'
#
# Example:
#
#     _find('default',  1, undef, 'printableValue');
#
# Returns:
#
#    An array of hash ref containing the rows with their printable
#    values
#
sub _find
{
    my ($self, $fieldName, $value, $allMatches, $kind) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    $kind = 'value' unless defined ( $kind );

    my $rows = $self->rows();

    my @matched;
    foreach my $row (@{$rows}) {
        my $element = $row->elementByName($fieldName);
        next unless (defined($element));

        my $eValue;
        if ($kind eq 'printableValue') {
            $eValue = $element->printableValue();
        } else {
            $eValue = $element->value();
        }
        next unless ($eValue eq $value);
        my $match;
        
        push (@matched, $row);
        return (\@matched) unless ($allMatches);
    }

    return \@matched;
}

sub _checkFieldIsUnique
{
    my ($self, $newData) = @_;

    # Call _rows instead of rows because of deep recursion
    my $rows = $self->_rows();
    foreach my $row (@{$rows}) {
        my $rowField = $row->elementByName($newData->fieldName());
        if ( $newData->isEqualTo($rowField) ) {
            throw EBox::Exceptions::DataExists(
                'data'  => $newData->printableName(),
                'value' => $newData->printableValue(),
               );
        }
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
    foreach my $row (@{$rows}) {
        # Compare if the row identifier is different
        next if ( defined($rowId) and $row->{'id'} eq $rowId);
        my $nEqual = grep
          { $row_ref->{$_}->isEqualTo($row->elementByName($_)) }
            @{$fields};
        next unless ( $nEqual == scalar(@{$fields}) );
        throw EBox::Exceptions::DataExists(
                                           'data'  => $self->printableRowName(),
                                           'value' => ''
                                           );
    }

}


# Deprecated?
sub _checkAllFieldsExist
{
    my ($self, $params) = @_;

    my $types = $self->table()->{'tableDescription'};

    foreach my $field (@{$types}) {

        unless ($field->paramExist($params)) {
            throw
                Exceptions::MissingArgument($field->printableName());
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
        unless ( $field->optional() ) {
            push ( @compulsory, $fieldName );
        }
    }

    return \@compulsory;

}

sub _checkRowExist
{
    my ($self, $id, $text) = @_;

    my $gconfmod = $self->{'gconfmodule'};
    my $dir = $self->{'directory'};

    unless ($gconfmod->dir_exists("$dir/$id")) {
        throw EBox::Exceptions::DataNotFound(
                data => $text,
                value => $id);
    }
}

# Insert the id element in selected position, if the position is the
# last + 1 is inserted after the last one
sub _insertPos #(id, position)
{
    my ($self, $id, $pos) = @_;

    my $gconfmod = $self->{'gconfmodule'};

    my @order = @{$gconfmod->get_list($self->{'order'})};

    if (@order == 0) {
        push (@order, $id);
    } elsif ($pos == 0) {
        @order = ($id, @order);
    } elsif ($pos == @order) {
        push (@order, $id);
    } else {
        splice (@order, $pos, 1, ($id, $order[$pos]));
    }


    $gconfmod->set_list($self->{'order'}, 'string', \@order);
}

sub _removeOrderId
{
    my ($self, $id) = @_;

    my $gconfmod = $self->{'gconfmodule'};
    my @order = @{$gconfmod->get_list($self->{'order'})};

    @order = grep (!/$id/, @order);

    $gconfmod->set_list($self->{'order'}, 'string', \@order);
}

sub _swapPos
{
    my ($self, $posA, $posB ) = @_;

    my $gconfmod = $self->{'gconfmodule'};
    my @order = @{$gconfmod->get_list($self->{'order'})};

    my $temp = $order[$posA];
    $order[$posA] =  $order[$posB];
    $order[$posB] = $temp;

    $gconfmod->set_list($self->{'order'}, 'string', \@order);
    $self->_setCacheDirty();
    $self->_reorderCachedRows($posA, $posB);
}

sub _orderHash
{
    my $self = shift;
    my $gconfmod = $self->{'gconfmodule'};

    my  %order;
    if ($self->table()->{'order'}) {
        my @order = @{$gconfmod->get_list($self->{'order'})};    
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

sub _hashFromDir
{
    my ($self, $id) = @_;

    my $gconfmod = $self->{'gconfmodule'};
    my $dir = $self->{'directory'};

    unless (defined($id)) {
        return;
    }

    my $row = $gconfmod->hash_from_dir("$dir/$id");
    $row->{'id'} = $id;
    $row->{'order'} = $self->_rowOrder($id);

    return $row;
}

sub _removeHasManyTables
{
    my ($self, $id) = @_;

    foreach my $type (@{$self->table()->{'tableDescription'}}) {
        my $dir = "$id/" . $type->fieldName();
        next unless ($self->{'gconfmodule'}->dir_exists($dir));
        $self->{'gconfmodule'}->delete_dir("$id/$dir");
    }

}

# FIXME This method must be in ModelManager
#sub _warnIfIdIsUsed
#{
#    my ($self, $id) = @_;
#    
#    my $manager = EBox::Model::ModelManager->instance();
#    my $modelName = $self->modelName();
#    my $tablesUsing;
#    
#    for my $name  (values %{$manager->modelsUsingId($modelName, $id)}) {
#        $tablesUsing .= '<br> - ' .  $name ;
#    }
#
#    if ($tablesUsing) {
#        throw EBox::Exceptions::DataInUse(
#            __('The data you are removing is being used by
#            the following dtables:') . '<br>' . $tablesUsing);
#    }
#}
#
## FIXME This method must be in ModelManager
#sub _warnOnChangeOnId 
#{
#    my ($self, $id, $changeData, $oldRow) = @_;
#    
#    my $manager = EBox::Model::ModelManager->instance();
#    my $modelName = $self->modelName();
#    my $tablesUsing;
#    
#    for my $name  (keys %{$manager->modelsUsingId($modelName, $id)}) {
#        my $model = $manager->model($name);
#        my $issue = $model->warnOnChangeOnId($id, $changeData, $oldRow);
#        if ($issue) {
#            $tablesUsing .= '<br> - ' .  $issue ;
#        }
#    }
#
#    if ($tablesUsing) {
#        throw EBox::Exceptions::DataInUse(
#            __('The data you are modifying is being used by
#            the following tables:') . '<br>' . $tablesUsing);
#    }
#}

# Method: _setDomain
#
#     Set the translation domain to the one stored in the model, if any
sub _setDomain
{
    my ($self) = @_;

    my $domain = $self->{'domain'};
    if ($domain) {
        $self->{'oldDomain'} = settextdomain($domain);
    }
}

# Method: _restoreDomain
#
#     Restore the translation domain privous to _setDomain
sub _restoreDomain
{
    my ($self) = @_;

    my $domain = $self->{'oldDomain'};
    if ($domain) {
        settextdomain($domain);
    }
}

# Method: _notifyModelManager
#
#     Notify to the model manager that an action has been performed on
#     this model
#
sub _notifyModelManager
{
    my ($self, $action, $row) = @_;

    my $manager = EBox::Model::ModelManager->instance();
    my $modelName = $self->modelName();

    return $manager->modelActionTaken($modelName, $action, $row);
}

# Method: _nofityCompositeManager
#
#     Notify to the composite manager that an action has been performed on
#     this model
#
sub _notifyCompositeManager
{
    my ($self, $action, $row) = @_;

    my $manager = EBox::Model::CompositeManager->Instance();
    my $modelName = $self->modelName();

    return $manager->modelActionTaken($modelName, $action, $row);
}

sub _filterRows
{
    my ($self, $rows, $filter, $page) = @_;

    # Filter using regExp
    my @newRows;
    if (defined($filter) and length($filter) > 0) {
        my @words = split (/\s+/, $filter);
        my $totalWords = scalar(@words);
        for my $row (@{$rows}) {
            my $nwords = $totalWords;
            my %wordFound;        
            for my $element (@{$row->elements()}) {
                my $printableVal = $element->printableValue();
                next unless defined($printableVal);
                my $rowFound;
                for my $regExp (@words) {
                    if (not exists $wordFound{$regExp} 
                            and $printableVal =~ /$regExp/) {
                        $nwords--;
                        $wordFound{$regExp} = 1;
                        unless ($nwords) {
                            push(@newRows, $row);
                            $rowFound = 1;
                            last;
                        }
                    }

                }
                last if $rowFound;
            }
        }
    } else {
        @newRows = @{$rows};
    }

    # Paging
    unless (defined($page) and $self->pageSize()) {
        return \@newRows;
    }


    my $pageSize = $self->pageSize();
    my $tpages;
    if (@newRows == 0) {
        $tpages = 0;
    } else {
        $tpages = ceil(@newRows / $pageSize) - 1;
    }

    if ($page < 0) { $page = 0; }
    if ($page > $tpages) { $page = $tpages; }


    my $index;
    if ($tpages > 0 and defined($pageSize) and $pageSize > 0) {
        $index = $page * $pageSize;
    } else {
        $index = 0;
        $pageSize = @{$rows} - 1;
    }
    my $offset = $index + $pageSize;
    if ($page == $tpages) {
        $offset = @newRows;
    }

    if ($tpages > 0) {
        return [@newRows[$index ..  ($offset - 1)]];
    } else {
        return \@newRows;
    }
}

# Set the default controller to that actions which do not have a
# custom controller
sub _setControllers
{

    my ($self) = @_;

    # Table is already defined
    my $table = $self->{'table'};

    my $defAction = $table->{'defaultController'};
    if ( (not defined ( $defAction )) and defined ( $self->modelDomain() )) {
        # If it is not a defaultController, we try to guess it from
        # the model domain and its name
        $defAction = '/ebox/' . $self->modelDomain() . '/Controller/' .
            $self->{'table'}->{'tableName'};
        if ( $self->index() ne '' ) {
            $defAction .= '/' . $self->index();
        }
    }
    if ($defAction) {
        foreach my $action (@{$table->{'defaultActions'}}) {
            # Do not overwrite existing actions
            unless ( exists ( $table->{'actions'}->{$action} )) {
                $table->{'actions'}->{$action} = $defAction;
            }
        }
    }

}

# Method:

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

    my ($self) = @_;

    my $table = $self->table();
    my @parameters;
    foreach my $type ( @{$table->{'tableDescription'}}) {
        push ( @parameters, $type->fields());
    }

    my $fieldsWithOutSetter = $self->fieldsWithUndefSetter();
    my @paramsWithSetter = grep {!$fieldsWithOutSetter->{$_}} @parameters;
    push (@paramsWithSetter, 'filter', 'page');
    my $paramsArray = '[' . "'" . pop(@paramsWithSetter) . "'";
    foreach my $param (@paramsWithSetter) {
        $paramsArray .= ', ' . "'" . $param . "'";
    }
    $paramsArray .= ']';

    return $paramsArray;

}

# Method: _isOptionsCacheDirty
#
#    Check if the options cache is dirty. In case of being empty
#    we return empty too
#
sub _isOptionsCacheDirty
{
    my ($self, $field) = @_;

    unless (defined($field)) {
        throw EBox::Exceptions::MissingArgument("field's name")
    }

    return 1 unless (exists $self->{'optionsCache'}->{$field});

    my $cachedVersion = 
        $self->{'optionsCache'}->{$field}->{'cachedVersion'};

    return ($cachedVersion ne $self->_storedVersion());
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
        my $instancedTypes = $self->_fillTypes($paramsRef);
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

    if ( $self->_actionAppliedToModel( 'get', $methodName) ) {
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
    $self->_checkMethodSignature( 'set', $methodName, $paramsRef);

    if ( $self->_actionAppliedToModel( 'set', $methodName) ) {
        my $updateId = $self->_autoloadGetId($self, $paramsRef);
        # Remove the id from the params
        shift ( @{$paramsRef} );
        # Convert array ref to hash ref
        my %params = @{$paramsRef};
        $paramsRef = \%params;
        # Simple add (add a new row to a model including submodels...)
        my $instancedTypes = $self->_fillTypes($paramsRef);
        $self->setTypedRow($updateId, $instancedTypes, force => 0);

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

    my $paramsRef = Clone::clone($oldParamsRef);

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
            my $manager = EBox::Model::ModelManager->instance();
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
                throw EBox::Exceptions::Internal('Illegal undefined method. It should ' .
                        'follow this pattern: add[<tableName>] if ' .
                        ' it has no HasMany fields');
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

    my ($self, $params) = @_;

# Check all given fields to fill are in the table description
    foreach my $paramName (keys %{$params}) {
        unless ( $paramName eq any(@{$self->fields()}) ) {
            throw EBox::Exceptions::Internal("$paramName does not exist in the " .
                    'model ' . $self->name() . ' description');
        }
    }

    my $filledTypes = {};
    foreach my $fieldName (@{$self->fields()}) {
        if ( exists $params->{$fieldName} ) {
            my $field = $self->fieldHeader($fieldName);
            my $paramValue = $params->{$fieldName};
            my $newType = $field->clone();
            $newType->setValue($paramValue);
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
    my $submodel = EBox::Model::ModelManager->instance()->model(
            $foreignModelName
            );
    $submodel->setDirectory($directory);

    # Addition to a submodel
    foreach my $subModelRow (@{$subModelRows}) {
        my $instancedTypes = $submodel->_fillTypes($subModelRow);
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
    my $submodel = EBox::Model::ModelManager->instance()->model(
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

    my $paramsRef = Clone::clone($origParamsRef);

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
        $model = EBox::Model::ModelManager->instance()->model(
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
#              /ebox/Controller/Foo
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
#              /ebox/Controller/Foo
sub popRedirection
{
    my ($self) = @_;

    my $redirection = $self->{redirection};
    $self->{redirection} = undef;

    return $redirection;
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
            unless ( defined ( $model->find( id => $paramsRef->[0] ))) {
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
                my $rows = $model->rows();
                if ( exists ( $rows->[$paramsRef->[0]] )) {
                    $id = $rows->[$paramsRef->[0]]->{id};
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
                                       gconfmodule => $row->GConfModule());
    $newRow->setId($row->id());
    $newRow->setOrder($row->order());

    my @modelFields = @{$self->fields()};
    foreach my $fieldName ( @{$fieldNames} ) {
        unless ( $fieldName eq any(@modelFields) ) {
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


sub _fileFields
{
    my ($self) = @_;

    my $tableDesc = $self->table()->{tableDescription};
    my @files = grep { $_->isa('EBox::Types::File') } @{ $tableDesc };

    return @files;
}


sub backupFiles
{
    my ($self) = @_;

    my @files = $self->_fileFields();
    @files or return;

    foreach my $file (@files) {
        $file->backup();
    }

}


sub restoreFiles
{
    my ($self) = @_;

    my @files = $self->_fileFields();
    @files or return;

    foreach my $file (@files) {
        $file->restore();
    }
}

sub backupFilesPaths
{
    my ($self) = @_;

    my @paths =  map {
        $_->path();
    }  grep {  
        $_->exist()
    }
    $self->_fileFields();

    return \@paths;
}


1;
