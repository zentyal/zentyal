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

package EBox::Virt::Model::NetworkSettings;

use base 'EBox::Model::DataTable';

# Class: EBox::Virt::Model::NetworkSettings
#
#      Table with the network interfaces of the Virtual Machine
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::MACAddr;

use constant MAX_IFACES => 8;

# Group: Private methods

sub _populateIfaceTypes
{
    return [
            { value => 'nat', printableValue => 'NAT' },
            { value => 'bridged', printableValue => __('Bridged') },
            { value => 'internal', printableValue => __('Internal Network') },
    ];
}

sub _populateIfaces
{
    my $virt = EBox::Global->modInstance('virt');

    my @values = map {
                        { value => $_, printableValue => $_ }
                     } $virt->ifaces();

    unshift @values, { value => 'none', printableValue => __('None'),  };
    return \@values;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
       new EBox::Types::Select(
                               fieldName     => 'type',
                               printableName => __('Type'),
                               populate      => \&_populateIfaceTypes,
                               editable      => 1,
                              ),
       new EBox::Types::Select(
                               fieldName     => 'iface',
                               printableName => __('Bridged to'),
                               populate      => \&_populateIfaces,
                               disableCache  => 1,
                               editable      => 1,
                              ),
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Internal Network Name'),
                             editable      => 1,
                             optional      => 1,
                             optionalLabel => 0,
                            ),
       new EBox::Types::MACAddr(
                           fieldName     => 'mac',
                           printableName => __('MAC Address'),
                           editable      => 1,
                           unique        => 1,
                           defaultValue  => \&randomMAC,
                          ),

    );

    my $dataTable =
    {
        tableName          => 'NetworkSettings',
        printableTableName => __('Network Settings'),
        printableRowName   => __('interface'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        tableDescription   => \@tableHeader,
        insertPosition     => 'back',
        order              => 1,
        enableProperty     => 1,
        defaultEnabledValue => 1,
        class              => 'dataTable',
        help               => __('Here you can define the network interfaces of the virtual machine.'),
        modelDomain        => 'Virt',
    };

    return $dataTable;
}

# TODO: It would be great to have something like this implemented at framework level
# for all the models
# FIXME: Workaround with RO instance needed until ModelManager always-rw bug is fixed
# all the commented lines could be restored after that
sub isEqual
{
    #my ($self, $other) = @_;
    my ($self, $vmRow) = @_;

    my $virtRO = EBox::Global->getInstance(1)->modInstance('virt');

    my @thisIds = @{$self->ids()};
    #my @otherIds = @{$other->ids()};
    my @otherIds = @{$virtRO->get_list("VirtualMachines/keys/$vmRow/settings/NetworkSettings/order")};
    return 0 unless (@thisIds == @otherIds);

    foreach my $id (@{$self->ids()}) {
        my $thisIface = $self->row($id);
        #my $otherIface = $other->row($id);
        #return 0 unless defined ($otherIface);

        foreach my $field (qw(enabled type iface name mac)) {
            my $thisField;
            if (($field ne 'mac') or $thisIface->elementExists('mac')) {
                $thisField = $thisIface->valueByName($field);
            }

            next unless defined ($thisField);
            # my $otherField = $otherIface->valueByName($field);
            my $otherField = $virtRO->get_string("VirtualMachines/keys/$vmRow/settings/NetworkSettings/keys/$id/$field");
            next unless defined ($otherField);
            return 0 unless ($thisField eq $otherField);
        }
    }

    return 1;
}

sub randomMAC
{
    my ($self) = @_;

    # XXX the fixed mac prefix is due to a strange networking bug of libvirt,
    #  with this prefix is less probable to trigger it
    my $mac = '00:1F:';
    foreach my $i (0 .. 3) {
        $mac .= sprintf("%02X", int(rand(255)));
        if ($i < 3) {
            $mac .= ':';
        }
    }

    return $mac;
}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;
    if (@{$self->ids()} >= MAX_IFACES) {
        throw EBox::Exceptions::External(__x('A maximum of {num} network interfaces are allowed', num => MAX_IFACES));
    }

    my $type = exists $changedFields->{type} ?
        $changedFields->{type}->value() : $allFields->{type}->value();
    if ($type eq 'bridged') {
        my $iface = exists $changedFields->{iface} ?
            $changedFields->{iface}->value() : $allFields->{iface}->value();
        if ($iface eq 'none') {
            if (not $self->{confmodule}->allowsNoneIface()) {
                throw EBox::Exceptions::External(
                    __("'None' interface is not allowed in your virtual machine backend")
                   );
            }
        }
    }
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    $customizer->setHTMLTitle([]);

    $customizer->setOnChangeActions(
            { type =>
                {
                  'nat' => { hide => [ 'iface', 'name' ] },
                  'bridged' => { show  => [ 'iface' ], hide => [ 'name' ] },
                  'internal' => { show  => [ 'name' ], hide => [ 'iface' ] },
                }
            });
    return $customizer;
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;

    if ($newmethod ne 'notset') {
        return;
    }

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $rowIface =$row->valueByName('iface');
        $rowIface or
            next;
        if ($rowIface eq $iface) {
            return 1;
        }
    }

    return undef;
}

sub freeIface
{
    my ($self , $iface) = @_;

    my $rowId;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $rowIface =$row->valueByName('iface');
        $rowIface or
            next;
        if ($rowIface eq $iface) {
            $rowId = $id;
            last;
        }
    }

    if ($rowId) {
        if ($self->{confmodule}->allowsNoneIface()) {
            my $row = $self->row($rowId);
            my $iface = $row->elementByName('iface');
            $iface->setValue('none');
            $row->store();
        } else {
            $self->removeRow($rowId);
        }
    }
}

1;
