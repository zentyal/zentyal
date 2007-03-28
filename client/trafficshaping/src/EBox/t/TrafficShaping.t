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

use Test::More tests => 27;
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox::Global;
use EBox;

use lib '../..';

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

my $ruleModel;

lives_ok { $ruleModel = $ts->ruleModel('eth1') }
  'Getting rule model for an external interface';

lives_ok { $ruleModel->addRow(
			      protocol        => 'tcp',
			      port            => 80,
			      guaranteed_rate => 60,
			      limited_rate    => 61,
			     );
	 }
  'Adding a correct rule';

lives_ok { $ruleModel->addRow(
			      protocol        => 'udp',
			      port            => 11122,
			      guaranteed_rate => 190,
			      limited_rate    => 200,
			     )
	 }
  'Adding another correct rule';

throws_ok { $ruleModel->addRow(
			       port            => 11122,
			       guaranteed_rate => 111,
			       limited_rate    => 111,
			      )
	  } EBox::Exceptions::MissingArgument,
  'Missing argument';

throws_ok{ $ts->ruleModel('eth0')
	 } EBox::Exceptions::External,
  'Bad interface';

throws_ok { $ruleModel->addRow(
			       protocol        => 'gre',
			       port            => 11122,
			       guaranteed_rate => 111,
			       limited_rate    => 111,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad protocol';

throws_ok { $ruleModel->addRow(
			       protocol       => 'udp',
			       port           => 1111112,
			       guaranteed_rate => 111,
			       limited_rate    => 111,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad port';

throws_ok { $ruleModel->addRow(
			       protocol        => 'udp',
			       port            => 1112,
			       guaranteed_rate => 820,
			       limited_rate    => 1111,
			      )
	  } EBox::Exceptions::External,
  'Bad rate';

throws_ok { $ruleModel->addRow(
			       protocol        => 'udp',
			       port            => 1112,
			       guaranteed_rate => 0,
			       limited_rate    => -1,
			      )
	  } EBox::Exceptions::InvalidData,
  'Bad rate';

# I maintain old interface to check priority stuff
throws_ok { $ts->addRule(
			 interface      => 'eth1',
			 protocol       => 'udp',
			 port           => 1112,
			 guaranteedRate => 0,
			 limitedRate    => 111,
			 enabled        => 0,
			 priority       => -1,
			)
	  } EBox::Exceptions::InvalidData,
  'Bad priority';

my $rules_ref = $ts->listRules('eth1');

cmp_ok ( scalar(@{$rules_ref}), '==', 2,
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

$rules_ref = $ts->listRules('eth1');

cmp_ok ( scalar(@{$rules_ref}), '==', 1,
	 'Rule correctly removed');

SKIP: {
  skip 'Enable/Disable feature', 2;
  lives_ok { $ts->enableRule('eth1', $rules_ref->[0]->{ruleId}, 1) }
    'Enabling a rule';

  ok ( $ts->get_bool('eth1/user_rules/' . $rules_ref->[0]->{ruleId} . '/enabled'),
       'Checking correctly enabled');
}

my $oldRule = $ts->listRules('eth1')->[0];

throws_ok { $ruleModel->setRow(
			      id => $rules_ref->[0]->{ruleId},
			     )
	  } EBox::Exceptions::MissingArgument,
  'Non updating';

my $ruleId = $ts->listRules('eth1')->[0]->{ruleId};

lives_ok { $ruleModel->setRow(
			      id              => $ruleId,
			      protocol        => 'tcp',
			      port            => 21,
			      guaranteed_rate => 100,
			      limited_rate    => 0,
			     );
	 }
  'Updating a rule';

my $updatedRule = $ts->listRules('eth1')->[0];

cmp_deeply(
	   {
	    ruleId          => $updatedRule->{ruleId},
	    protocol        => 'tcp',
	    port            => 21,
	    guaranteed_rate => 10,
	    limited_rate    => 0,
#	    priority        => 2,
	    enabled         => 'enabled',
	   },
	   $updatedRule,
	   'Check updated rule'
	  );

# Checks lowest priority
lives_ok { $ruleModel->addRow(
			protocol        => 'tcp',
			port            => 82,
			guaranteed_rate => 100,
			limited_rate    => 120,
#			enabled         => 1,
		       )
	 }
  'Adding third correct rule';

cmp_ok( $ts->getLowestPriority('eth1'), '==', 2,
	'Checking adding lowest priority');

$rules_ref = $ts->listRules('eth1');

# Get the rule id from recently created rule
foreach my $rule_ref (@{$rules_ref}) {

  $ruleId = $rule_ref->{ruleId};
  last if ($rule_ref->{protocol} eq 'tcp' and
	   $rule_ref->{port} == 82 and
	   $rule_ref->{guaranteed_rate} == 100 and
	   $rule_ref->{limited_rate} == 120
	  );
}

lives_ok { $ruleModel->removeRow(
				 $ruleId
				)
	 }
  'Removing last added';

cmp_ok( $ts->getLowestPriority('eth1'), '==', 1,
	'Checking updating lowest priority');

