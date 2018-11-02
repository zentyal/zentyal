# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::EBackup::Model::BackupRestoreLogs;

use base 'EBox::Model::DataForm::Action';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Exceptions::DataInUse;
use EBox::EBackup::DBRestore;

use TryCatch;

# Group: Public methods

# Constructor: new
#
#       Create the new Hosts model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::Hosts> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: precondition
#
#      The preconditionFailMsg method is only implemented
#      in BackupRestoreConf to avoid showing it twice
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;
    $self->{_precondition_msg} = undef;

    my @status;
    try {
        @status = @{$self->{confmodule}->remoteStatus()};
    } catch (EBox::Exceptions::External $e) {
        # ignore error, it will be shown in the same composite by the model
        # BackupRestoreConf
    }
    return 0 if not @status;
    my $logs = $self->global()->modInstance('logs');
    if (not $logs) {
        $self->{_precondition_msg} = __('To be able to restore logs you need the logs module installed and enabled');
        return 0;
    }
    if (not $logs->configured()) {
        $self->{_precondition_msg} = __('To be able to restore logs you need the logs module enabled');
        return 0;

    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;
    my $msg = $self->{_precondition_msg};
    defined $msg or
        $msg = '';
    return $msg;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader = (
        new EBox::Types::Select(
            fieldName     => 'date',
            printableName => __('Backup Date'),
            populate      => \&_backupVersion,
            editable      => 1,
            disableCache  => 1,
       )

    );

    my $dataTable =
    {
        tableName          => 'BackupRestoreLogs',
        printableTableName => __('Restore logs database'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        defaultEnabledValue => 1,
        customFilter       => 1,
        help => __('Restores the Zentyal logs found in the selected backup'),
    };

    return $dataTable;
}

sub _backupVersion
{
    my $ebackup = EBox::Global->modInstance('ebackup');
    my @status = @{$ebackup->remoteStatus()};
    return [] unless (@status);
    my @versions;
    for my $id (@status) {
        push (@versions, {
                value => $id->{'date'},
                printableValue => $id->{'date'}
        });
    }

    # reverse for antichrnological order
    @versions = reverse  @versions;
    return \@versions;
}

sub formSubmitted
{
    my ($self, $row) = @_;
    my $date = $row->valueByName('date');
    EBox::EBackup::DBRestore::restoreEBoxLogs($date);

}

1;
