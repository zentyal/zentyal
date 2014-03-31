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

package EBox::RemoteServices::Model::DisasterRecoveryDomains;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;

sub syncRows
{
    my ($self, $currentRows) = @_;

    my %domains = %{$self->_currentDomains()};

    my $modified;

    # Remove old non-existent rows or update description
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $name = $row->valueByName('name');
        if (not exists $domains{$name}) {
            $self->removeRow($id);
            $modified = 1;
        } else {
            if ($domains{$name} ne $row->valueByName('description')) {
                $row->elementByName('description')->setValue($domains{$name});
                $row->store();
                $modified = 1;
            }
            delete $domains{$name};
        }
    }

    # add new rows
    while (my ($name, $desc) = each %domains) {
        $self->add(name => $name, description => $desc);
        $modified = 1;
    }

    return $modified;
}

# Method: moduleEnabled
#
#      Get if the requested module is enabled
#
# Returns:
#
#      boolean - true if enabled, false otherwise
#
sub moduleEnabled
{
    my ($self, $module) = @_;

    my @enabled;
    foreach my $id (@{ $self->enabledRows() }) {
        my $row = $self->row($id);
        if ($row->valueByName('name') eq $module) {
            return 1;
        }
    }

    return 0;
}

# Method: updatedRowNotify
#
#      Notify cloud-prof if installed to be restarted
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to notify changes
        return;
    }

    my $global = EBox::Global->getInstance();
    if ( $global->modExists('cloud-prof') ) {
        $global->modChange('cloud-prof');
    }
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
            'fieldName' => 'name',
            'unique' => 1,
            'editable' => 0,
            'hidden' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Name'),
            'unique' => 1,
            'editable' => 0,
        ),
    );

    my $dataTable =
    {
        tableName           => 'DisasterRecoveryDomains',
        pageTitle           => __('Disaster Recovery'),
        printableTableName  => __('Data to back up'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableHeader,
        class               => 'dataTable',
        modelDomain         => 'RemoteServices',
        enableProperty      => 1,
        defaultEnabledValue => 0,
        automaticRemove     => 1,  # WTF! to notify other modules
        printableRowName   => __('data domain'),
        help               => __('Select the data you want to back up.'),
    };
    return $dataTable;
}

sub _currentDomains
{
    my ($self) = @_;

    my %backupDomains = ();

    my $global = EBox::Global->getInstance();

    foreach my $mod (@{$global->modInstancesOfType('EBox::SyncFolders::Provider')}) {
        my $domain = $mod->recoveryDomainName();
        if ($domain) {
            my $name = $mod->{name};
            $backupDomains{$name} = $domain;
        }
    }

    return \%backupDomains;
}

1;
