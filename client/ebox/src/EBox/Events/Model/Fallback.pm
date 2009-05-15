# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::Events::Model::Fallback;

# Class: EBox::Events::Model::Fallback
#
#   This model is intended to substitute any submodel from an event
#   watcher or dispatcher row because of its removal
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
#       <EBox::Events::Model::Fallback> - the recently
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

    my $dataTable =
    {
        tableName          => 'Fallback',
        defaultActions     => [ 'changeView' ],
        tableDescription   => [],
        class              => 'dataTable',
        modelDomain        => 'Events',
    };
    return $dataTable;
}

1;
