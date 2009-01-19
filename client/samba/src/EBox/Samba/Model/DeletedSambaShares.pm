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

# Class: EBox::Samba::Model::DeletedSambaShares
#
#  This model is used to store the samba shares which are removed by the user.
#  eBox configuration works as follows:
#
#   - User add/remove stuff on the GUI
#   - Once is done he saves changes and the changes take places
#   - We need to actually remove the directories at saving changes time,
#     so we have to write down which directories we must remove
#
package EBox::Samba::Model::DeletedSambaShares;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Sudo;
use EBox::SambaLdapUser;

use Error qw(:try);

use constant EBOX_SHARE_DIR => EBox::SambaLdapUser::basePath() . '/shares/';

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
#     <EBox::Samba::Model::DeletedSambaShares> - the newly created object
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

    for my $row ( @{$self->rows()}) {
        my $path = EBOX_SHARE_DIR;
        $path .= $row->elementByName('path')->value();
        unless ( -d $path ) {
            $self->removeRow($row->id(), 1);
            next;
        }
        try {
            EBox::Sudo::root("rm -rf $path");
        } otherwise {
            EBox::warn("Couldn't remove $path");
        };
        $self->removeRow($row->id(), 1);
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

    my @tableDesc =
      (
       new EBox::Types::Text(
                               fieldName     => 'path',
                               printableName => __('path'),
                               editable      => 1,
                               unique        => 1,
                              ),
 
      );

    my $dataTable = {
                     tableName          => 'DeletedSambaShares',
                     printableTableName => 'Deleted Samba shares',
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
