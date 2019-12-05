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

# Class: EBox::Samba::Model::ExportUsers
#
#   This model is used to manage the system status report feature
#
package EBox::Samba::Model::ExportGroups;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Global;
use EBox::Samba::Types::DownloadGroups;

use EBox::Gettext;
use EBox::Types::Text;

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
        new EBox::Samba::Types::DownloadUsers(
           fieldName => 'downloadExportedGroups',
           printableName => __('Export groups'),
        ),
    );

    my $dataTable =
    {
        tableName          => 'ExportGroups',
        modelDomain        => 'Samba',
        printableTableName => __('Export domain groups'),
        tableDescription   => \@tableHeader,
        defaultEnabledValue => 1,
    };

    return $dataTable;
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

    return $self->parentModule()->isEnabled();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    return __('You must enable the Users and Groups module to access the LDAP information.');
}

1;