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

# Class: EBox::Asterisk::Model::Meetings
#
#   Form to set the configuration settings for the meetings
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Asterisk::Extensions;

# Group: Public methods

# Constructor: new
#
#       Create the new Meetings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Meetings> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Method: validateTypedRow
#
#      Check the row to add or update if the name contains a valid
#      extension
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the extension is not
#      valid
#
sub validateTypedRow
{
  my ($self, $action, $changedFields) = @_;

  if ( exists $changedFields->{exten} ) {
      EBox::Asterisk::Extensions->checkExtension(
                                      $changedFields->{exten}->value(),
                                      __(q{extension}),
                                      EBox::Asterisk::Extensions->MEETINGMINEXTN,
                                      EBox::Asterisk::Extensions->MEETINGMAXEXTN,
                                      );
  }

}


# Method: addedRowNotify
#
#      Check the row to add or update if the name contains a valid
#      extension
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $row) = @_;


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
                                size          => 4,
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
                                size          => 8,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Password(
                                fieldName     => 'adminpin',
                                printableName => __('Administrator password'),
                                size          => 8,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'desc',
                                printableName => __('Description'),
                                size          => 24,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
      );

    my $dataTable =
      {
       tableName          => 'Meetings',
       printableTableName => __('Meetings'),
       printableRowName   => __('meeting'),
       defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataTable',
       sortedBy           => 'exten',
       modelDomain        => 'Asterisk',
      };

    return $dataTable;

}

1;
