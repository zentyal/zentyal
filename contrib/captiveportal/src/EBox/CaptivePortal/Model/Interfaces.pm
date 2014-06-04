# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortal::Model::Interfaces;

use base 'EBox::Model::DataTable';

# Class: EBox::CaptivePortal::Model::Interfaces
#
#   Interfaces where a Captive Portal is enabled
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;

# Group: Public methods

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
        new EBox::Types::Text(
            'fieldName' => 'interface',
            'printableName' => __('Interface'),
            'editable' => 0,
        ),
    );

    my $dataTable =
    {
        tableName          => 'Interfaces',
        printableTableName => __('Captive Interfaces'),
        printableRowName   => __('interface'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of interfaces where Captive Portal is enabled.'),
        modelDomain        => 'CaptivePortal',
        enableProperty     => 1,
        defaultEnabledValue => 0,
    };

    return $dataTable;
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if (not $self->bwmonitorNeeded()) {
        return;
    }

    my $iface = $row->valueByName('interface');
    my $enabled = $row->valueByName('enabled');
    my $sync = $self->_syncBWMonitorIface($iface, $enabled);
    if ($sync) {
        # XXX this message will not apeear due to a limitation of edit-bool in place
        $self->setMessage(__x(
            'Interface {if} set to {val} in bandwith monitor module',
            if => $iface,
            val => $enabled ? __('enabled') : __('disabled')
           ));
    }

 }

sub _syncBWMonitorIface
{
    my ($self, $iface, $enabled) = @_;
    my $bwMonitorInterfaces = $self->global()->modInstance('bwmonitor')->model('Interfaces');
    my $bwEnabled = $bwMonitorInterfaces->interfaceIsEnabled($iface);
    if ($bwEnabled == $enabled) {
        return 0;
    }
    $bwMonitorInterfaces->enableInterface($iface, $enabled);
    return 1;
}

sub interfaceNeedsBWMonitor
{
    my ($self, $interface) = @_;
    if (not $self->parentModule()->isEnabled()) {
        return 0;
    }
    if (not $self->bwmonitorNeeded()) {
        return 0;
    }

    my $row = $self->find(interface => $interface);
    return $row->valueByName('enabled');
}

sub bwmonitorNeeded
{
    my ($self) = @_;
    my $bwSettings =  $self->parentModule()->model('BWSettings');
    return $bwSettings->limitBWValue();
}

sub bwMonitorEnabled
{
    my ($self) = @_;

    my $anySync = 0;
    foreach my $id (@{$self->enabledRows()  }) {
        my $row = $self->row($id);
        my $iface = $row->valueByName('interface');
        my $sync = $self->_syncBWMonitorIface($iface, 1);
        $sync and $anySync = 1;
    }

    return $anySync;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
#   Populate table with internal ifaces
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    my $ifaces = EBox::Global->modInstance('network')->InternalIfaces();

    my %currentIfaces = map { $self->row($_)->valueByName('interface') => $_ }
    @{$currentRows};

    my %realIfaces = map { $_ => 1 } @{$ifaces};

    # Check if there is any module that has not been added yet
    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @{$ifaces};
    my @ifacesToDel = grep { not exists $realIfaces{$_} } keys %currentIfaces;

    return 0 unless (@ifacesToAdd + @ifacesToDel);

    for my $iface (@ifacesToAdd) {
        $self->add(interface => $iface, enabled => 0);
    }

    foreach my $iface (@ifacesToDel) {
        my $id = $currentIfaces{$iface};
        $self->removeRow($id, 1);
    }

    return 1;
}

1;
