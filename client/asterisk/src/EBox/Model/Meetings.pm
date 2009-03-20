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

package EBox::Asterisk::Model::Meetings;

# Class: EBox::Asterisk::Model::Provider
#
#   Form to set the configuration settings for the SIP provider
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;

# Group: Public methods

# Constructor: new
#
#       Create the new Provider model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Provider> - the recently created model
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
       new EBox::Types::Int(
                                fieldName     => 'exten',
                                printableName => __('Extension'),
                                size          => 3,
                                unique        => 1,
                                editable      => 1,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'alias',
                                printableName => __('Alias'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Password(
                                fieldName     => 'pin',
                                printableName => __('Password'),
                                size          => 6,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Password(
                                fieldName     => 'adminpin',
                                printableName => __('Administrator Password'),
                                size          => 6,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'desc',
                                printableName => __('Description'),
                                size          => 12,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
      );

    my $dataTable =
      {
       tableName          => 'Meetings',
       printableTableName => __('Meetings'),
       'printableRowName' => __('meeting'),
       defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataTable',
       sortedBy           => 'exten',
       help               => __('SIP provider configuration.'),
       messages           => {
                              update => __('SIP provider configuration settings updated'),
                             },
       modelDomain        => 'Asterisk',
      };

    return $dataTable;

}

1;
