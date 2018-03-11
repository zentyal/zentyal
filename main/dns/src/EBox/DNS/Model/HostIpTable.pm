# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class:
#
#   EBox::DNS::Model::HostIpTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains domains names and a reference
#   to a member <EBox::DNS::Model::AliasTable>
#
#
package EBox::DNS::Model::HostIpTable;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::HostIP;
use EBox::Types::Text;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub validateRow
{
    my ($self, $action, %params) = @_;

    $self->parentModule()->checkDuplicatedIP($params{ip}, $self->parentRow()->parentRow()->valueByName('domain'));
}

sub pageTitle
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();

    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('hostname');
}

# Method: _table
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead = (
        new EBox::Types::HostIP(
            fieldName => 'ip',
            printableName => __('IP'),
            size => '20',
            unique => 1,
            editable => 1,
        ),
        new EBox::Types::Text(
            fieldName => 'iface',
            printableName => __('Interface'),
            optional => 1,
            editable => 0,
            hidden => 1,
        ),
    );

    my $dataTable = { tableName => 'HostIpTable',
                      printableTableName => __('IP'),
                      automaticRemove => 1,
                      defaultController => '/Dns/Controller/HostIpTable',
                      defaultActions => ['add', 'del', 'editField',  'changeView'],
                      tableDescription => \@tableHead,
                      class => 'dataTable',
                      help => __('The host name will be resolved to this list of IP addresses.'),
                      printableRowName => __('IP') };

    return $dataTable;
}

1;
