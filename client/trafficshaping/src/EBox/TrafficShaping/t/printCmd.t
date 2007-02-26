#!/usr/bin/perl -w

# Copyright (C) 2007 Warp Networks S.L.
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

# A tester to show what it is stored in HTB tree builder

use strict;
use warnings;

use Data::Dumper;
use EBox::Global;
use EBox;

EBox->init();

my $ts = EBox::Global->modInstance('trafficshaping');

my $tcCommands_ref = $ts->{builders}->{'eth1'}->dumpTcCommands();
my $ipTablesCommands_ref = $ts->{builders}->{'eth1'}->dumpIptablesCommands();

print ( Dumper($tcCommands_ref) );
print ( Dumper($ipTablesCommands_ref) );
