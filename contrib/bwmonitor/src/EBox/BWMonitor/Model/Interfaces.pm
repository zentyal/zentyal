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

package EBox::BWMonitor::Model::Interfaces;

use base 'EBox::Model::DataTable';

# Class: EBox::BWMonitor::Model::Interfaces
#
#   Interfaces where bandwidth monitoring is enabled
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Exceptions::External;

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
        printableTableName => __('Configure interfaces'),
        printableRowName   => __('interface'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of monitored interfaces.'),
        checkAll           => ['enabled'],
        modelDomain        => 'BWMonitor',
        enableProperty     => 1,
        defaultEnabledValue => 0,
        noDataMsg => __("There aren't any internal interfaces to monitor"),
    };

    return $dataTable;
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

sub validateTypedRow
{
    my ($self, $action, $changes, $all) = @_;

    # dont allow to disable a interface used by captiveportal
    if (not $changes->{enabled}) {
        return;
    } elsif ($changes->{enabled}->value()) {
        return;
    }

    my $interface = $all->{interface}->value();

    if (not $self->global()->modExists('captiveportal')) {
        return;
    }
    my $captive = $self->global()->modInstance('captiveportal');
    if ($captive->model('Interfaces')->interfaceNeedsBWMonitor($interface)) {
        throw EBox::Exceptions::External(__x(
            'Cannot disable {if}, it is needed by captive portal',
            if => $interface
           ));
    }
}

sub enabledInterfaces
{
    my ($self) = @_;
    my @ifaces;

    foreach my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        push(@ifaces, $row->valueByName('interface'));
    }

    return \@ifaces;
}

sub interfaceIsEnabled
{
    my ($self, $interface) = @_;
    my $row = $self->find(interface => $interface);
    return $row->valueByName('enabled');
}

sub enableInterface
{
    my ($self, $interface, $value) = @_;
    my $row = $self->find(interface => $interface);
    $row->elementByName('enabled')->setValue($value);
    $row->store();
}

1;
