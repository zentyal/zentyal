# Copyright (C) 2010 EBox Technologies S.L.
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

package EBox::EBackup::Model::BackupDomains;
use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use  EBox::EBackup::Subscribed;

# Method: syncRows
#
#  Needed to show all bakcup domains provided by the modules
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $ebackup  = $self->{'gconfmodule'};
    # If the GConf module is readonly, return current rows
    if ( $ebackup->isReadOnly() ) {
        return undef;
    }


    my %domains = %{ $ebackup->selectableBackupDomains() };
    my $modified;
    # Remove old no-existent rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $name = $row->valueByName('name');
        if (not exists $domains{$name} or ($name =~ /deleted/)) {
            $self->removeRow($id);
            $modified = 1;
        } else {

            if ( ($domains{$name}->{printableName} ne $row->valueByName('description'))
                 or (not $row->elementExists('full_description'))
                 or ($domains{$name}->{description} ne $row->valueByName('full_description')) ) {
                # update descriptions if needed, for example for language changes
                $row->elementByName('description')->setValue(
                          $domains{$name}->{printableName}
                                                            );
                $row->elementByName('full_description')->setValue(
                    $domains{$name}->{description});

                $row->store();
                $modified = 1;
            }

            delete $domains{$name};
        }
    }

    # add new rows
    while (my ($name, $attr) = each %domains) {
        $self->add(
            name             => $name,
            description      => $attr->{printableName},
            full_description => $attr->{description},
            enabled          => 0
           );
        $modified = 1;
    }

    my $modIsChanged =  EBox::Global->getInstance()->modIsChanged($ebackup->name());
    if ($modified and not $modIsChanged) {
        $ebackup->_saveConfig();
        EBox::Global->getInstance()->modRestarted($ebackup->name());
    }

    return $modified;
}


sub enabled
{
    my ($self) = @_;
    my %enabled = ();

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        if ($row->valueByName('enabled')) {
            $enabled{$row->valueByName('name')} = 1;
        }
    }

    return \%enabled;
}


sub report
{
    my ($self) = @_;
    my @enabled;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        if ($row->valueByName('enabled')) {
            push @enabled, $row->valueByName('description');
        }
    }

    return { backupDomains => \@enabled};
}

sub precondition
{
    return EBox::EBackup::Subscribed::isSubscribed();
}

sub preconditionFailMsg
{
    # No precondition message since they do not give any valuable information
    return '';
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
        new EBox::Types::Text(
            'fieldName'     => 'full_description',
            'printableName' => __('Description'),
            'unique'        => 1,
            'editable'      => 0,
           ),
        new EBox::Types::Boolean (
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'defaultValue' => 0,
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'BackupDomains',
        printableTableName => __('Domains to back up'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'ebackup',
        printableRowName   => __('Backup domain'),
        help               => __('Select the domains you want to back up.'),
    };
    return $dataTable;
}

1;
