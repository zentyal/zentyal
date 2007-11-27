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
use warnings;
use strict;

use Test::More tests => 44;
use Test::Exception;
use Test::Deep;
use Data::Dumper;
use Net::IP;

use EBox::Global;
use EBox;

use lib '../../../..';

use EBox::Types::Service;

BEGIN {
    diag ( 'Starting EBox::TrafficShaping test' );
    use_ok ( 'EBox::TrafficShaping' )
      or die;
}

EBox::init();

# Delete gconf entries
#system( 'gconftool --recursive-unset /ebox/modules/trafficshaping' );
#cmp_ok( $?, "==", 0, 'All gconf entries were deleted');

# Start testing
my $gl = EBox::Global->getInstance();
my $ts;
lives_ok { $ts = $gl->modInstance( 'trafficshaping' ) }
  'Getting a traffic shaping instance';

my $net;
lives_ok { $net = $gl->modInstance( 'network' ) }
  'Getting a network instance';

my $objs;
lives_ok { $objs = $gl->modInstance( 'objects' ) }
  'Getting an objects instance';

my $servs;
lives_ok { $servs = $gl->modInstance('services') }
  'Getting a service instance';

my $gwModel;
lives_ok { $gwModel = $net->gatewayModel(); }
  'Getting gateway model';

# Check if there are enough interfaces
unless ( $ts->enoughInterfaces() ) {
    plan( skip_all => 'It is required to have at least one internal and one external interface ' .
          'to do traffic shaping');
}

my $intIface = $net->InternalIfaces()->[0];
my $downRate = $ts->totalDownloadRate();

lives_ok {
    # Adding a gateway to an external interface if there is no in order to
    # test ingress traffic
    my $intIface = $net->InternalIfaces()->[0];

    my $gwName = '';

    if ( $downRate == 0) {
        # Create a gateway on a extIface
        my $extIface;
        do {
            $extIface = $net->ExternalIfaces()->[0];
        } until ( $net->ifaceMethod($extIface) eq 'static' );
        my $ip = $net->ifaceAddresses($extIface)->[0];
        my $ifaceAddr = new Net::IP($ip->{address} . '/' . $ip->{netmask});
        $ifaceAddr++;
        $gwName = 'foowarp';
        $gwModel->add(
                      name      => $gwName,
                      ip        => $ifaceAddr->ip(),
                      interface => $extIface,
                      upload    => 1000,
                      download  => 1000,
                      weight    => 1,
                      default   => 0,
                     );
        $downRate = $ts->totalDownloadRate();

    }
} 'Adding a gateway to an external interface if required';

my $testObj;
lives_ok {
    my @objects = @{$objs->objects()};
    ( $testObj ) = grep { $_->{name} eq 'fooObject' } @objects;
    unless ( defined ( $testObj )) {
        $testObj = $objs->addObject( name => 'fooObject',
                                     members => [
                                                 { name      => 'foo1',
                                                   ipaddr_ip => '10.0.0.1',
                                                   ipaddr_mask => 32,
                                                   macaddr => '00:00:00:FA:BA:DA'},
                                                 { name      => 'foo2',
                                                   ipaddr_ip => '10.0.1.0',
                                                   ipaddr_mask => 24},
                                                ],
                                   );
    } else {
        $testObj = $testObj->{id};
    }
} 'Adding an object';

my ($anyServ, $sshServ, $customServ, $greServ, $icmpServ);
ok ( $anyServ = $servs->serviceId('any'), q{Getting 'any' service id});
ok ( $sshServ = $servs->serviceId('ssh'), q{Getting 'ssh' service id});

if ( $servs->serviceExists( name => 'test') ) {
    ok ( $customServ = $servs->serviceId( 'test' ),
         q{Getting 'test' service id});
} else {
    ok ( $customServ = $servs->addService(name => 'test',
                                          description => 'Test service',
                                          protocol => 'tcp',
                                          sourcePort => '10:13',
                                          destinationPort => '30',
                                          internal => 0,
                                          readOnly => 0),
         q{Creating a custom 'test' service});
}

if ( $servs->serviceExists( name => 'gre') ) {
    ok ( $greServ = $servs->serviceId( 'gre' ),
         q{Getting 'gre' service id});
} else {
    ok ( $greServ = $servs->addService(name => 'gre',
                                       description => 'GRE protocol',
                                       protocol => 'gre',
                                       sourcePort => 'any',
                                       destinationPort => 'any',
                                       internal => 0,
                                       readOnly => 1),
         q{Creating 'gre' service for GRE protocol});
}

