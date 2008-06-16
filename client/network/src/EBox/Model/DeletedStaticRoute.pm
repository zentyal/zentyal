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

# Class: EBox::Network::Model::DeletedStaticRoute
#
#  This model is used to store those static routes that have been
#  deleted by user. So those static routes that we may add from eBox
#  UI will be deleted without intrusing those ones which the user had
#  added before.
#

package EBox::Network::Model::DeletedStaticRoute;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::IPAddr;
use EBox::Types::HostIP;

use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Create the new deleted static route table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Network::Model::DeletedStaticRoute> - the newly created object
#     instance
#
sub new
{
      my ($class, %opts) = @_;
      my $self = $class->SUPER::new(%opts);
      bless ( $self, $class);

      return $self;
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
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::IPAddr(
                               fieldName     => 'network',
                               printableName => 'Network',
                               editable      => 1,
                              ),
       new EBox::Types::HostIP(
                               fieldName     => 'gateway',
                               printableName => 'Gateway',
                               editable      => 1,
                              ),
       new EBox::Types::Boolean(
                               fieldName     => 'deleted',
                               printableName => 'Deleted',
                               editable      => 1,
                              ),
      );

    my $dataTable = {
                     tableName          => 'DeletedStaticRoute',
                     printableTableName => 'Deleted static routes',
                     modelDomain        => 'Network',
                     defaultActions     => [ 'add', 'del', 'editField' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     printableRowName   => 'deleted static route',
                    };

      return $dataTable;
}

1;
