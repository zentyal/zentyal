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

# A module to test HTB tc tree structure

use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;
use Test::Deep;
use Data::Dumper;
use Tree;

diag ( 'Starting tc HTB tree structure test' );

# Create a HTB builder and dump tc commands
BEGIN {
  use_ok( 'EBox::TrafficShaping::HTBTreeBuilder' )
    or die;
}

my $builder;
my $tcTree;
my $rootValue;

lives_ok { $builder = EBox::TrafficShaping::HTBTreeBuilder->new('eth0') }
  'Creating builder';
isa_ok($builder, 'EBox::TrafficShaping::HTBTreeBuilder' );

# Build root
throws_ok { $builder->buildRoot() } 'EBox::Exceptions::MissingArgument',
  'Building HTB tree without a default class';

my $maxRate = 100; # kbit/s
lives_ok { $tcTree = $builder->buildRoot(22, $maxRate) }
  'Building HTB tree with a default class';
isa_ok($tcTree, 'Tree');

# Check structure
cmp_ok($tcTree->height(), '==', 3, 'Checking height');
$rootValue = $tcTree->root()->value();
isa_ok($rootValue, 'EBox::TrafficShaping::RootQDisc');
isa_ok($rootValue->getQueueDiscipline(), 'EBox::TrafficShaping::HTB');

# Checking child class
my ($childNode) = $tcTree->root()->children();
my $childValue = $childNode->value();

isa_ok($childValue, 'EBox::TrafficShaping::ClassTS');
cmp_deeply($childValue->getIdentifier(),
	   {
	    major => 1,
	    minor => 1,
	   },
	   'Correct identifier'
	  );

my ($leafNode) = $childNode->children();
my $leafValue = $leafNode->value();

isa_ok($leafValue, 'EBox::TrafficShaping::ClassTS');
my $qDisc = $leafValue->getAttachedQDisc();
isa_ok($qDisc, 'EBox::TrafficShaping::QDisc');
isa_ok($qDisc->getQueueDiscipline(), 'EBox::TrafficShaping::SFQ');
cmp_deeply(
	   $qDisc->getIdentifier(),
	   {
	    major => 22,
	    minor => 0,
	   },
	   'Checking leaf qdisc identifier'
	  );

# Add another rule
lives_ok { $builder->buildRule( protocol       => "tcp",
				port           => 21,
				guaranteedRate => 10,
				limitedRate    => 0,
				priority       => 2,
			 );
	 }
  'Adding a new rule';

# Add an impossible rule
throws_ok { $builder->buildRule( protocol       => "tcp",
				 port           => 11,
				 guaranteedRate => 100,
				 limitedRate    => 1,
				 priority       => 3,
			       );
	  }
  'EBox::Exceptions::External',
  'Exceeded guaranteed rate';

throws_ok { $builder->buildRule( protocol       => "tcp",
				 port           => 121,
				 guaranteedRate => 21,
				 limitedRate    => 1000,
				 priority       => 3,
			       );
	  }
  'EBox::Exceptions::External',
  'Exceeded limited rate';

# Dump tc commands
my @commands;
lives_ok { @commands = @{$builder->dumpTcCommands()} } 'Dumping tc commands';

diag("tc commands " . Dumper(\@commands));

# Dump iptables commands
lives_ok { @commands = @{$builder->dumpIptablesCommands()} }
  'Dumping iptables commands';

diag("iptables commands: " . Dumper(\@commands));


