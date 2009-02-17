# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

# Class: EBox::Firewall::Model::RedirectsTable
#
package EBox::Firewall::Model::RedirectsTable;

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


use strict;
use warnings;


use base 'EBox::Model::DataTable';


sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub interface
{
    my $ifaces = EBox::Global->modInstance('network')->ifaces();

    my @options;
    foreach my $iface (@{$ifaces}) {
        push(@options, { 'value' => $iface, 'printableValue' => $iface });
    }

    return \@options;
}

sub protocol
{
    my  @options =
        (
         {
         'value' => 'tcp/udp',
         'printableValue' => 'TCP/UDP'
         },
         {
         'value' => 'tcp',
         'printableValue' => 'TCP'
         },
         {
         'value' => 'udp',
         'printableValue' => 'UDP'
         },
         {
         'value' => 'esp',
         'printableValue' => 'ESP'
         },
         {
         'value' => 'gre',
         'printableValue' => 'GRE'
         },
         {
         'value' => 'icmp',
         'printableValue' => 'ICMP'
         }
    );

    return \@options;
}

sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
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

    my $new_iface = $allFields->{interface};
    my $new_eport = $allFields->{external_port};
    my $new_protocol = $allFields->{protocol};
    my $new_source = $allFields->{source};

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($action eq 'update' and $row->id() eq $changedFields->{id}) {
            next; # We must not check against the row that is being modified
        }
        my $iface = $row->elementByName('interface');
        my $eport = $row->elementByName('external_port');
        my $protocol = $row->elementByName('protocol');
        my $source = $row->elementByName('source');

        ($iface->value() eq $new_iface->value()) or next;
        $self->_sameProtocol($protocol->value(), $new_protocol->value()) or next;
        $self->_samePort($eport, $new_eport) or next;
        $self->_sameSource($source, $new_source) or next;

        throw EBox::Exceptions::External(__x('Contradictory rule found. Remove it first'));
    }
}

sub _sameProtocol
{
    my ($self, $protocol, $new_protocol) = @_;

    if ($protocol eq $new_protocol) {
        return 1;
    }

    if (($protocol eq 'tcp/udp') and
         (($new_protocol eq 'tcp') or ($new_protocol eq 'udp'))) {
            return 1;
    }

    if (($new_protocol eq 'tcp/udp') and
         (($protocol eq 'tcp') or ($protocol eq 'udp'))) {
            return 1;
    }

    return 0;
}

sub _samePort
{
    my ($self, $port, $new_port) = @_;

    if (($port->rangeType() eq 'any') or ($new_port->rangeType() eq 'any')) {
        return 1;
    }

    if ($port->rangeType() eq 'single') {
        if ($new_port->rangeType() eq 'single') {
            if ($port->single() == $new_port->single()) {
                return 1;
            }
        } elsif ($new_port->rangeType() eq 'range') {
            if (($port->single() >= $new_port->from()) and
                ($port->single() <= $new_port->to())) {
                return 1;
            }
        }
    } elsif ($port->rangeType() eq 'range') {
        if ($new_port->rangeType() eq 'single') {
            if (($new_port->single() >= $port->from()) and
                ($new_port->single() <= $port->to())) {
                return 1;
            }
        } elsif ($new_port->rangeType() eq 'range') {
            if (($new_port->from() >= $port->from()) and
                ($new_port->from() <= $port->to())) {
                return 1;
            }
            if (($new_port->to() >= $port->from()) and
                ($new_port->to() <= $port->to())) {
                return 1;
            }
        }
    }

    return 0;
}

sub _sameSource
{
    my ($self, $source, $new_source) = @_;

    if (($source->selectedType() eq 'source_any') or
            ($new_source->selectedType() eq 'source_any')) {
        return 1;
    }

    if (($source->selectedType() eq 'source_ipaddr') and
        ($new_source->selectedType() eq 'source_ipaddr')) {
        if ($source->value() eq $new_source->value()) {
            return 1;
        }
    }

    # Ignore source_object's because currently we don't have
    # a way to notice changes in object members.

    return 0;
}

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

    my $iface = new EBox::Types::Select(
             'fieldName' => 'interface',
             'printableName' => __('Interface'),
             'populate' => \&interface,
             'editable' => 1);
    push (@tableHead, $iface);

    my $external_port = new EBox::Types::PortRange(
            'fieldName' => 'external_port',
            'printableName' => __('External port'),
            );
    push (@tableHead, $external_port);

    my $protocol = new EBox::Types::Select(
            'fieldName' => 'protocol',
            'printableName' => __('Protocol'),
            'populate' => \&protocol,
            'editable' => 1);
    push (@tableHead, $protocol);

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
                'foreignModel' => \&objectModel,
                'foreignField' => 'name',
                'editable' => 1),
            ],
            'unique' => 1,
            'editable' => 1);
    push (@tableHead, $source);

    my $dest = new EBox::Types::HostIP(
            'fieldName' => 'destination',
            'printableName' => __('Destination IP'),
            'editable' => 1);
    push (@tableHead, $dest);

    my $dport = new EBox::Types::Union(
            'fieldName' => 'destination_port',
            'printableName' => __('Port'),
            'subtypes' =>
            [
            new EBox::Types::Union::Text(
                'fieldName' => 'destination_port_same',
                'printableName' => __('Same')),
            new EBox::Types::Port(
                'fieldName' => 'destination_port_other',
                'printableName' => __('Other'),
                'editable' => 1,)
            ],
            'editable' => 1);
    push (@tableHead, $dport);

    return \@tableHead;
}

sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        'tableName' => 'RedirectsTable',
        'printableTableName' =>
          __('Port redirections'),
        'automaticRemove' => 1,
        'defaultController' =>
            '/ebox/Firewall/Controller/RedirectsTable',
        'defaultActions' =>
            [ 'add', 'del', 'editField', 'changeView' ],
        'tableDescription' => $self->_fieldDescription('source' => 1),
        'menuNamespace' => 'Firewall/View/RedirectsTable',
        'help' => __x(''),
        'printableRowName' => __('redirect'),
    };

    return $dataTable;
}

1;