if ( $servs->serviceExists( name => 'icmp') ) {
    ok ( $icmpServ = $servs->serviceId( 'icmp' ),
         q{Getting 'icmp' service id});
} else {
    ok ( $icmpServ = $servs->addService(name => 'icmp',
                                        description => 'ICMP protocol',
                                        protocol => 'icmp',
                                        sourcePort => 'any',
                                        destinationPort => 'any',
                                        internal => 0,
                                        readOnly => 1),
         q{Creating 'icmp' service for ICMP protocol});
}

my @rulesAdded = ();
lives_ok {
push (@rulesAdded,
      $ts->addRule($intIface,
                   service         => $sshServ,
                   source          => { source_any => '.' },
                   destination     => { destination_any => '.' },
                   guaranteed_rate => 0,
                   limited_rate    => 11,
                   priority        => 0,
                   enabled         => 1,
                  ));
} 'Adding a rule as service (step 1)';

lives_ok {
push (@rulesAdded,
      $ts->addRule($intIface,
                   service         => $anyServ,
                   source          => { source_ipaddr => '192.168.45.0/24' },
                   destination     => { destination_ipaddr => '192.168.45.0/24' },
                   priority        => 1,
                   guaranteed_rate => 190,
                   limited_rate    => 200,
                   enabled         => 1,
                  ));
} 'Adding a rule shaping from IP source only (step 2)';

lives_ok {
push (@rulesAdded,
      $ts->addRule($intIface,
                   service         => $greServ,
                   source          => { source_macaddr => '00:0C:29:32:2D:E3' },
                   destination     => { destination_any => '' },
                   priority        => 1,
                   guaranteed_rate => 0,
                   limited_rate    => 20,
                   enabled         => 1,
                  ));
} 'Adding a rule shaping GRE traffic from a MAC address (step 2)';

lives_ok {
push (@rulesAdded,
      $ts->addRule($intIface,
                   service         => $icmpServ,
                   source          => { source_object => $testObj },
                   destination     => { destination_object => $testObj },
                   priority        => 1,
                   guaranteed_rate => 60,
                   limited_rate    => 0,
                   enabled         => 1,
                  ));
} 'Adding a rule shaping ICMP traffic from an object (step 2)';

lives_ok {
push (@rulesAdded,
      $ts->addRule($intIface,
                   service         => $customServ,
                   source          => { source_object => $testObj },
                   destination     => { destination_any => '' },
                   priority        => 2,
                   guaranteed_rate => 60,
                   limited_rate    => 0,
                   enabled         => 1,
                  ));
} 'Adding a rule shaping complex service traffic from an object (step 2)';

isa_ok( $ts->ruleModel($intIface), 'EBox::TrafficShaping::Model::RuleTable',
        'Getting a correct model');

is( $ts->ruleModel('etth0'), undef, 'Bad interface');

throws_ok {
    $ts->addRule($intIface,
                 service => $anyServ,
                 source  => { source_ipaddr => '334.121.421.11/11' },
                 destination => { destination_any => '' },
                 priority        => 2,
                 guaranteed_rate      => 0,
                 limited_rate         => 1,
                 enabled => 1,
                )
} 'EBox::Exceptions::InvalidData', 'Bad IP address';

throws_ok {
    $ts->addRule($intIface,
                 service => $anyServ,
                 source  => { source_macaddr => '334' },
                 destination => { destination_any => '' },
                 priority        => 2,
                 guaranteed_rate      => 0,
                 limited_rate         => 1,
                 enabled => 1,
                );
} 'EBox::Exceptions::InvalidData', 'Bad MAC address';

throws_ok {
    $ts->addRule($intIface,
                 service => $anyServ,
                 source  =>  { source_object => 'sadfafa232' },
                 destination => { destination_any => '' },
                 priority        => 2,
                 guaranteed_rate      => 0,
                 limited_rate         => 1,
                 enabled => 1,
                );
} 'EBox::Exceptions::InvalidData', 'Inexistent object';

throws_ok {
    $ts->addRule($intIface,
                 service => $sshServ,
                 source  => { source_any => '' },
                 destination => { destination_any => '' },
                 priority        => 2,
                 guaranteed_rate  => 820,
                 limited_rate     => 111111,
                 enabled => 1,
                );
} 'EBox::Exceptions::External', 'Bad rate';

