# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::RemoteServices::Model::AccessSettings
#
# This class is the model to configure the access settings from
# control panel of remote services to eBox:
#
#     - passwordless (Boolean)
#

package EBox::RemoteServices::Model::AccessSettings;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;

# Constants

# Group: Public methods

# Constructor: new
#
#     Create the access settings form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::AccessSettings>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

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
                                fieldName     => 'passwordless',
                                printableName => __('Access from control panel without password'),
                                editable      => 1,
                               ),
      );

    my $dataForm = {
                    tableName          => 'AccessSettings',
                    printableTableName => __('Access settings'),
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                };

      return $dataForm;

  }

# Group: Private methods

1;
