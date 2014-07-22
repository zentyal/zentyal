# Copyright (C) 2013-2014 Zentyal S.L.
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
use EBox::Samba::GPOIdMapper;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table();
    $dataTable->{tableName}          = 'GPOScriptsLogin';
    $dataTable->{printableTableName} = __('Logon Scripts');
    $dataTable->{printableRowName}   = __('logon script');
    return $dataTable;
}

sub _scriptPath
{
    my ($self, $basename) = @_;

    my $gpoId = $self->parentRow()->id();
    my $gpoDN = EBox::Samba::GPOIdMapper::idToDn($gpoId);
    my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
    my $path = $gpo->path();
    return "$path/User/Scripts/Logon/$basename";
}

sub _scriptHost
{
    my ($self) = @_;
    my $host = $self->parentModule->ldap()->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal('Could not get DNS hostname');
    }
    return $host;
}

sub _scriptService
{
    my ($self) = @_;
    return 'sysvol';
}

sub ids
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    unless (defined $parentRow) {
        return [];
    }

    my @ids;

    my $gpoId = $parentRow->id();
    my $gpoDN = EBox::Samba::GPOIdMapper::idToDn($gpoId);
    my $extension = new EBox::Samba::GPO::ScriptsUser(dn => $gpoDN);

    my $data = $extension->read();

    # Cache the data for row function
    $self->{data} = $data;

    # Filter the results, get Batch Logon only
    my $batchScripts = $data->{batch};
    my $batchLogonScripts = $batchScripts->{Logon};
    foreach my $index (sort keys %{$batchLogonScripts}) {
        push (@ids, "batch_$index");
    }

    # Filter the results, get PowerShell Logon only
    my $psScripts = $data->{ps};
    my $psLogonScripts = $psScripts->{Logon};
    foreach my $index (sort keys %{$psLogonScripts}) {
        push (@ids, "ps_$index");
    }

    return \@ids;
}

sub row
{
    my ($self, $id) = @_;

    # Try to retrieve cached data
    my $data = $self->{data};
    unless (defined $data) {
        my $parentRow = $self->parentRow();
        if (not $parentRow) {
            return undef;
        }
        my $gpoId = $parentRow->id();
        my $gpoDN = EBox::Samba::GPOIdMapper::idToDn($gpoId);
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
    my $gpoId = $self->parentRow()->id();
    my $gpoDN = EBox::Samba::GPOIdMapper::idToDn($gpoId);
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

    $self->setMessage(__x('Logon script {x} added',
        x => $scriptElement->userPath()));

    return "$type\_$index";
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined $id) {
        throw EBox::Exceptions::MissingArgument(
            "Missing row identifier to remove");
    }

    my $row = $self->row($id);
    unless (defined $row) {
        throw EBox::Exceptions::Internal(
            "Row with id $id does not exist, so it cannot be removed");
    }
    my $e = $row->elementByName('script');
    my $name = $e->userPath();

    my $gpoId = $self->parentRow()->id();
    my $gpoDN = EBox::Samba::GPOIdMapper::idToDn($gpoId);
    my $extension = new EBox::Samba::GPO::ScriptsUser(dn => $gpoDN);
    my $data = $self->{data};
    unless (defined $data) {
        my $data = $extension->read();
    }

    my ($type, $index) = split (/_/, $id);
    delete $data->{$type}->{Logon}->{$index};
    foreach my $i (sort keys %{$data->{$type}->{Logon}}) {
        my $newIdx = $i - 1;
        if ($i > $index) {
            $data->{$type}->{Logon}->{$newIdx} = $data->{$type}->{Logon}->{$i};
            delete $data->{$type}->{Logon}->{$i};
        }
    }
    $extension->write($data);

    $self->setMessage(__x('Logon script {x} removed', x => $name));
}

1;
