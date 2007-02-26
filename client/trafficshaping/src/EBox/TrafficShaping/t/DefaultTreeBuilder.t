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

# A module to test default tc tree structure

use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use Test::Deep;
use Data::Dumper;
use Tree;
diag ( 'Starting tc default tree structure test' );

# Create a default builder and dump tc commands
BEGIN {
  use_ok( 'EBox::TrafficShaping::DefaultTreeBuilder' )
    or die;
}

my $builder;
my $tcTree;
my $rootValue;

# Create default builder
lives_ok { $builder = EBox::TrafficShaping::DefaultTreeBuilder->new( 'eth0' ) }
  'Creating default tree';
isa_ok($builder, 'EBox::TrafficShaping::DefaultTreeBuilder' );

# Build root
lives_ok { $tcTree = $builder->buildRoot() }
  'Building default tree without arguments';
isa_ok($tcTree, 'Tree');

# Check structure
cmp_ok($tcTree->height(), '==', 1, 'Only 1 level tree');
$rootValue = $tcTree->root()->value();
isa_ok($rootValue, 'EBox::TrafficShaping::RootQDisc');
my $qd = $rootValue->getQueueDiscipline(); 
isa_ok($qd, 'EBox::TrafficShaping::PFIFO_FAST');

# Dump tc commands
my @commands;
lives_ok { @commands = @{$builder->dumpTcCommands()} } 
  'Dumping tc commands';

diag("tc commands " . Dumper(\@commands));

# Dump iptables commands
lives_ok { @commands = @{$builder->dumpIptablesCommands()} }
    'Dumping iptables commands';

diag("iptables commands: " . Dumper(\@commands));




