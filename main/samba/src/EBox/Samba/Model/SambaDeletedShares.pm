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

# Class: EBox::Samba::Model::SambaDeletedShares
#
#  This model is used to store the samba shares which are removed by the user.
#  Zentyal configuration works as follows:
#
#   - User add/remove stuff on the GUI
#   - Once is done he saves changes and the changes take places
#   - We need to actually remove the directories at saving changes time,
#     so we have to write down which directories we must remove
#
use strict;
use warnings;

package EBox::Samba::Model::SambaDeletedShares;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Sudo;

use TryCatch;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the new deleted Samba shares table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::SambaDeletedShares> - the newly created object
#     instance
#
sub new
{
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    bless ( $self, $class);

    return $self;
}

# Method: removeDirs
#
#   This method is used to remove the share directories. It must be used
#   in saving changes time.
#
sub removeDirs
{
    my ($self) = @_;

    for my $id ( @{$self->ids()}) {
        my $row = $self->row($id);
        my $path = EBox::Samba::SHARES_DIR() . '/' . $row->elementByName('path')->value();
        unless (EBox::Sudo::fileTest('-d', $path)) {
            $self->removeRow($row->id(), 1);
            next;
        }
        try {
            EBox::Sudo::root("rm -rf $path");
        } catch {
            EBox::warn("Couldn't remove $path");
        }
        $self->removeRow($id, 1);
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
        new EBox::Types::Text(
                              fieldName     => 'path',
                              printableName => __('path'),
                              editable      => 1,
                              unique        => 1,
                             ),
    );

    my $dataTable = {
                     tableName          => 'SambaDeletedShares',
                     printableTableName => 'Deleted shares',
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del',
                                             'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     help               => '',
                     printableRowName   => __('share'),
    };

    return $dataTable;
}

1;
