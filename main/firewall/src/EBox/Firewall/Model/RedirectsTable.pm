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

package EBox::Firewall::Model::RedirectsTable;

use base qw(EBox::Model::DataTable EBox::Firewall::Model::RulesWithInterface);

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

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
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
         'value' => 'ah',
         'printableValue' => 'AH'
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
         },
         {
         'value' => 'all',
         'printableValue' => 'All'
         },
    );

    return \@options;
}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# XXX Disabled until we make sure that we don't reject valid rules
sub validateTypedRowDisable
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $new_iface = $allFields->{interface};
    my $new_eport = $allFields->{external_port};
    my $new_protocol = $allFields->{protocol};
    my $new_source = $allFields->{source};

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($action eq 'update' and $id eq $changedFields->{id}) {
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
             'populate' => $self->interfacePopulateSub,
             'disableCache' => 1,
             'editable' => 1);
    push (@tableHead, $iface);

    my $origDest = new EBox::Types::Union(
            'fieldName' => 'origDest',
            'printableName' => __('Original destination'),
            'subtypes' =>
            [
            new EBox::Types::Union::Text(
                'fieldName' => 'origDest_ebox',
                'printableName' => __('Zentyal')),
            new EBox::Types::IPAddr(
                'fieldName' => 'origDest_ipaddr',
                'printableName' => __('IP Address'),
                'editable' => 1,),
            new EBox::Types::Select(
                'fieldName' => 'origDest_object',
                'printableName' => __('Object'),
                'foreignModel' => $self->modelGetter('network', 'ObjectTable'),
                'foreignField' => 'name',
                'foreignNextPageField' => 'members',
                'editable' => 1),
            ]);

    push (@tableHead, $origDest);

    my $protocol = new EBox::Types::Select(
            'fieldName' => 'protocol',
            'printableName' => __('Protocol'),
            'populate' => \&protocol,
            'editable' => 1);
    push (@tableHead, $protocol);

    my $external_port = new EBox::Types::PortRange(
            'fieldName' => 'external_port',
            'printableName' => __('Original destination port'),
            # FIXME: this usability improvement cannot be
            # implemented because PortRange type cannot be
            # optional, maybe we should fix viewCustomizer to
            # automatically ignore hidden values even
            # if not marked as optional
            #'defaultSelectedType' => 'single',
            );
    push (@tableHead, $external_port);

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

    my $snat = new EBox::Types::Boolean(
            'fieldName' => 'snat',
            'printableName' => __('Replace source address'),
            'editable' => 1,
            'defaultValue' => 1,
            'help' => __(q{Replaces the original source address of the connection with the Zentyal's own address. This could be neccesary when the destination does not have a return route or has restrictive firewall rules})
    );
    push (@tableHead, $snat);

    my $plog = new EBox::Types::Boolean(
            'fieldName' => 'log',
            'printableName' => __('Log'),
            'editable' => 1,
            'help' => __x('Log new forwarded connections to {log}', log => '/var/log/syslog'));
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
        'tableName' => 'RedirectsTable',
        'printableTableName' =>
          __('List of forwarded ports'),
        'pageTitle' => __('Port Forwarding'),
        'automaticRemove' => 1,
        'defaultController' =>
            '/Firewall/Controller/RedirectsTable',
        'defaultActions' =>
            [ 'add', 'del', 'editField', 'changeView', 'clone', 'move' ],
        'order' => 1,
        'tableDescription' => $self->_fieldDescription('source' => 1),
        'menuNamespace' => 'Firewall/View/RedirectsTable',
        'printableRowName' => __('forwarding'),
    };

    return $dataTable;
}

# Method: viewCustomizer
#
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    # disable port selection in protless protocols
    my $portFields = [qw(external_port destination_port)];
    $customizer->setOnChangeActions({
        protocol => {
            'tcp/udp' => {show => $portFields},
            'tcp' => {show => $portFields},
            'udp' => {show => $portFields},

            'ah' => { hide => $portFields },
            'esp' => { hide => $portFields },
            'gre' => { hide => $portFields },
            'icmp' => { hide => $portFields },
            'all' => { hide => $portFields },
        }
    });

    return $customizer;
}

1;
