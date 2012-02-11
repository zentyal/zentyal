# Copyright (C) 2011-2012 eBox Technologies S.L.
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


package EBox::Virt::Model::NetworkSettings;

# Class: EBox::Virt::Model::NetworkSettings
#
#      Table with the network interfaces of the Virtual Machine
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::MACAddr;

use constant MAX_IFACES => 8;

# Group: Public methods

# Constructor: new
#
#       Create the new NetworkSettings model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Virt::Model::NetworkSettings> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);

    return $self;
}

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

    unshift (@values, { value => 'none', printableValue => __('None') });

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
    );

    if (EBox::Config::boolean('custom_mac_addresses')) {
        push (@tableHeader, new EBox::Types::MACAddr(
                                    fieldName     => 'mac',
                                    printableName => __('MAC Address'),
                                    editable      => 1,
                                    optional      => 1));
    }

    my $dataTable =
    {
        tableName          => 'NetworkSettings',
        printableTableName => __('Network Settings'),
        printableRowName   => __('interface'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        tableDescription   => \@tableHeader,
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
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    # XXX workaround for the bug of parentComposite with viewCustomizer
    my $composite  = $self->{gconfmodule}->composite('VMSettings');
    $self->setParentComposite($composite);

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

1;
