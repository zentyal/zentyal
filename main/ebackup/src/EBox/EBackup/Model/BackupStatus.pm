# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::EBackup::Model::BackupStatus;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
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

# Method: ids
#
# Overrides:
#
#      <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self) = @_;

    my @status = @{$self->{confmodule}->remoteStatus()};
    return [] unless (@status);

    return [0 .. (scalar(@status) -1)];
}

# Method: row
#
# Overrides:
#
#      <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id) = @_;

    # the reverse is for antichronological order
    my @status = reverse @{$self->{confmodule}->remoteStatus()};
    my $type = $status[$id]->{'type'};
    my $date = $status[$id]->{'date'};

    my $row = $self->_setValueRow(type => $type,
                                  date => $date,
                                 );
    $row->setId($id);
    return $row;
}

# Method: precondition
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    if ($self->{confmodule}->updateStatusInBackgroundRunning()) {
        $self->{preconditionFailMsg} =  __('Remote Backup Status : Update process running, retry later');
        return 0;
    }

    if (not $self->{confmodule}->configurationIsComplete()) {
        $self->{preconditionFailMsg} =  __('Remote Backup Status : There are not backed up files yet');
        return 0;
    }

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
    }

    if (not scalar @status) {
        $self->{preconditionFailMsg} =  __('Remote Backup Status : There are not backed up files yet');
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
        new EBox::Types::Text(
            fieldName     => 'type',
            printableName => __('Type'),
        ),
        new EBox::Types::Text(
            fieldName     => 'date',
            printableName => __('Date'),
        ),

    );

    my $dataTable =
    {
        tableName          => 'RemoteStatus',
        printableTableName => __('Remote Backup Status'),
        printableRowName   => __('backup'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        defaultEnabledValue => 1,
        withoutActions     => 1,
    };

    return $dataTable;

}

1;
