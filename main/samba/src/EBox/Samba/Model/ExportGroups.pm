# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EEBox::Samba::Model::ExportGroups
#
#   This model is used to manage the system status report feature
#
package EBox::Samba::Model::ExportGroups;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Link;
use EBox::Samba::Types::RunExportGroups;
use EBox::Samba::Types::StatusExportGroups;
use EBox::Samba::Types::DownloadExportGroups;

# Constructor: new
#
#       Create the new ExportGroups model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Samba::Model::ExportGroups> - the recently created model
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Samba::Types::RunExportGroups(
            fieldName       => 'exportGroups',
            printableName   => __('Export groups'),
        ),
        new EBox::Samba::Types::StatusExportGroups(
           fieldName => 'status',
           printableName => __('CSV available'),
        ),
        new EBox::Samba::Types::DownloadExportGroups(
            fieldName       => 'downloadExportedGroups',
            printableName   => __('Download csv'),
        ),
    );
    my $dataTable =
    {
        tableName          => 'ManageExportGroups',
        modelDomain        => 'Samba',
        printableTableName => __('Export domain groups'),
        tableDescription   => \@tableHeader,
        defaultActions     => [ 'changeView' ],
    };

    return $dataTable;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    if (@{$currentRows}) {
        return 0;
    } else {
        $self->add(status => 'noreport');
        return 1;
    }
}

# Method: precondition
#
#   Check if usersandgroups is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    # Return false if this is a community edition
    if ($ed) {
        return 0;
    }

    if (! $dep) {
        return 0;
    }

    return 1;
}

1;