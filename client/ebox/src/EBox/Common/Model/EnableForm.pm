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

# Class: EBox::Common::EnableForm
#
# This class is a common model which stores a single boolean which
# indicates if something is enabled or not. The data stored is just a
# single boolean attribute
#
#     - enabled
#

package EBox::Common::Model::EnableForm;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#      Create an enabled form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
# Parameters:
#
#      enableTitle - String the i18ned title for the printable name
#      for the enabled attribute
#
#      modelDomain - String the model domain which this form belongs to
#
#      - Named parameters
#
# Returns:
#
#      <EBox::Common::Model::EnableForm> - the recently created model
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub new
  {

      my ($class, %params) = @_;

      my $enableTitle = delete $params{enableTitle};
      defined ( $enableTitle ) or
        throw EBox::Exceptions::MissingArgument('enableTitle');

      my $modelDomain = delete $params{modelDomain};
      defined ( $modelDomain ) or
        throw EBox::Exceptions::MissingArgument('modelDomain');

      my $self = $class->SUPER::new(%params);
      bless( $self, $class );

      $self->{enableTitle} = $enableTitle;
      $self->{modelDomain} = $modelDomain;

      return $self;

  }

# Method: formSubmitted
#
# Overrides:
#
#     <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

      if ( $self->enabledValue() ) {
          $self->setMessage(__('Service enabled'));
      } else {
          $self->setMessage(__('Service disabled'));
      }

  }

# Group: Class methods

# Method: Viewer
#
# Overrides:
#
#     <EBox::Model::DataForm::Viewer>
#
sub Viewer
  {

      return '/common/enable.mas';

  }

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
  {

      my ($self) = @_;

      my @tableDesc =
        (
         new EBox::Types::Boolean(
                                  fieldName     => 'enabled',
                                  printableName => $self->{enableTitle},
                                  editable      => 1,
                                 ),
        );

      my $dataForm = {
                      tableName          => 'EnableForm',
                      printableTableName => __('Enable service'),
                      modelDomain        => $self->{modelDomain},
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                     };

      return $dataForm;

  }

1;
