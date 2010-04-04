# Copyright (C) 2009 eBox Technologies S.L.
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


package EBox::EBackup::Model::RemoteStatus;

# Class: EBox::EBackup::Model::RemoteStatus
#
#
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;

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

    my @status = @{$self->{gconfmodule}->remoteStatus()};
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
    my @status = reverse @{$self->{gconfmodule}->remoteStatus()};
    my $type = $status[$id]->{'type'};
    my $date = $status[$id]->{'date'};

    my $row = $self->_setValueRow(type => $type, date => $date);
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

    my @status = @{$self->{gconfmodule}->remoteStatus()};
    return (scalar(@status));
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

    return __('There are not backuped files yet');
}


#
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
    };

    return $dataTable;

}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}
1;
