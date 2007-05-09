#!/usr/bin/perl -w

# Copyright (C) 2006 Warp Networks S.L.
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

# A module to test TrafficShaping module

use Test::More tests => 42;
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox::Global;
use EBox;

use lib '../..';

use EBox::Types::Service;

diag ( 'Starting EBox::TrafficShaping test' );

BEGIN {
  use_ok ( 'EBox::TrafficShaping' )
    or die;
}

EBox::init();

# Delete gconf entries
system( 'gconftool --recursive-unset /ebox/modules/trafficshaping' );
cmp_ok( $?, "==", 0, 'All gconf entries were deleted');

# Start testing
my $ts;
lives_ok { $ts = EBox::Global->modInstance( 'trafficshaping' ) }
  'Getting a traffic shaping instance';

my $net;
lives_ok { $net = EBox::Global->modInstance( 'network' ) }
  'Getting a network instance';

my $objs;
lives_ok { $objs = EBox::Global->modInstance( 'objects' ) }
  'Getting an objects instance';

my $gwModel;
lives_ok { $gwModel = $net->gatewayModel(); }
  'Getting gateway model';

# TODO: putting eth1 as external
SKIP: {
  skip 'Object/gateway creation', 6;
  my @gws;
  lives_ok { @gws = @{$net->gateways()} }
    'Getting gateways...';

  my $id;
  foreach my $gw (@gws) {
    if ( $gw->{name} eq 'foo' ) {
      $id = $gw->{id};
    }
  }

  if ( defined( $id ) ) {
    lives_ok { $gwModel->removeRow(id => $id); }
      'Removing previous gateway';
  }

  # Setting a gateway
  lives_ok { $gwModel->addRow(
			      interface => 'eth1',
			      default   => 'true',
			      name      => 'foo',
			      download  => 22222,
			      upload    => 22222,
			      ip        => '192.168.45.1',
			     ) }
    'Setting a gateway on an external interface';

  # Setting an object
  lives_ok { $objs->removeObjectForce('foowarp') }
    'Removing previous object';

  lives_ok { $objs->addObject('foowarp') }
    'Adding an object';

  # Adding a member
  lives_ok { $objs->addToObject(
				'foowarp',
				'192.168.45.0',
				'24',
				'',
				'foo warp description'
			       ) }
    'Adding a member';

}

my $ruleModel;
lives_ok { $ruleModel = $ts->ruleModel('eth0') }
  'Getting rule model for an interface';

lives_ok { $ruleModel->addRow(
			      service_protocol => 'tcp',
			      service_port     => 80,
			      source_selected  => 'source_object',
			      source_object    => '',
			      destination_selected  => 'destination_object',
			      destination_object    => '',
			      limited_rate     => 11,
			      guaranteed_rate  => 0,
			      priority         => 0,
			      enabled          => 1,
			     );
	 }
  'Adding a rule as a service (step 1)';

lives_ok { $ruleModel->addRow(
			      service_protocol        => 'all',
			      source_selected         => 'source_ipaddr',
			      source_ipaddr_ip        => '192.168.45.0',
			      source_ipaddr_mask      => '24',
			      destination_selected    => 'destination_ipaddr',
			      destination_ipaddr_ip   => '192.168.45.0',
			      destination_ipaddr_mask => '24',
			      priority                => 1,
			      guaranteed_rate         => 190,
			      limited_rate            => 200,
			     )
	 }
  'Adding a rule shaping from IP source only (step 2)';

lives_ok { $ruleModel->addRow(
			      service_protocol => 'gre',
			      source_selected  => 'source_macaddr',
			      source_macaddr   => '00:0C:29:32:2D:E3',
			      destination_selected  => 'destination_object',
			      destination_object    => '',
			      priority         => 1,
			      limited_rate     => 20,
			     )
	 }
  'Adding a rule shaping GRE traffic from a MAC address (step 2)';

lives_ok { $ruleModel->addRow(
			      service_protocol => 'icmp',
			      source_selected  => 'source_object',
			      source_object    => $objs->ObjectsArray()->[0]->{name},
			      destination_selected  => 'destination_object',
			      destination_object    => $objs->ObjectsArray()->[0]->{name},
			      priority         => 1,
			      guaranteed_rate  => 60,
			     )
	 }
  'Adding a rule shaping ICMP traffic from an object (step 2)';

lives_ok { $ruleModel->addRow(
			      service_protocol     => 'udp',
			      service_port         => '2221',
			      source_selected      => 'source_object',
			      source_object        => $objs->ObjectsArray()->[0]->{name},
			      destination_selected => 'destination_object',
			      destination_object   => '',
			      priority             => 2,
			      guaranteed_rate      => 60,
			     )
	 }
  'Adding a rule shaping UDP traffic to an object (step 2)';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'udp',
			       guaranteed_rate  => 111,
			       limited_rate     => 111,
			      )
	  } EBox::Exceptions::External,
  'Missing port in strict service type';

