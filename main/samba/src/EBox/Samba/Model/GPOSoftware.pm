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

# Class: EBox::Samba::Model::GPOSoftware
#
#
package EBox::Samba::Model::GPOSoftware;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use File::LibMagic;
use TryCatch::Lite;

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Text(fieldName     => 'name',
                              printableName => __('Name'),
                              optional      => 1,
                              hiddenOnSetter => 1),
        new EBox::Types::Text(fieldName     => 'version',
                              printableName => __('Version'),
                              optional      => 1,
                              hiddenOnSetter => 1),
        new EBox::Types::Text(fieldName     => 'state',
                              printableName => __('Deployment State'),
                              optional      => 1,
                              hiddenOnSetter => 1),
        new EBox::Types::Text(fieldName     => 'source',
                              printableName => __('Source MSI package path'),
                              editable      => 1),
    ];

    my $dataTable = {
        tableName           => 'GPOSoftware',
        printableTableName  => __('Software Installation'),
        defaultActions      => ['add', 'del', 'edit', 'changeView'],
        tableDescription    => $tableDesc,
        printableRowName    => __('software package'),
        sortedBy            => 'name',
        withoutActions      => 0,
        modelDomain         => 'Samba',
    };

    return $dataTable;
}

sub addedRowNotify
{
    my ($self, $row) = @_;

    my $file = $row->valueByName('source');
    try {
        my $flm = new File::LibMagic();
        my $description = $flm->describe_filename($file);
        EBox::info(Dumper($description));
#    my $author = $row->elementByName('service');
#    $service->setValue(0);
#    $row->store();
    } catch ($error) {
        EBox::error($error);
    }
}

# Method: precondition
#
#   Check samba is configured and provisioned
#
# Overrides:
#
#   <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $samba = $self->parentModule();
    unless ($samba->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }
    unless ($samba->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
    }
    unless (scalar @{$samba->shares()} >= 1) {
        $self->{preconditionFail} = 'noShares';
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Show the precondition failure message
#
# Overrides:
#
#   <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notConfigured') {
        return __('You must enable the module in the module ' .
                'status section in order to use it.');
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        return __('The domain has not been created yet.');
    }
    if ($self->{preconditionFail} eq 'noShares') {
        return __('No shares');
    }
}

1;
