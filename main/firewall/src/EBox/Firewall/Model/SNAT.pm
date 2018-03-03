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

package EBox::Firewall::Model::SNAT;

use base ('EBox::Model::DataTable', 'EBox::Firewall::Model::RulesWithInterface');

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Text;
use EBox::Types::Union::Text;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::Port;
use EBox::Types::PortRange;
use EBox::Types::Union;
use EBox::Types::HostIP;
use EBox::Sudo;
use EBox::Firewall::Model::RedirectsTable;

# Method: _fieldDescription
#
#   Return the field description for a firewall redirect table. You have to
#   decided if you need destination, source, or both of them.
#
# Returns:
#
#   Array ref of objects derivated of <EBox::Types::Abstract>
#
sub _fieldDescription
{
    my ($self) = @_;

    my @tableHead;

    my $snat = new EBox::Types::HostIP(
            'fieldName' => 'snat',
            'printableName' => __('SNAT address'),
            'editable' => 1,
            'help' => __()
    );
    push (@tableHead, $snat);

    my $iface = new EBox::Types::Select(
             'fieldName' => 'interface',
             'printableName' => __('Outgoing interface'),
             'populate' => $self->interfacePopulateSub,
             'disableCache' => 1,
             'editable' => 1);
    push (@tableHead, $iface);

    my $source = new EBox::Types::Union(
            'fieldName' => 'source',
            'printableName' => __('Source'),
            'subtypes' =>
            [
            new EBox::Types::Union::Text(
                'fieldName' => 'source_any',
                'printableName' => __('Any')),
            new EBox::Types::IPAddr(
                'fieldName' => 'source_ipaddr',
                'printableName' => __('Source IP'),
                'editable' => 1,),
            new EBox::Types::Select(
                'fieldName' => 'source_object',
                'printableName' => __('Source object'),
                'foreignModel' => $self->modelGetter('network', 'ObjectTable'),
                'foreignField' => 'name',
                'foreignNextPageField' => 'members',
                'editable' => 1),
            ],
            'unique' => 1,
            'editable' => 1);
    push (@tableHead, $source);

    my $destination = new EBox::Types::Union(
            'fieldName' => 'destination',
            'printableName' => __('Destination'),
            'subtypes' =>
            [
            new EBox::Types::Union::Text(
                'fieldName' => 'destination_any',
                'printableName' => __('Any')),
            new EBox::Types::IPAddr(
                'fieldName' => 'destination_ipaddr',
                'printableName' => __('IP Address'),
                'editable' => 1,),
            new EBox::Types::Select(
                'fieldName' => 'destination_object',
                'printableName' => __('Object'),
                'foreignModel' => $self->modelGetter('network', 'ObjectTable'),
                'foreignField' => 'name',
                'foreignNextPageField' => 'members',
                'editable' => 1),
            ]);

    push (@tableHead, $destination);

    my $service =  new EBox::Types::InverseMatchSelect(
                'fieldName' => 'service',
                'printableName' => __('Service'),
                'foreignModel' => $self->modelGetter('network', 'ServiceTable'),
                'foreignField' => 'printableName',
                'foreignNextPageField' => 'configuration',
                'editable' => 1,
                'help' => __('If inverse match is ticked, any ' .
                             'service but the selected one will match this rule')

                );
    push (@tableHead, $service);

    my $plog = new EBox::Types::Boolean(
            'fieldName' => 'log',
            'printableName' => __('Log'),
            'editable' => 1,
            'help' => __('Log new forwarded connections'));
    push (@tableHead, $plog);

    my $desc = new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'size' => '32',
            'editable' => 1,
            'optional' => 1);
    push (@tableHead, $desc);

    return \@tableHead;
}

sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        'tableName' => 'SNAT',
        'printableTableName' => __('Source Network Address Translation rules'),
        'pageTitle' => __('SNAT'),
        'automaticRemove' => 1,
        'defaultController' =>
            '/Firewall/Controller/SNAT',
        'defaultActions' =>
            [ 'add', 'del', 'move', 'editField', 'changeView', 'clone',  ],
        'order' => 1,
        'tableDescription' => $self->_fieldDescription(),
        'menuNamespace' => 'Firewall/View/SNAT',
        'printableRowName' => __('SNAT rule'),
    };

    return $dataTable;
}

sub usesIface
{
    my ($self, $iface) = @_;
    my $row = $self->find(interface => $iface);
    return $row ? 1 : 0;
}

sub freeIface
{
    my ($self, $iface) = @_;
    $self->_removeIfaceRules($iface);
}

sub freeViface
{
    my ($self, $iface, $viface) = @_;
    $self->_removeIfaceRules("$iface:$viface");
}

sub _removeIfaceRules
{
    my ($self, $iface) = @_;
    my @idsToRemove = @{ $self->findAll(interface => $iface) };
    foreach my $id (@idsToRemove) {
        $self->removeRow($id);
    }
}

1;