throws_ok{ $ts->ruleModel('etth0')
	 } EBox::Exceptions::External,
  'Bad interface';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'gre',
			       service_port     => 11122,
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected  => 'destination_object',
			       destination_object    => '',
			       guaranteed_rate  => 111,
			       limited_rate     => 111,
			      )
	  } EBox::Exceptions::External,
  'Bad protocol';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'udp',
			       service_port     => 1111112,
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected  => 'destination_object',
			       destination_object    => '',
			       guaranteed_rate  => 111,
			       limited_rate     => 111,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad port';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'all',
			       source_selected  => 'source_ipaddr',
			       source_ipaddr_ip => '334.121.421.11',
			       source_ipaddr_mask => 11,
			       destination_selected => 'destination_object',
			       destination_object   => '',
			       guaranteed_rate      => 0,
			       limited_rate         => 1,
			       )
	  } EBox::Exceptions::InvalidData,
  'Bad IP address';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'all',
			       source_selected  => 'source_macaddr',
			       source_macaddr   => '334',
			       destination_selected => 'destination_object',
			       destination_object   => '',
			       guaranteed_rate      => 0,
			       limited_rate         => 1,
			       )
	  } EBox::Exceptions::InvalidData,
  'Bad MAC address';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'all',
			       source_selected  => 'source_object',
			       source_object    => 'sadfafa232',
			       destination_selected => 'destination_object',
			       destination_object   => '',
			       guaranteed_rate      => 0,
			       limited_rate         => 1,
			       )
	  } EBox::Exceptions::DataNotFound,
  'Inexistent object';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'udp',
			       service_port     => 1112,
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected  => 'destination_object',
			       destination_object    => '',
			       guaranteed_rate  => 820,
			       limited_rate     => 111111,
			      )
	  } EBox::Exceptions::External,
  'Bad rate';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'udp',
			       service_port     => 1112,
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected  => 'destination_object',
			       destination_object    => '',
			       guaranteed_rate  => 0,
			       limited_rate     => -1,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad rate';

throws_ok { $ruleModel->addRow(
			       service_protocol => 'all',
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected => 'destination_object',
			       destination_object => '',
			       guaranteed_rate  => 0,
			       limited_rate     => 1,
			      )
	  } EBox::Exceptions::External,
  'No rule to apply';

# I maintain old interface to check priority stuff
throws_ok { $ruleModel->addRow(
			       service_protocol => 'udp',
			       service_port     => 1112,
			       source_selected  => 'source_object',
			       source_object    => '',
			       destination_selected => 'destination_object',
			       destination_object => '',
			       guaranteed_rate => 0,
			       limited_rate    => 111,
			       enabled        => 1,
			       priority       => 9,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad priority';

my $rules_ref = $ts->listRules('eth0');

cmp_ok ( scalar(@{$rules_ref}), '==', 5,
	 'Checking rules were added correctly'
       );

throws_ok { $ruleModel->removeRow() }
  EBox::Exceptions::MissingArgument,
  'Missing id rule';

throws_ok { $ruleModel->removeRow(
				  3243,
				 )
	  } EBox::Exceptions::DataNotFound,
  'Rule not found';

my $idToRemove = $rules_ref->[0]->{ruleId};

lives_ok { $ruleModel->removeRow( $idToRemove )
	 }
  'Remove rule';

$rules_ref = $ts->listRules('eth0');

cmp_ok ( scalar(@{$rules_ref}), '==', 4,
	 'Rule correctly removed');

SKIP: {
  skip 'Enable/Disable feature', 2;
  lives_ok { $ts->enableRule('eth1', $rules_ref->[0]->{ruleId}, 1) }
    'Enabling a rule';

  ok ( $ts->get_bool('eth1/user_rules/' . $rules_ref->[0]->{ruleId} . '/enabled'),
       'Checking correctly enabled');
}

my $oldRule = $ts->listRules('eth0')->[0];

throws_ok { $ruleModel->setRow(
			      id => $rules_ref->[0]->{ruleId},
			      )
	  } EBox::Exceptions::MissingArgument,
  'Non updating';

my $ruleId = $ts->listRules('eth0')->[0]->{ruleId};

lives_ok { $ruleModel->setRow(
			      id               => $ruleId,
			      service_protocol => 'tcp',
			      service_port     => 21,
			      source_selected  => 'source_object',
			      source_object    => '',
			      destination_selected  => 'destination_object',
			      destination_object    => '',
			      guaranteed_rate  => 60,
			      priority         => 5,
			      limited_rate     => 0,
			     );
	 }
  'Updating a rule';

my $updatedRule = $ts->listRules('eth0')->[0];

my $service = EBox::Types::Service->new ( fieldName => 'service',
					  protocol  => 'tcp',
					  port      => 21
					);

#cmp_deeply(
#	   {
#	    ruleId               => $updatedRule->{ruleId},
#	    service              => $service,
#	    source               => $objs->ObjectsArray()->[0]->{name},
#	    destination          => '',
#	    guaranteed_rate      => 60,
#	    limited_rate         => 0,
#	    priority             => 2,
#	    enabled              => 'enabled',
#	   },
#	   superhashof($updatedRule),
#	   'Check updated rule'
#	  );

# Checks lowest priority
lives_ok { $ruleModel->addRow(
			      service_protocol => 'tcp',
			      service_port     => 82,
			      source_selected  => 'source_object',
			      source_object    => '',
			      destination_selected  => 'destination_object',
			      destination_object    => '',
			      guaranteed_rate => 60,
			      limited_rate    => 120,
			      priority        => 2,
#			      enabled         => 1,
			     )
	 }
  'Adding third correct rule';

cmp_ok( $ts->getLowestPriority('eth0', 'search'), '==', 5,
	'Checking adding lowest priority');

$rules_ref = $ts->listRules('eth0');

# Get the rule id from recently created rule
foreach my $rule_ref (@{$rules_ref}) {

  $ruleId = $rule_ref->{ruleId};
  last if ($rule_ref->{service_protocol} eq 'tcp' and
	   $rule_ref->{service_port} == 82 and
	   $rule_ref->{guaranteed_rate} == 60 and
	   $rule_ref->{limited_rate} == 120
	  );
}

lives_ok { $ruleModel->removeRow(
				 $ruleId
				)
	 }
  'Removing last added';

cmp_ok( $ts->getLowestPriority('eth0', 'search'), '==', 5,
	'Checking updating lowest priority');

