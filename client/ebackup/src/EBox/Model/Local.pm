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


package EBox::EBackup::Model::Local;

# Class: EBox::EBackup::Model::Local
#
#       Form to set the configuration for the local backup
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::EBackup;

# Group: Public methods

# Constructor: new
#
#       Create the new Local model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::Local> - the recently created model
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
#       Check the row to add or update if contains an existing local backup path
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - thrown if the path is not valid
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists $allFields->{backupPath} ) {
        unless (-d $allFields->{backupPath}->value()) {
            throw EBox::Exceptions::InvalidData(__('Local backup directory {p} does not exist',
                                                   'p' => $allFields->{backupPath}->value()));
        }
    }
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
       new EBox::Types::Boolean(
                                fieldName     => 'backupEnable',
                                printableName => __('Enable local backup'),
                                editable      => 1,
                            ),
       new EBox::Types::Text(
                                fieldName     => 'backupPath',
                                printableName => __('Backup destination'),
                                editable      => 1,
                                defaultValue  => EBox::EBackup->DFLTPATH,
                            ),
       new EBox::Types::Int(
                                fieldName     => 'backupKeep',
                                printableName => __('Days to keep'),
                                editable      => 1,
                                defaultValue  => EBox::EBackup->DFLTKEEP,
                            ),
      );

    my $dataTable =
    {
        tableName          => 'Local',
        printableTableName => __('Local Backup Configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Local backup configuration.'),
        messages           => {
                                  update => __('Local backup configuration updated.'),
                              },
        modelDomain        => 'EBackup',
    };

    return $dataTable;

}

# Method: _backupStatus
sub _backupStatus
{
    my ($self) = @_;

    my $path = EBox::EBackup->DFLTPATH . "/" . EBox::EBackup->DFLTDIR;

    unless (-d $path) {
        throw EBox::Exceptions::External(__('Local backup directory {p} does not exist', 'p' => $path));
    }

    return `rdiff-backup -l $path`;
}

1;
