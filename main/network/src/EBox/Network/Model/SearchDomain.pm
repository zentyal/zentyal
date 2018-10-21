# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Network::Model::SearchDomain;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::Text;
use TryCatch;

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableHeader = [
        new EBox::Types::DomainName(
            fieldName     => 'domain',
            printableName => __('Domain'),
            editable      => 1,
            optional      => 1),
        new EBox::Types::Text(
            fieldName       => 'interface',
            printableName   => __('Interface'),
            editable        => 0,
            optional        => 1,
            hidden          => 1),
    ];

    my $dataTable = {
        tableName          => 'SearchDomain',
        printableTableName => __('Search Domain'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => $tableHeader,
        class              => 'dataForm',
        help               => __('This domain will be appended when trying '
                                . 'to resolve hosts if the first attempt '
                                . 'without appending it has failed.'),
        modelDomain        => 'Network',
    };

    return $dataTable;
}

# Method: updatedRowNotify
#
#   This method is overrided to update the interface field.
#
#   When search domain is updated from the resolvconf update script
#   (/etc/resolvconf/update.d/zentyal-resolvconf), the interface field is
#   populated with the value used by the network configurer daemon
#   (ifup, ifdown, etc). Otherwise, we fill with the value "zentyal_<row id>"
#
# Overrides:
#
#   <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row) = @_;

    my $interfaceElement = $row->elementByName('interface');
    my $id = 'zentyal.' . $row->id();
    if ($interfaceElement->value() ne $id) {
        $interfaceElement->setValue($id);
        $row->store();
    }
}

# Method: importSystemSearchDomain
#
#   This method populate the model with the given search domain
#
sub importSystemSearchDomain
{
    my ($self, $interface, $domain) = @_;

    try {
        $self->setValue('interface', $interface);
        $self->setValue('domain', $domain);
    } catch ($e) {
        EBox::error("Could not import search domain: $e");
    }
}

1;
