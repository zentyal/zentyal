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

sub protocols
{
	my ($self) = @_;
	
	my @options = 
	  (
		{
		 'value' => 'any',
		 'printableValue' => __('any')
		 },
		{ 
		 'value' => 'tcp',
		 'printableValue' => 'tcp'
		},
		{
		 'value' => 'udp',
		 'printableValue' => 'udp'
		}
	  );	

	  return \@options;
}

sub gatewayModel
{
	my $network = EBox::Global->getInstance()->modInstance('network');
	return $network->gatewayModel();
}

sub objectModel
{
	my $objects = EBox::Global->getInstance()->modInstance('objects');
	return $objects->{'objectModel'};
}

sub _table
{


	
	my @tableHead =
	 (
		new EBox::Types::Select(
					'fieldName' => 'protocol',
					'printableName' => __('Protocol'),
					'editable' => 1,
					'populate'=> \&protocols,
				      ),	
		new EBox::Types::Select(
					'fieldName' => 'iface',
					'printableName' => __('Interface'),
					'editable' => 1,
					'populate' => \&ifaces,
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
							'editable' => 1)
						],

					'unique' => 1,
					'editable' => 1
				),
		new EBox::Types::Int(
					'fieldName' => 'source_port',
					'printableName' => __('Port'),
					'size' => '3',
					'editable' => 1,
					'optional' => 1
				),
		new EBox::Types::Union(
					'fieldName' => 'destination',
					'printableName' => __('Destination'),
					'optional' => 1,
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
		new EBox::Types::Int(
					'fieldName' => 'destination_port',
					'printableName' => __('Port'),
					'size' => '3',
					'editable' => 1,
					'optional' => 1
				),
		new EBox::Types::Select(
					'fieldName' => 'gateway',
					'printableName' => __('Gateway'),
  					'foreignModel' => \&gatewayModel,
					'foreignField' => 'name',
					'editable' => 1
				      )


	 );

	my $dataTable = 
		{ 
			'tableName' => 'MultiGwRulesDataTable',
			'printableTableName' => __('Multigateway rules'),
			'defaultController' =>
				'/ebox/Network/Controller/MultiGwRulesDataTable',
			'defaultActions' =>
				[	
				'add', 'del', 
				'move', 'editField',
				'changeView'
				],
				
				
			'tableDescription' => \@tableHead,
			'class' => 'dataTable',
			'order' => 1,
			'help' => __('You can decide what kind of traffic goes out by each gateway. This way, you can force a subnet, service, destiantion and so forth  to use the router you choose. Please, bear in mind that rules will be applied in order, from top to bottom, you can reorder them once they are added. If you do not set a port or an IP address, then the rule will match all of them'),
		        'rowUnique' => 0,
		        'printableRowName' => __('rule'),
		};

	return $dataTable;
}

# Method: validateRow
#
#      Override <EBox::Model::DataTable::validateRow> method
#
sub validateRow()
{
	my $self = shift;
	my $action = shift;
	my %params = @_;

	if (defined ($params{'destination_port'}) and 
	    $params{'destination_port'} ne '') {
		checkPort($params{'destination_port'}, __('Destination port'));
	}

	if (defined ($params{'source_port'}) and
	    $params{'source_port'} ne '') {
		checkPort($params{'source_port'}, __('Source port'));
	}

	if ($params{'protocol'} eq 'any') {
		my $sport = $params{'source_port'};
		my $dport = $params{'destination_port'};	
		if ((defined($dport) and $dport ne '') 
		    or (defined($sport) and $sport ne '')) {

			throw EBox::Exceptions::External(
			   __('Port cannot be set if no protocol is selected'));
		}

	}
}

sub removeRulesUsingRouter
{
	my ($self, $router) = @_;

	for my $row (@{$self->rows()}) {
		my $rowRouter = $row->{'valueHash'}->{'gateway'}->value();
		if ($rowRouter eq $router) {
			$self->removeRow($row->{'id'});
		}
	}
}

sub iptablesRules
{
	my $self = shift;

	my @rules;
	for my $row (@{$self->rows()}) {
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
	my $marks = $network->marksForRouters();

	my $hVal = $row->{'valueHash'};
	my $proto = $hVal->{'protocol'}->value();
	my $iface = $hVal->{'iface'}->value();
	my $srcType = $hVal->{'source'}->selectedType();
	my $srcPort = $hVal->{'source_port'}->printableValue();
	my $dstType = $hVal->{'destination'}->selectedType();
	my $dstPort = $hVal->{'destination_port'}->printableValue();
	my $gw = $hVal->{'gateway'}->value();

	my @ifaces = @{$self->_ifacesForRule($iface)};
	
	my @src;
	EBox::debug("source $srcType destination $dstType");
    if ($srcType eq 'source_any') {
        @src = ('');
    } elsif  ($srcType eq 'source_ipaddr') {
		my $ipaddr = $hVal->{'source'}->subtype();
		my $ip;
		if ($ipaddr->ip()) {
			$ip = $ipaddr->ip() . '/' . $ipaddr->mask();
		} else {
			$ip = '';
		}
		@src = ($ip);
	} else {
		my $object = $hVal->{'source'}->subtype();
		@src = @{$self->_addressesForObject($object->value())};
	}


	my @dst;
     if ($dstType eq 'destination_any') {
        @dst = ('');
    } elsif  ($dstType eq 'destination_ipaddr') {
		my $ipaddr = $hVal->{'destination'}->subtype();
		my $ip;
		if ($ipaddr->ip()) {
			$ip = $ipaddr->ip() . '/' . $ipaddr->mask();
		} else {
			$ip = '';
		}
		@dst = ($ip);
	} else {
		my $object = $hVal->{'destination'}->subtype();
		@dst = @{$self->_addressesForObject($object->value())};
	}

	my $rule = "-t mangle -A PREROUTING";
	if ($proto ne 'any') {
		$rule .= " -p $proto";
	}
	if (defined($srcPort) and $srcPort ne '') {
		$rule .=  " --source-port $srcPort";
	}
	if (defined($dstPort) and $dstPort ne '') {
		$rule .= " --destination-port $dstPort";
	}
	my @ipRules;
	for my $riface (@ifaces) {
		for my $rsrc (@src) {
			for my $rdst (@dst) {
				my $wRule = $rule .  " -i $riface";
				if ($rsrc ne '') {
					$wRule .= " -s $rsrc";
				}
				if ($rdst ne '') {
					$wRule .= " -d $rdst";
				}
				my $ruleMark  = "$wRule -m mark --mark 0/0xff "
						. "-j MARK"
						. " --set-mark  $marks->{$gw}";
				push (@ipRules, $ruleMark);
			}
		}
	}

	return @ipRules;
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


1;
