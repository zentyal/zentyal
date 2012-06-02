# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::DHCP::Model::Interfaces
#
#   This class is used to display in a select form those interface
#   configuration composites to configure the DHCP server. This
#   composite is just a container for
#   <EBox::DHCP::Model::InterfaceConfiguration> composites indexed by
#   interface's name
#

package EBox::DHCP::Model::Interfaces;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Types::HasMany;

# Group: Public methods

# Constructor: new
#
#         Constructor for the dhcp interfaces model
#
# Returns:
#
#       <EBox::DHCP::Model::Interfaces> - a
#       interfaces dhcp composite
#
sub new
{
    my $class = shift;

    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


sub precondition
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance($self->parentModule->isReadOnly());
    my $net = $global->modInstance('network');
    my @ifaces = @{$net->allIfaces()};
    foreach my $iface (@ifaces) {
        if ($net->ifaceMethod($iface) eq 'static') {
            return 1;
        }
    }

    return 0;
}

sub preconditionFailMsg
{
    my ($self) = @_;
    return __('You need at least one static interface to serve DHCP');
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $global = EBox::Global->getInstance($self->parentModule()->isReadOnly());
    my $net = $global->modInstance('network');

    my @ifaces = @{$net->allIfaces()};
    @ifaces = grep { $net->ifaceMethod($_) eq 'static' } @ifaces;
    my %newIfaces =
        map { $_ => 1 } @ifaces;
    my %currentIfaces =
        map { $self->row($_)->valueByName('iface') => 1 } @{$currentRows};

    my $modified = 0;

    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @ifaces;
    foreach my $iface (@ifacesToAdd) {
        $self->add(iface => $iface);
        $modified = 1;
    }

    # Remove old rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $ifaceName = $row->valueByName('iface');
        next if exists $newIfaces{$ifaceName};
        $self->removeRow($id);
        $modified = 1;
    }

    return $modified;
}

# Group: Protected methods

sub _table
{
    my @tableDesc = (
       new EBox::Types::Text(
                             fieldName     => 'iface',
                             printableName => __('Interface'),
                             editable      => 0,
                             optional      => 0,
                            ),
       new EBox::Types::HasMany(
                                fieldName => 'configuration',
                                printableName => __('Configuration'),
                                foreignModel => 'InterfaceConfiguration',
                                foreignModelIsComposite => 1,
                                view => '/DHCP/Composite/InterfaceConfiguration',
                                backView => '/DHCP/View/Interfaces',
                               ),
    );

    my $dataTable = {
       tableName  => 'Interfaces',
       modelDomain => 'DHCP',
       pageTitle => 'DHCP',
       printableTableName => __('Interfaces'),
       tableDescription  => \@tableDesc,
       defaultActions => [ 'changeView' ],
       enableProperty => 1,
       defaultEnabledValue => 1,
       help            => __('Here you can configure the DHCP server for each internal interface, and enable or disable them'),
       printableRowName => __('interface'),
    };

    return $dataTable;
}

1;
