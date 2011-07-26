# Copyright (C) 2011 eBox Technologies S.L.
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
use EBox::NetWrappers;

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
    my @values = map {
                        { value => $_, printableValue => $_ }
                     } EBox::NetWrappers::list_ifaces();

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

# XXX: workaround for bad directory problem
sub parent
{
    my ($self) = @_;

    my $virt = $self->parentModule();
    my $parent = $virt->model('VirtualMachines');
    my $dir = $parent->directory();
    $dir =~ s{/keys$}{};
    $parent->setDirectory($dir);

    return $parent;
}

1;
