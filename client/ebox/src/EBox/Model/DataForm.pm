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

# Class: EBox::Model::DataForm
#
#       An specialized model from <EBox::Model::DataTable> which
#       stores just one row. In fact, the viewer and setter is
#       different.

package EBox::Model::DataForm;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::Internal;
use EBox::Gettext;

###################
# Dependencies
###################
use Perl6::Junction qw(any);
use NEXT;

# Core modules
use Error qw(:try);
use Clone qw(clone);

# Group: Public methods

# Constructor: new
#
#       Create the <EBox::Model::DataForm> model instance
#
# Parameters:
#
#       gconfmodule - <EBox::GConfModule> the GConf eBox module which
#       gives the environment where to store data
#
#       directory - String the subdirectory within the environment
#       where the data will be stored
#
#       domain    - String the Gettext domain
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless ( $self, $class );

      # Change the directory to store the form data since it's not
      # required a lot complexity
      $self->{directory} = $self->{gconfdir};

      return $self;

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

      return $self->_row();

  }

# Method: isRowReadOnly
#
#       Return whether the row is read only or not. It ignores any
#       additional parameter
#
# Overrides:
#
#       <EBox::Model::DataTable::isRowReadOnly>
#
sub isRowReadOnly
  {

      my ($self) = @_;

      my $row = $self->row();
      return undef unless ( $row );

      return $row->{'readOnly'};

  }

# Method: moveUp
#
#       Move a row up. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::moveUp>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub moveUp
  {

      throw EBox::Exceptions::Internal('It cannot move up a row in an ' .
                                       'one-rowed table');

  }

