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

package EBox::Asterisk::Model::GeneralSettings;

# Class: EBox::Asterisk::Model::GeneralSettings
#
#   Form to set the general configuration settings for the Asterisk server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#       Create the new GeneralSettings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::GeneralSettings> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader =
      (
       new EBox::Types::Boolean(
                                fieldName     => 'incomingCalls',
                                printableName => __('Enable incoming calls'),
                                editable      => 1,
                                defaultValue  => 1,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'outgoingCalls',
                                printableName => __('Enable outgoing calls'),
                                editable      => 1,
                                defaultValue  => 1,
                               ),
      );

    my $dataTable =
      {
       tableName          => 'GeneralSettings',
       printableTableName => __('General configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       help               => __('General Asterisk server configuration.'),
       messages           => {
                              update => __('General Asterisk server configuration settings updated'),
                             },
       modelDomain        => 'Asterisk',
      };

    return $dataTable;

}

1;
