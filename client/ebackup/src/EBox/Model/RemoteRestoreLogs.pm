# Copyright (C) 2010 eBox Technologies S.L.
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


package EBox::EBackup::Model::RemoteRestoreLogs;

# Class: EBox::EBackup::Model::RemoteRestoreLogs
#
#
#

use base 'EBox::Model::DataForm::Action';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Exceptions::DataInUse;
use EBox::EBackup::DBRestore;

use Error qw(:try);

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
#      in RemoteRestoreConf to avoid showing it twice
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my @status = @{$self->{gconfmodule}->remoteStatus()};
    return (scalar(@status));
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
        tableName          => 'RemoteRestoreLogs',
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
