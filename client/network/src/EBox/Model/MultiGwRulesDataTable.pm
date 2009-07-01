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


package EBox::Network::Model::MultiGwRulesDataTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use Perl6::Junction qw( any );
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{'pageSize'} = 10;

    return $self;
}


sub gatewayModel
{
    return EBox::Global->modInstance('network')->model('GatewayTable');
}


sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}


sub serviceModel
{
    return EBox::Global->modInstance('services')->{'serviceModel'};
}


sub ifaces
{
    my $self = shift;

    my $network = EBox::Global->modInstance('network');

    my @options;
    push (@options, {
        'value' => 'any',
        'printableValue' => __('any')
    });
    foreach my $iface (@{$network->InternalIfaces()}) {
        push (@options, {
           'value' => $iface,
           'printableValue' => $iface
        });
    }

    return \@options;
}

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead =
    (
        new EBox::Types::Select(
           'fieldName' => 'iface',
           'printableName' => __('Interface'),
           'editable' => 1,
           'populate' => \&ifaces,
           'help' => __('Incoming interface to match packets. If you '.
                        ' want to match a whole subnet you can ' .
                        ' select the interface of that subnet')
            ),
        new EBox::Types::Union(
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
                    'editable' => 1,
                    'optional' => 1),
                new EBox::Types::Select(
                    'fieldName' => 'source_object',
                    'printableName' => __('Source object'),
                    'foreignModel' => \&objectModel,
                    'foreignField' => 'name',
                    'editable' => 1),
                new EBox::Types::Union::Text(
                    'fieldName' => 'source_ebox',
                    'printableName' => __('eBox'))
                ],
            'size' => '16',
            'unique' => 1,
            'editable' => 1,
            ),
        new EBox::Types::Union(
            'fieldName' => 'destination',
            'printableName' => __('Destination'),
            'subtypes' =>
                [
                new EBox::Types::Union::Text(
                    'fieldName' => 'destination_any',
                    'printableName' => __('Any')),
                new EBox::Types::IPAddr(
                    'fieldName' => 'destination_ipaddr',
                    'printableName' => __('Destination IP'),
                    'editable' => 1,
                    'optional' => 1),
                new EBox::Types::Select(
                    'fieldName' => 'destination_object',
                    'printableName' => __('Destination object'),
                    'foreignModel' => \&objectModel,
                    'foreignField' => 'name',
                    'editable' => 1)
                ],
            'size' => '16',
            'unique' => 1,
            'editable' => 1
            ),
        new EBox::Types::Select(
                'fieldName' => 'service',
                'printableName' => __('Service'),
                'foreignModel' => \&serviceModel,
                'foreignField' => 'name',
                'editable' => 1,
            ),
        new EBox::Types::Select(
            'fieldName' => 'gateway',
            'printableName' => __('Gateway'),
            'foreignModel' => \&gatewayModel,
            'foreignField' => 'name',
            'editable' => 1,
            'help' => __('Gateway to route packets matching ' .
                        'this rule')
            )
    );

    my $dataTable =
    {
        'tableName' => 'MultiGwRulesDataTable',
        'printableTableName' => __('Multigateway rules'),
        'defaultController' => '/ebox/Network/Controller/MultiGwRulesDataTable',
        'defaultActions' =>
            [
                'add', 'del',
                'move', 'editField',
                'changeView'
            ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'order' => 1,
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
        'help' => __('You can decide what kind of traffic goes out by each gateway. This way, you can force a subnet, service, destination and so forth  to use the router you choose. Please, bear in mind that rules will be applied in order, from top to bottom, you can reorder them once they are added. If you do not set a port or an IP address, then the rule will match all of them'),
        'rowUnique' => 0,
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

sub iptablesRules
{
    my $self = shift;

    my @rules;
    for my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        my @rule = $self->_buildIptablesRule($row);
        if (@rule) {
            push (@rules, @rule);
        }
    }

    return \@rules;
}


sub _ifacesForRule
{
    my ($self, $iface) = @_;

    unless ($iface eq 'any') {
        return [$iface];
    }

    my $network = EBox::Global->modInstance('network');
    my @ifaces;
    foreach my $iface (@{$network->InternalIfaces()}) {
        push (@ifaces, $iface)
    }

    return \@ifaces;
}


sub _addressesForObject
{
    my ($self, $object) = @_;

    my $objects = EBox::Global->modInstance('objects');
    return $objects->objectAddresses($object);
}


sub _buildIptablesRule
{
    my ($self, $row) = @_;

    my $network = EBox::Global->modInstance('network');
    my $services = EBox::Global->modInstance('services');
    my $marks = $network->marksForRouters();

    my $iface = $row->valueByName('iface');
    my $srcType = $row->elementByName('source')->selectedType();
    my $dstType = $row->elementByName('destination')->selectedType();
    my $serviceConf = $services->serviceConfiguration($row->elementByName('service')->value());
    my $gw = $row->valueByName('gateway');

    # Return if the gateway for this rule is disabled
    my $gwRow = gatewayModel()->find('name' => $gw);
    return unless (defined $gwRow);
    return unless ($gwRow->valueByName('enabled'));

    my @ifaces = @{$self->_ifacesForRule($iface)};

    # prepare srcs into @src array
    my @src;
    if ($srcType eq 'source_any') {
        @src = ('');
    } elsif  ($srcType eq 'source_ipaddr') {
        my $ipaddr = $row->elementByName('source')->subtype();
        my $ip;
        if ($ipaddr->ip()) {
            $ip = $ipaddr->ip() . '/' . $ipaddr->mask();
        } else {
            $ip = '';
        }
        @src = ($ip);
    } elsif  ($srcType eq 'source_ebox') {
        @src = ('');
    } else {
        my $object = $row->elementByName('source')->subtype();
        @src = @{$self->_addressesForObject($object->value())};
    }

    # prepare dsts into @dst array
    my @dst;
     if ($dstType eq 'destination_any') {
        @dst = ('');
    } elsif  ($dstType eq 'destination_ipaddr') {
        my $ipaddr = $row->elementByName('destination')->subtype();
        my $ip;
        if ($ipaddr->ip()) {
            $ip = $ipaddr->ip() . '/' . $ipaddr->mask();
        } else {
            $ip = '';
        }
        @dst = ($ip);
    } else {
        my $object = $row->elementByName('destination')->subtype();
        @dst = @{$self->_addressesForObject($object->value())};
    }

    # prepare rules determined by the service into @prerules array
    my $prefix = "-t mangle -A PREROUTING";
    if ($srcType eq 'source_ebox') {
        $prefix = "-t mangle -A OUTPUT";
    }
    my @prerules;

    my $port;
    foreach my $ser (@{$serviceConf}) {
        $port = "";
        my $protocol = $ser->{'protocol'};
        my $srcPort = $ser->{'source'};
        my $dstPort = $ser->{'destination'};

        if ($protocol eq any ('tcp', 'udp', 'tcp/udp')) {

            if ($srcPort ne 'any') {
                $port .= " --source-port $srcPort ";
            }

            if ($dstPort ne 'any') {
                $port .= " --destination-port $dstPort ";
            }

            if ($protocol eq 'tcp/udp') {
                push (@prerules, $prefix . " -p udp " . $port);
                push (@prerules, $prefix . " -p tcp " . $port);
            } else {
                push (@prerules, $prefix . " -p $protocol " . $port);
            }

        } elsif ($protocol eq any ('gre', 'icmp', 'esp')) {
            push (@prerules, $prefix . " -p $protocol " . $port);
        } elsif ($protocol eq 'any') {
            push (@prerules, $prefix . "" . $port);
        }
    }

    # generate final iptables rules from @prerules into @rules array
    my @rules;

    # src ebox (already with different prefix) we don't loop arround ifaces
    if ($srcType eq 'source_ebox') {
        for my $rule (@prerules) {
           for my $rsrc (@src) {
               for my $rdst (@dst) {
                   my $wrule = $rule;
                   if ($rsrc ne '') {
                       $wrule .= " -s $rsrc";
                   }
                   if ($rdst ne '') {
                       $wrule .= " -d $rdst";
                   }
                   my $mrule  = "$wrule -m mark --mark 0/0xff "
                                 . "-j MARK "
                                 . "--set-mark $marks->{$gw}";
                   push (@rules, $mrule);
               }
           }
        }
    } else {
        for my $rule (@prerules) {
            for my $riface (@ifaces) {
                for my $rsrc (@src) {
                    for my $rdst (@dst) {
                        my $wrule = $rule . " -i $riface";
                        if ($rsrc ne '') {
                            $wrule .= " -s $rsrc";
                        }
                        if ($rdst ne '') {
                            $wrule .= " -d $rdst";
                        }
                        my $mrule  = "$wrule -m mark --mark 0/0xff "
                                      . "-j MARK "
                                      . "--set-mark $marks->{$gw}";
                        push (@rules, $mrule);
                    }
                }
            }
        }
    }
    return @rules;
}

sub precondition
{
    my $network = EBox::Global->modInstance('network');
    my $nGateways = @{$network->gateways()};
    return $nGateways >= 2;
}

1;
