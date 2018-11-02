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

package EBox::EBackup::Model::BackupRestoreConf;

use base 'EBox::Model::DataForm::Action';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::External;

use TryCatch;

# Group: Public methods

# Method: precondition
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my @status;
    my $statusFailure;
    try {
        @status = @{$self->{confmodule}->remoteStatus()};
    } catch (EBox::Exceptions::External $e) {
        $statusFailure = $e->text();
    }

    if ($statusFailure) {
        $self->{preconditionFailMsg} = $statusFailure;
        return 0;
    } elsif (@status == 0) {
        $self->{preconditionFailMsg} = __('There are no backed up files yet');
        return 0;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Overrides:
#
#      <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;
    return $self->{preconditionFailMsg};
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
        tableName          => 'BackupRestoreConf',
        printableTableName => __('Restore Zentyal configuration from backup'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        defaultEnabledValue => 1,
        customFilter       => 1,
        help => __('Loads the configuration found in the backup' ),
        messages => {
                      'update' => __('Please wait...'),
                    },
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

    my $backupFile = $self->_backupFile($date);

    my $url = "/SysInfo/Backup?restoreFromFile=1&backupfile=$backupFile";

    $self->pushRedirection($url)
}

sub _backupFile
{
    my ($self, $date) = @_;
    my $ebackup  = EBox::Global->modInstance('ebackup');
    my $settings = $ebackup->model('BackupSettings');

    my $tmpFile = EBox::Config::tmp() . 'eboxbackup-tmp.tar';

    try {
        my $bakFile  =   EBox::EBackup::extraDataDir()  . '/confbackup.tar';
        $ebackup->restoreFile($bakFile, $date, $tmpFile);
    } catch (EBox::Exceptions::External $e) {
        my $text = $e->stringify();
        if ($text =~ m/not found in backup/) {
            throw EBox::Exceptions::External(__x('Configuration backup not found in backup for {d}. Maybe you could try another date?',
                                                 d => $date));
        }

        $e->throw();
    }

    return $tmpFile;
}

1;
