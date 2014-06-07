# Copyright (C) 2012-2013 Zentyal S.L.
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
use strict;
use warnings;

# Class: EBox::Samba::Model::SyncShares
#
#   Configure Shares syncing
#
package EBox::Samba::Model::SyncShares;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;

use TryCatch::Lite;

# Group: Public methods

# Method: updatedRowNotify
#
#      Notify cloud-prof if installed to be restarted
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to notify changes
        return;
    }

    my $global = EBox::Global->getInstance();
    if ( $global->modExists('cloud-prof') ) {
        $global->modChange('cloud-prof');
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
    my ($self) = @_;

    my @tableDesc = (
       new EBox::Types::Boolean(
                               fieldName     => 'sync',
                               printableName => __('Sync all with Zentyal Cloud'),
                               editable      => 1,
                               defaultValue  => 0,
                               help          => __('All shares and user homes will be synchronized using Zentyal Cloud.'),
                               ),
    );

    my $dataTable = {
                     tableName          => 'SyncShares',
                     printableTableName => __('Cloud Sync'),
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     menuNamespace      => 'Samba/View/SyncShares',
                    };

      return $dataTable;
}

sub precondition
{
    my $rs = EBox::Global->modInstance('remoteservices');
    $rs or return 0;
    return $rs->filesSyncAvailable();
}

sub preconditionFailMsg
{
    return __('Zentyal Cloud Files not available')
}

1;
