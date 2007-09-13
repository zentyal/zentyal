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

package EBox::ModuleName::Model::Model;

# Class: EBox::ModuleName::Model::Model
#
#   Class description
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::ModuleName::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;

}

# Group: Protected methods

# Method: _table
#
#       Model description
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
  {

      my @tableHeader = ();

      my $dataTable =
        {
         tableName          => 'tableName',
         printableTableName => __('table title'),
         defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
         tableDescription   => \@tableHeader,
         class              => 'dataTable',
         printableRowName   => __('row'),
         help               => __('help message'),
        };

      return $dataTable;

  }


1;
