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

# Core modules
use Error qw(:try);

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

      if ( $self->_hasRow() ) {
          $self->{rowId} = $self->rows()->[0]->{id};
      }

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

      $id = $self->{rowId} unless ( defined ( $id ));

      return $self->SUPER::row($id);

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

      return $self->SUPER::row($self->{rowId});

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
# Overrides:
#
#       <EBox::Model::DataTable::removeRow>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub removeRow
  {

      throw EBox::Exceptions::Internal('It cannot remove a row in an ' .
                                       'one-rowed table');

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
          $self->{rowId} = $self->rows()->[0]->{id};
          $params{id} = $self->{rowId};
          $self->SUPER::setRow($force, %params);
      } else {
          # Add a new one
          $self->SUPER::addRow(%params);
          $self->{rowId} = $self->rows()->[0]->{id};
      }

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

      # The method which takes care of loading the rows
      # from gconf is _rows(). 
      #
      # rows() tries to cache the data to avoid extra access
      # to gconf
      my $gconfmod = $self->{'gconfmodule'};
      my $storedVersion = $self->_storedVersion();
      my $cachedVersion = $self->{'cachedVersion'};

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

      return $self->{'cachedRows'};

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

# Method: find
#
#       Find a row . It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::find>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub find
  {

      throw EBox::Exceptions::Internal('Finding is not needed in an one-rowed table');

  }

# Method: findAll
#
#       Find rows . It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::findAll>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub findAll
  {

      throw EBox::Exceptions::Internal('Finding is not needed in an one-rowed table');

  }

# Method: findValue
#
#       Find a row. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::findValue>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub findValue
  {

      throw EBox::Exceptions::Internal('Finding is not needed in an one-rowed table');

  }

# Method: findAllValue
#
#       Find some rows. It makes no sense in an one-rowed table.
#
# Overrides:
#
#       <EBox::Model::DataTable::findAllValue>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown since it has no sense in
#       an one-rowed table
#
sub findAllValue
  {

      throw EBox::Exceptions::Internal('Finding is not needed in an one-rowed table');

  }

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

# Check if the model is empty
sub _hasRow
  {

      my ($self) = @_;

      my $id = $self->rows()->[0]->{id};

      return defined ( $id );

  }

1;
