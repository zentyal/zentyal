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

package EBox::EBackup::Model::BackupStorage;

use base 'EBox::Model::DataForm::ReadOnly';

# Class: EBox::EBackup::Model::BackupStorage
#
#   TODO: Document the class
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Exceptions::Command;
use EBox::Exceptions::NotConnected;
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

sub _content
{
    my ($self) = @_;

    unless (defined $self->{storage}) {
        $self->{storage} = $self->_getStorageUsage();
    }

    if ($self->{badConnection}) {
        $self->setMessage($self->_badConnectionMsg() );
    }

    unless (defined $self->{storage}) {
        # unable to retrieve storage for whatever reason..
        return {
                used => __('Unknown'),
                available => __('Unknown'),
                total     => __('Unknown'),
               };
    }

    return {
            used => $self->{storage}->{used} . ' MB',
            available => $self->{storage}->{available} . ' MB',
            total => $self->{storage}->{total} . ' MB',
           };
}

sub _getStorageUsage
{
    my ($self) = @_;
    my $ebackup = $self->{confmodule};
    delete $self->{storage};
    my $badConnection;

    try {
        $self->{storage} = $ebackup->storageUsage();
    } catch (EBox::Exceptions::Command $e) {
        my $error = $e->error();
        foreach my $line (@{ $error }) {
            if ($line =~ m/Connection timed out/ or
                ($line =~  m/Connection closed by remote host/ )) {
                $badConnection = 'backupServer';
                last;
            }
        }

        if (not $badConnection) {
            $e->throw();
        }
    }

    $self->{badConnection} = $badConnection;

    return $self->{storage};
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

    $self->{storage} = $self->_getStorageUsage();
    return defined $self->{storage}
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

    if ($self->{badConnection}) {
        return _badConnectionMsg();
    }

    # nothing to show if not precondition..
    return '';
}

sub _badConnectionMsg
{
    return __('Error connecting to backup server. Storage status unknown');
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
            fieldName     => 'used',
            printableName => __('Used storage'),
        ),
        new EBox::Types::Text(
            fieldName     => 'available',
            printableName => __('Available storage'),
        ),
        new EBox::Types::Text(
           fieldName     => 'total',
            printableName => __('Total storage'),
        ),
    );

    my $dataTable =
    {
        tableName          => 'BackupStorage',
        printableTableName => __('Remote Storage Usage'),
        printableRowName   => __('backup'),
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
    };

    return $dataTable;
}

1;
