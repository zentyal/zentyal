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

# Class: EBox::Events::Model::Watcher::DiskFreeSpace
#
# This class is the model to configurate DiskFreeSpace watcher. It has
# a single field in a form:
#
# The field is the following:
#
#    - spaceThreshold - Int the minimum disk free space before
#    notifying the user of lack of space in a disk
#

package EBox::Events::Model::Watcher::DiskFreeSpace;

use base 'EBox::Model::DataForm';

# eBox uses
use EBox::Exceptions::External;
use EBox::Types::Int;

# Core modules

# Group: Public methods

# Constructor: new
#
#     Create the configure the log watchers
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Events::Model::Watcher::Log>
#
sub new
{
      my $class = shift;

      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      return $self;

}

# Method: validateTypedRow
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists ( $changedFields->{spaceThreshold} )) {
      if ( $changedFields->{spaceThreshold} <= 0
	   or $changedFields->{spaceThreshold} >= 100 ) {
	throw EBox::Exceptions::External('The allowed values for the '
					 . 'minimum free disk space must '
					 . 'be in the interval (1, 99)');
      }
    }

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
  {

      my @tableDesc =
        (
         new EBox::Types::Int(
			      fieldName     => 'spaceThreshold',
			      printableName => __('Minimum free disk space per filesystem'),
			      editable      => 1,
			      trailingText  => '%',
			     ),
       );

      my $dataForm = {
                      tableName           => 'DiskFreeWatcherConfiguration',
                      printableTableName  => __('Configure disk free space watcher'),
                      modelDomain         => 'Events',
                      defaultActions      => [ 'editField', 'changeView' ],
                      tableDescription    => \@tableDesc,
                      class               => 'dataForm',
                      help                => __('Take care the minimum percentage of '
						. 'free space is done per file system '
					        . 'and not in overall'),
                     };

      return $dataForm;

  }

1;
