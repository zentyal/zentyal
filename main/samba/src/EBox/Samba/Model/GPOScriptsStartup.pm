# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::GPOScriptsStartup
#
#
package EBox::Samba::Model::GPOScriptsStartup;

use base 'EBox::Samba::Model::GPOScripts';

use EBox::Gettext;
use EBox::Samba::GPO::ScriptsComputer;

sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table();
    $dataTable->{tableName}          = 'GPOScriptsStartup',
    $dataTable->{printableTableName} = __('Startup Scripts'),
    $dataTable->{printableRowName}   = __('startup script'),
    return $dataTable;
}

sub ids
{
    my ($self) = @_;

    my $ids = [];

    my $gpoDN = $self->parentRow->id();
    my $extension = new EBox::Samba::GPO::ScriptsComputer(dn => $gpoDN);

    my $data = $extension->read();

    # Cache the data for row function
    $self->{data} = $data;

    # Filter the results, get Batch Logon only
    my $batchScripts = $data->{batch};
    my $batchLogonScripts = $batchScripts->{Startup};
    foreach my $index (sort keys %{$batchLogonScripts}) {
        push (@{$ids}, "batch_$index");
    }

    # Filter the results, get PowerShell Logon only
    my $psScripts = $data->{ps};
    my $psLogonScripts = $psScripts->{Startup};
    foreach my $index (sort keys %{$psLogonScripts}) {
        push (@{$ids}, "ps_$index");
    }

    return $ids;
}

sub row
{
    my ($self, $id) = @_;

    # Try to retrieve cached data
    my $data = $self->{data};
    unless (defined $data) {
        my $gpoDN = $self->parentRow->id();
        my $extension = new EBox::Samba::GPO::UserScripts(dn => $gpoDN);
        $data = $extension->read();
    }

    my ($type, $index) = split (/_/, $id);

    my $script = $data->{$type}->{Startup}->{$index};
    my $row = $self->_setValueRow(
            type => $type,
            name => $script->{CmdLine},
            parameters => $script->{Parameters},
        );
    $row->setId($id);

    return $row;
}

1;
