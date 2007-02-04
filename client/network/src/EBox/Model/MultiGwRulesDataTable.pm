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

sub selectOptions
{
	my ($self, $id) = @_;
	
	my @options;
	if ($id eq 'iface') {
		@options = @{$self->_internalInterfaces};
				
	} elsif ($id eq 'destination_object' or $id eq 'source_object') {
		@options = @{$self->_objects()};

	} elsif ($id eq 'protocol') {
		@options = 
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

	} elsif ($id eq 'gateway') {
		my $network = EBox::Global->modInstance('network');
		foreach my $gw (@{$network->gateways()}) {
			push (@options, {
					'value' => $gw->{'id'},
					'printableValue' => $gw->{'name'}
					});
		}
	}

	return \@options;
}

sub table
{
	my @tableHead = 
	 ( 
		new EBox::Types::Select(
					'fieldName' => 'protocol',
					'printableName' => __('Protocol'),
					'class' => 'tcenter',
					'type' => 'select',
					'size' => '12',
					'unique' => 0,
					'editable' => 1
				      ),	
		new EBox::Types::Select(
					'fieldName' => 'iface',
					'printableName' => __('Interface'),
					'class' => 'tcenter',
					'type' => 'select',
					'size' => '12',
					'unique' => 0,
					'editable' => 1
				      ),
		new EBox::Types::Union(
					'fieldName' => 'source',
					'printableName' => __('Source'),
					'class' => 'tcenter',
					'type' => 'union',
					'optional' => 1,
					'subtypes' => 
						[
						 new EBox::Types::IPAddr(
						 	'fieldName' => 'source_ipaddr',
							'printableName' => __('Source IP'),
							'class' => 'tcenter',
							'type' => 'ipaddr',
							'unique' => 0,
							'editable' => 1,
							'optional' => 1),
						new EBox::Types::Select(
						 	'fieldName' => 'source_object',
							'printableName' => __('Source object'),
							'class' => 'tcenter',
							'type' => 'select',
							'unique' => 0,
							'editable' => 1)
						],

					'size' => '16',
					'unique' => 1,
					'editable' => 1
				),
		new EBox::Types::Int(
					'fieldName' => 'source_port',
					'printableName' => __('Port'),
					'class' => 'tcenter',
					'type' => 'int',
					'size' => '3',
					'unique' => 0,
					'editable' => 1,
					'optional' => 1
				),
		new EBox::Types::Union(
					'fieldName' => 'destination',
					'printableName' => __('Destination'),
					'class' => 'tcenter',
					'type' => 'union',
					'optional' => 1,
					'subtypes' => 
						[
						 new EBox::Types::IPAddr(
						 	'fieldName' => 'destination_ipaddr',
							'printableName' => __('Destination IP'),
							'class' => 'tcenter',
							'type' => 'ipaddr',
							'unique' => 0,
							'editable' => 1,
							'optional' => 1),
						new EBox::Types::Select(
						 	'fieldName' => 'destination_object',
							'printableName' => __('Destination object'),
							'class' => 'tcenter',
							'type' => 'select',
							'unique' => 0,
							'editable' => 1)
						],

					'size' => '16',
					'unique' => 1,
					'editable' => 1
				),
		new EBox::Types::Int(
					'fieldName' => 'destination_port',
					'printableName' => __('Port'),
					'class' => 'tcenter',
					'type' => 'int',
					'size' => '3',
					'unique' => 0,
					'editable' => 1,
					'optional' => 1
				),
		new EBox::Types::Select(
					'fieldName' => 'gateway',
					'printableName' => __('Gateway'),
					'class' => 'tcenter',
					'type' => 'select',
					'size' => '12',
					'unique' => 0,
					'editable' => 1
				      )


	 );

	my $dataTable = 
		{ 
			'tableName' => 'multigwrulestable',
			'printableTableName' => __('Multigateway rules'),
			'actions' =>
				{
				'add' => 
				  '/ebox/Network/Controller/MultiGwRulesDataTable', 
				'del' => 
				  '/ebox/Network/Controller/MultiGwRulesDataTable', 
				'move' => 
				  '/ebox/Network/Controller/MultiGwRulesDataTable', 
				'editField' => 
				  '/ebox/Network/Controller/MultiGwRulesDataTable', 
				'changeView' =>
				  '/ebox/Network/Controller/MultiGwRulesDataTable', 
				},
				
			'tableDescription' => \@tableHead,
			'class' => 'dataTable',
			'order' => 1,
			'help' => __('You can decide what kind of traffic goes out by each gateway. This way, you can force a subnet, service, destiantion and so forth  to use the router you choose. Please, bear in mind that rules will be applied in order, from top to bottom, you can reorder them once they are added. If you do not set a port or an IP address, then the rule will match all of them')
		};

	return $dataTable;
}

sub validateRow()
{
	my $self = shift;
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


sub _objects
{
	my $self = shift;

	my $objects = EBox::Global->modInstance('objects');
	
	my @options;
	foreach my $object (@{$objects->ObjectsArray()}) {
		push (@options, { 
				 'value' => $object->{'name'},
				 'printableValue' => $object->{'description'}
				 });
	}

	return \@options;
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
	return $objects->ObjectAddresses($object);	
}

sub _buildIptablesRule
{
	my ($self, $row) = @_;


	my $network = EBox::Global->modInstance('network');
	my $marks = $network->marksForRouters();

	my $hVal = $row->{'valueHash'};
	my $proto = $hVal->{'protocol'}->printableValue();
	my $iface = $hVal->{'iface'}->value();
	my $srcType = $hVal->{'source'}->selectedType();
	my $srcPort = $hVal->{'source_port'}->printableValue();
	my $dstType = $hVal->{'destination'}->selectedType();
	my $dstPort = $hVal->{'destination_port'}->printableValue();
	my $gw = $hVal->{'gateway'}->value();

	my @ifaces = @{$self->_ifacesForRule($iface)};
	
	my @src;
	if ($srcType eq 'source_ipaddr') {
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
	if ($dstType eq 'destination_ipaddr') {
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
	for my $riface (@ifaces) {
		for my $rsrc (@src) {
			for my $rdst (@dst) {
				$rule .=  " -i $riface";
				if ($rsrc ne '') {
					$rule .= " -s $rsrc";
				}
				if ($rdst ne '') {
					$rule .= " -d $rdst";
				}
				my $ruleMark  = "$rule -j MARK "
						. "--set-mark  $marks->{$gw}";
				my $ruleAccept = "$rule -j ACCEPT";
				return ($ruleMark, $ruleAccept) ;
			}
		}
	}

	return undef;
}

sub _internalInterfaces
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
