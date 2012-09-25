# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::Samba::Model::SyncShares
#
#   Configure Shares syncing
#
package EBox::Samba::Model::SyncShares;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;

use Error qw(:try);

sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}


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
                               help          => __('All shares and user homes will be syncrhonized using Zentyal Cloud.'),
                               hidden        => \&_syncNotAvailable,
                               ),
      );

    my $dataTable = {
                     tableName          => 'SyncShares',
                     printableTableName => __('Zentyal Cloud Sync'),
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     menuNamespace      => 'Samba/View/SyncShares',
                    };

      return $dataTable;
}


sub _syncAvailable
{
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        return $rs->filesSyncAvailable();
    }

    return 0;
}

sub _syncNotAvailable
{
    return not _syncAvailable()
}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
#
sub headTitle
{
    return undef;
}

1;
