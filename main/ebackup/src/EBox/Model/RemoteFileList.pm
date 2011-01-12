# Copyright (C) 2009-2010 eBox Technologies S.L.
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


package EBox::EBackup::Model::RemoteFileList;

# Class: EBox::EBackup::Model::RemoteFileList
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
use EBox::View::Customizer;
use EBox::Exceptions::DataInUse;

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

# Method: ids
#
# Overrides:
#
#      <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self) = @_;

    my @status = @{$self->{gconfmodule}->remoteListFiles()};
    return [] unless (@status);
    return [1 .. (scalar(@status))];
}

# Method: customFilterIds
#
# Overrides:
#
#      <EBox::Model::DataTable::customFilterIds>
#
sub customFilterIds
{
    my ($self, $filter) = @_;

    unless (defined($filter)) {
        return $self->ids();
    }

    my @status = @{$self->{gconfmodule}->remoteListFiles()};
    return [] unless (@status);
    my @filtered;
    for my $id (1 .. (scalar(@status))) {
        push (@filtered, $id) if ($status[$id - 1] =~ /$filter/);
    }

    return \@filtered;
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

    my @status = @{$self->{gconfmodule}->remoteListFiles()};

    my $row = $self->_setValueRow(file => $status[$id - 1]);
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

    return __('There are not backed up files yet');
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
            fieldName     => 'file',
            printableName => __('File'),
        ),
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
        tableName          => 'RemoteFileList',
        printableTableName => __('Restore Files'),
        printableRowName   => __('file restore operation'),
        printableActionName   => __('Restore'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        defaultEnabledValue => 1,
        customFilter       => 1,
    };

    return $dataTable;

}

sub _checkRowExist
{
    return 1;
}

sub validateTypedRowBak
{
    my ($self, $action, $fields) = @_;


    my $file = $fields->{file}->value();
    if (EBox::Sudo::fileTest('-e', $file)) {
        throw EBox::Exceptions::DataInUse(
                __('File already exists if you continue the current'.
                   ' will be deleted'
                  )
                );
    }
}

sub setTypedRow
{
    my ($self, $id, $fields, $force) = @_;


    my $file = $fields->{file}->value();
    my $date = $fields->{date}->value();
    my $ebackup = EBox::Global->modInstance('ebackup');
    $ebackup->restoreFile($file, $date);
    $self->setMessage(__('File restored successfully'));
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


# Method: headTitle
#
# Overrides:
#
#       <EBox::Model::Composite::headTitle>
#
sub headTitle
{
    return undef;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to show and hide source and destination ports
#   depending on the protocol
#
#
sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    if ($self->precondition()) {
        my $ebackup = EBox::Global->modInstance('ebackup');
        my $url = $ebackup->_remoteUrl();
        $customizer->setPermanentMessage(
         __x('Remote URL to be used with duplicity for manual restores: {url}',
             url => $url)
        );
    }
    return $customizer;
}
1;
