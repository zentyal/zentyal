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

# Method: _fieldDescription
#
#   Return the field description for a firewall redirect table. You have to
#   decided if you need destination, source, or both of them.
#
# Returns:
#
#   Array ref of objects derivated of <EBox::Types::Abstract>	
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