throws_ok {
    $ts->addRule($intIface,
                 service => $sshServ,
                 source  => { source_any => '' },
                 destination => { destination_any => '' },
                 guaranteed_rate  => 0,
                 limited_rate     => -1,
                 enabled => 1,
                );
} 'EBox::Exceptions::InvalidData', 'Bad rate';

throws_ok {
    $ts->addRule($intIface,
                 service => $anyServ,
                 source  => { source_any => '' },
                 destination => { destination_any => '' },
                 priority        => 2,
                 guaranteed_rate  => 0,
                 limited_rate     => 1,
                 enabled => 1,
                );
} 'EBox::Exceptions::External', 'No rule to apply';

throws_ok {
    $ts->addRule($intIface,
                 service => $sshServ,
                 source  => { source_any => '' },
                 destination => { destination_any => '' },
                 priority        => 9,
                 guaranteed_rate  => 0,
                 limited_rate     => 111,
                 enabled => 1,
                );
} 'EBox::Exceptions::InvalidData', 'Bad priority';

my $rules_ref = $ts->listRules($intIface);
my $rulesNum = scalar(@{$rules_ref});

cmp_ok ( $rulesNum, '>=', 5,
	 'Checking rules were added correctly'
       );

throws_ok { $ts->removeRule($intIface) }
  'EBox::Exceptions::Internal', 'Missing id rule';

throws_ok { $ts->removeRule( $intIface, 'rule100' );
        } 'EBox::Exceptions::DataNotFound', 'Rule not found';

lives_ok { $ts->removeRule( $intIface, pop( @rulesAdded )); } 'Remove rule';

$rules_ref = $ts->listRules($intIface);

cmp_ok ( scalar(@{$rules_ref}), '==', $rulesNum - 1,
	 'Rule correctly removed');

lives_ok { $ts->enableRule( $intIface, 0, 1) } 'Enabling first rule';

cmp_ok($ts->isEnabledRule($intIface, 0)->value(), '==', 1,
       'Enabling first rule was done correctly');

lives_ok { $ts->enableRule( $intIface, 0, 0) } 'Disabling first rule';

cmp_ok($ts->isEnabledRule($intIface, 0)->value(), '==', 0,
       'Disabling first rule was done correctly');

lives_ok {
    $ts->updateRule( $intIface,
                     $rulesAdded[0],
                     service => $customServ,
                     source  => { source_any => '' },
                     destination => { destination_any => '' },
                     priority        => 5,
                     guaranteed_rate  => 60,
                     limited_rate     => 0,
                   );
} 'Updating a rule';

my $answer;
lives_ok {
    $answer = $ts->getRule($intIface,
                           $rulesAdded[0],
                           [ 'service', 'source', 'destination',
                             'guaranteed_rate', 'limited_rate',
                             'priority' ])
} 'Getting a rule';

my $answerPrintableValues = $answer->{printableValueHash};
cmp_deeply( $answerPrintableValues,
           superhashof({service => 'test',
                        source  => 'Cualquiera',
                        destination => 'Cualquiera',
                        guaranteed_rate => 60,
                        limited_rate => 0,
                        priority => 5}),
            'Update was done correctly');

# Checks lowest priority
lives_ok {
    $ts->addRule( $intIface,
                  service => $customServ,
                  source  => { source_any => '' },
                  destination => { destination_any => '' },
                  priority        => 7,
                  guaranteed_rate  => 60,
                  limited_rate     => 120,
                  enabled => 0,
                );
}  'Adding third correct rule';

cmp_ok( $ts->getLowestPriority($intIface, 'search'), '==', 7,
	'Checking adding lowest priority');

$rules_ref = $ts->listRules($intIface);

# Get the rule id from recently created rule
my $ruleId;
foreach my $rule_ref (@{$rules_ref}) {

    $ruleId = $rule_ref->{ruleId};
    last if ($rule_ref->{service} eq $customServ
             and $rule_ref->{guaranteed_rate} == 60
             and $rule_ref->{limited_rate} == 120);
}
lives_ok { $ts->removeRule( $intIface, $ruleId ) } 'Removing last added';

cmp_ok( $ts->getLowestPriority($intIface, 'search'), '==', 5,
	'Checking updating lowest priority');

lives_ok {
    foreach my $ruleId (@rulesAdded) {
        $ts->removeRule($intIface, $ruleId);
    }
} 'Remove everything we put inside';