# Method: moveDown
#
#       Move a row down. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::moveDown>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub moveDown
  {

      throw EBox::Exceptions::Internal('It cannot move down a row in an ' .
                                       'one-rowed table');

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
    my ($self, $id, $force ) = @_;

    if ( $force ) {
        $self->removeAll($force);
    } else {
        throw EBox::Exceptions::Internal('It cannot remove a row'
                                         . 'in an one-rowed table. '
                                         . 'Use removeAll instead.');
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

    if ( $force ) {
        # Remove the data
        $self->{gconfmodule}->delete_dir($self->{directory});
    } else {
        throw EBox::Exceptions::Internal('It cannot remove data unless '
                                         . 'it is forcing the operation');
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
#	Set an existing row. The unique row is set here. If there was
#	no row. It will be created.
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

      # Check cached row id
      if ( $self->_hasRow() ) {
          $self->validateRow('update', @_);
          # We can only set those types which have setters
          my @newValues = @{$self->setterTypes()};

          my $changedData;
          for (my $i = 0; $i < @newValues ; $i++) {
              my $newData = clone($newValues[$i]);
              $newData->setMemValue(\%params);

              $changedData->{$newData->fieldName()} = $newData;
          }

          $self->_setTypedRow( $changedData,
                               force => $force,
                               readOnly => $params{'readOnly'});
      } else {
          # Add a new one
          $self->_addRow(%params);
      }

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

    if ( $self->_hasRow() ) {
        $self->_setTypedRow($paramsRef, %optParams);
    } else {
        $self->_addTypedRow($paramsRef);
    }

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

    unless ( keys %params > 0 ) {
        throw EBox::Exceptions::MissingArgument('Missing parameters to set their value');
    }

    my $typedParams = $self->_fillTypes(\%params);

    $self->setTypedRow(0, $typedParams, force => $force,
                       readOnly => $readOnly);

}

# Method: rows
#
#       Return a list containing the table rows. Just one row in this case
#
# Overrides:
#
#       <EBox::Model::DataTable::rows>
#
sub rows
  {

      my ($self) = @_;

      return [ $self->_row() ];

  }

# Method: printableValueRows
#
#       Return a list containing the table rows and the printable
#       value of every field. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::printableValueRows>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
#sub printableValueRows
#  {
#
#      throw EBox::Exceptions::Internal('It cannot return more than one row in an ' .
#                                       'one-rowed table');
#
#  }
#
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

# Method: rowUnique
#
#
# Overrides:
#
#       <EBox::Model::DataTable::rowUnique>
#
sub rowUnique
  {

      return 1;

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
#      oldRow - hash ref containing the old row content, return the
#      same hash ref as <EBox::Model::DataForm::row> does
#
sub formSubmitted
  {

  }

# Method: AUTOLOAD
#
#      This method will intercept any call done to undefinede
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

      my $row = $self->row();

      # Get the attribute and its suffix if any <attr>(Value|PrintableValue|Type|)
      my ($attr, $suffix) = $methodName =~ m/^(.+?)(Value|PrintableValue|Type|)$/;

      unless ( any( keys ( %{$row->{valueHash}} ) ) eq $attr ) {
          # Try with the parent autoload
          return $self->NEXT::ACTUAL::AUTOLOAD(@params);
      }

      # If no suffix is given used
      unless ( $suffix ) {
          # Use the default value
          $suffix = 'Value';
      }

      if ( $suffix eq 'Value' ) {
          return $row->{plainValueHash}->{$attr};
      } elsif ( $suffix eq 'PrintableValue' ) {
          return $row->{printableValueHash}->{$attr};
      } elsif ( $suffix eq 'Type' ) {
          return $row->{valueHash}->{$attr};
      }

      return;

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

      unless ( exists $self->table()->{'messages'}->{'update'} ) {
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

# Method: size
#
# Overrides:
#
#     <EBox::Model::DataTable::size>
#
# Returns:
#
#     Int - the number of rows which the model contains (stored in
#     GConf)
#
sub size
{
    my ($self) = @_;
    if ( $self->_hasRow() ) {
        return 1;
    } else {
        return 0;
    }
}

# Group: Private methods

# Check if the model is empty
sub _hasRow
  {

      my ($self) = @_;

      return $self->{'gconfmodule'}->dir_exists($self->{'directory'});

  }

# Add a row to the system without id. Its a reimplementation of
# addRow so it should be looked up when any change is done at
# DataTable stuff
sub _addRow
  {

      my ($self, %params) = @_;

      my $tableName = $self->tableName();
      my $dir = $self->{'directory'};
      my $gconfmod = $self->{'gconfmodule'};

      $self->validateRow('add', %params);

      my @userData;
      my $userData;
      foreach my $type (@{$self->table()->{'tableDescription'}}) {
          my $data = clone($type);
          $data->setMemValue(\%params);

          push (@userData, $data);
          $userData->{$data->fieldName()} = $data;
      }

#      $self->validateTypedRow('add', $userData);
#
#      foreach my $data (@userData) {
#          $data->storeInGConf($gconfmod, "$dir");
#          $data = undef;
#      }
#
#      $gconfmod->set_bool("$dir/readOnly", $params{'readOnly'});
#
#      $self->setMessage($self->message('update'));
#      $self->updatedRowNotify($self->row());
#      $self->_notifyModelManager('add', $self->row());
#
#      $self->_setCacheDirty();
      $self->_addTypedRow($userData, readOnly => $params{'readOnly'});

  }

# Add a row to the system without id. Its a reimplementation of
# addTypedRow so it should be looked up when any change is done at
# DataTable stuff
sub _addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $tableName = $self->tableName();
    my $dir = $self->{'directory'};
    my $gconfmod = $self->{'gconfmodule'};
    my $readOnly = delete $optParams{'readOnly'};

    # Check compulsory fields
    $self->_checkCompulsoryFields($paramsRef);

    $self->validateTypedRow('add', $paramsRef, $paramsRef);

    foreach my $data (values ( %{$paramsRef} )) {
        $data->storeInGConf($gconfmod, "$dir");
        $data = undef;
    }
    $gconfmod->set_bool("$dir/readOnly", $readOnly);

    $self->setMessage($self->message('update'));
    $self->updatedRowNotify($self->row());
    $self->_notifyModelManager('add', $self->row());
    $self->_notifyCompositeManager('add', $self->row());

    $self->_setCacheDirty();

}

# Set a row without id and with types. It's a reimplementation of
# setTypedRow so it should be looked over when any change is done at
# DataTable stuff
sub _setTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $force = delete $optParams{'force'};
    my $readOnly = delete $optParams{'readOnly'};

    my $dir = $self->{'directory'};
    my $gconfmod = $self->{'gconfmodule'};

    my $oldRow = $self->row();
    my $oldValues = $oldRow->{'valueHash'};

    my @setterTypes = @{$self->setterTypes()};

    my $changedData = { };
    my $allData = $oldValues;
    my @changedData = ();
    foreach my $paramName (keys %{$paramsRef}) {
        unless ( exists ( $oldValues->{$paramName} )) {
            throw EBox::Exceptions::Internal('Field to update $paramName does not ' .
                                             'exist in this model');
        }

        unless ( $paramName ne any(@setterTypes) ) {
            throw EBox::Exceptions::Internal('Trying to update a non setter type');
        }

        my $paramData = $paramsRef->{$paramName};
        if ( $oldValues->{$paramName}->isEqualTo($paramsRef->{$paramName})) {
            next;
        }

        $paramData->setRow($oldRow);
        $changedData->{$paramName} = $paramData;
        push ( @changedData, $paramData);
        $allData->{$paramName} = $paramData;
    }

    # TODO: Check its usefulness
    $self->validateTypedRow('update', $changedData, $allData);

    # If force != true atomaticRemove is enabled it means
    # the model has to automatically check if the row which is 
    # about to be changed is referenced elsewhere and this change
    # produces an inconsistent state
    if ((not $force) and $self->table()->{'automaticRemove'}) {
        my $manager = EBox::Model::ModelManager->instance();
        $manager->warnOnChangeOnId($self->tableName(), 0, $changedData, $oldRow);
    }

    my $modified = undef;
    for my $data (@changedData) {
        $data->storeInGConf($gconfmod, "$dir");
        $modified = 1;
    }

    # update readonly if change
    my $rdOnlyKey = "$dir/readOnly";
    if (defined ( $readOnly )
        and ($readOnly xor $gconfmod->get_bool("$rdOnlyKey"))) {

        $gconfmod->set_bool("$rdOnlyKey", $readOnly);

    }

    if ($modified) {
        $self->_setCacheDirty();
        $self->setMessage($self->message('update'));
        # Dependant models may return some message to inform the user
        my $depModelMsg = $self->_notifyModelManager('update', $self->row());
        if ( defined ($depModelMsg)
             and ( $depModelMsg ne '' and $depModelMsg ne '<br><br>' )) {
            $self->setMessage($self->message('update') . '<br><br>' . $depModelMsg);
        }
        $self->_notifyCompositeManager('update', $self->row());
        $self->updatedRowNotify($oldRow, $force);
    }
}

# Return a row from within the model. It's a reimplementation of
# SUPER::row so it should take care about any change at superclass
sub _row
  {

      my ($self) = @_;

      my $dir = $self->{'directory'};
      my $gconfmod = $self->{'gconfmodule'};
      my $row = {};

      unless ($gconfmod->dir_exists("$dir")) {
          # Return default values instead
          return $self->_defaultRow();
      }

      my @values;
      $self->{'cacheOptions'} = {};
      my $gconfData = $gconfmod->hash_from_dir("$dir");
      $row->{'readOnly'} = $gconfData->{'readOnly'};
      foreach my $type (@{$self->table()->{'tableDescription'}}) {
          my $data = clone($type);
          $data->restoreFromHash($gconfData);
          $data->setRow($row);
          $data->setModel($self);

          # TODO Rework the union select options thing
          #      this code just sucks. Modify Types to do something
          #      nicer 
          if ($data->type() eq 'union') {
              # FIXME: Check if we can avoid this
              $row->{'plainValueHash'}->{$data->selectedType} =
                $data->value();
              $row->{'printableValueHash'}->{$data->selectedType} =
                $data->printableValue();
          }
          if ($data->type eq 'hasMany') {
              my $fieldName = $data->fieldName();
              $data->setDirectory("$dir/$fieldName");
          }
          if ($data->type eq 'hasMany') {
              my $fieldName = $data->fieldName();
              $data->setDirectory("$dir/$fieldName");
          }

          push (@values, $data);
          $row->{'valueHash'}->{$type->fieldName()} = $data;
          $row->{'plainValueHash'}->{$type->fieldName()} = $data->value();
          $row->{'printableValueHash'}->{$type->fieldName()} =
            $data->printableValue();
      }

      $row->{'values'} = \@values;
      # Dummy id for dataform
      $row->{'id'} = 'dummy';

      return $row;

  }

# Return a row with only default values
sub _defaultRow
  {

      my ($self) = @_;

      my $dir = $self->{'directory'};
      my $row = {};
      my @values = ();

      foreach my $type (@{$self->table()->{'tableDescription'}}) {
          my $data = clone($type);

          if ($data->type() eq 'union') {
            # FIXME: Check if we can avoid this
              $row->{'plainValueHash'}->{$data->selectedType} =
                $data->value();
              $row->{'printableValueHash'}->{$data->selectedType} =
                $data->printableValue();
          }
          if ($data->type eq 'hasMany') {
              my $fieldName = $data->fieldName();
              $data->setDirectory("$dir/$fieldName");
          }
          if ($data->type eq 'hasMany') {
              my $fieldName = $data->fieldName();
              $data->setDirectory("$dir/$fieldName");
          }

          push (@values, $data);
          $row->{'valueHash'}->{$type->fieldName()} = $data;
          $row->{'plainValueHash'}->{$type->fieldName()} = $data->value();
          $row->{'printableValueHash'}->{$type->fieldName()} =
            $data->printableValue();
      }

      $row->{'values'} = \@values;

      return $row;

  }

1;
