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


package EBox::EBackup::Model::Settings;

# Class: EBox::EBackup::Model::Settings
#
#       Form to set the general configuration for the backup server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;

# Group: Public methods

# Constructor: new
#
#       Create the new Settings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::Settings> - the recently created model
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
       new EBox::Types::Text(
                                fieldName     => 'backupPath',
                                printableName => __('Backup destination'),
                                editable      => 1,
                                defaultValue  => EBox::EBackup->DFLTPATH,
                            ),
      );

    my $dataTable =
    {
        tableName          => 'Settings',
        printableTableName => __('General Configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('General backup server configuration'),
        messages           => {
                                  update => __('General backup server configuration updated'),
                              },
        modelDomain        => 'EBackup',
    };

    return $dataTable;

}

1;
