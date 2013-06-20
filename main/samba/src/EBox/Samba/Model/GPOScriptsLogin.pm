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

#
# Class: EBox::Samba::Model::GPOScriptsLogin
#
package EBox::Samba::Model::GPOScriptsLogin;

use base 'EBox::Samba::Model::GPOScripts';

use EBox::Gettext;
use EBox::Samba::GPO;
use EBox::Samba::GPO::ScriptsUser;

sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table();
    $dataTable->{tableName}          = 'GPOScriptsLogin',
    $dataTable->{printableTableName} = __('Login Scripts'),
    $dataTable->{printableRowName}   = __('login script'),
    return $dataTable;
}

sub _scriptPath
{
    my ($self, $basename) = @_;

    my $gpoDN = $self->parentRow->id();
    my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
    my $path = $gpo->path();
    return "$path/User/Scripts/Logon/$basename";
}

sub ids
{
    my ($self) = @_;

    my $ids = [];

    my $gpoDN = $self->parentRow->id();
    my $extension = new EBox::Samba::GPO::ScriptsUser(dn => $gpoDN);

    my $data = $extension->read();

    # Cache the data for row function
    $self->{data} = $data;

    # Filter the results, get Batch Logon only
    my $batchScripts = $data->{batch};
    my $batchLogonScripts = $batchScripts->{Logon};
    foreach my $index (sort keys %{$batchLogonScripts}) {
        push (@{$ids}, "batch_$index");
    }

    # Filter the results, get PowerShell Logon only
    my $psScripts = $data->{ps};
    my $psLogonScripts = $psScripts->{Logon};
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
        my $extension = new EBox::Samba::GPO::ScriptsUser(dn => $gpoDN);
        $data = $extension->read();
    }

    my ($type, $index) = split (/_/, $id);

    my $script = $data->{$type}->{Logon}->{$index};
    my $row = $self->_setValueRow(
            type => $type,
            parameters => $script->{Parameters},
            script => $self->_scriptPath($script->{CmdLine}));
    $row->setId($id);

    return $row;
}

# Method: addTypedRow
#
# Overrides:
#
#   <EBox::Model::DataTable::addTypedRow>
#
sub addTypedRow
{
    my ($self, $params_r, %optParams) = @_;

    # Check compulsory fields
    $self->_checkCompulsoryFields($params_r);

    my $type = $params_r->{type}->value();
    my $parameters = $params_r->{parameters}->value();

    # Move the file
    my $scriptElement = $params_r->{script};
    $scriptElement->_moveToPath();

    # Write extension
    my $gpoDN = $self->parentRow->id();
    my $extension = new EBox::Samba::GPO::ScriptsUser(dn => $gpoDN);
    my $data = $self->{data};
    unless (defined $data) {
        my $data = $extension->read();
    }

    my $ids = $self->ids();
    my $index = scalar @{$ids};
    $data->{$type}->{Logon}->{$index} = {
        CmdLine => $scriptElement->userPath(),
        Parameters => $parameters,
    };
    $extension->write($data);

    return "$type\_$index";
}

1;
