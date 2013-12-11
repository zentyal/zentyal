# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::NTP::Test;

use base 'EBox::Test::Class';

# Description:
#

use Test::More;
use Test::Exception;
use Test::Differences;

use File::Slurp;

use lib '../..';
use EBox::Test ':all';

sub setModuleGlobalConf : Test(startup)
{
    EBox::Global::TestStub::setAllModules('ntp' => 'EBox::NTP');
}

sub _useAndCreationTest : Test
{
    checkModuleInstantiation('ntp', 'EBox::NTP');
}

sub setAndGetServersDeviantTest : Test(20)
{
    my @deviantCases = (
			# bad IPs:
			['543.32.23.12'],
			['134.23.12.23', '543.32.23.12'],
			['134.23.12.23',  '21.46.12.34', '543.12.32.34'],
			# bad hosts:
			['badHost+'],
			['macaco', 'badHost='],
			['macaco', 'rhesus.mono.com',  'badHost|'],
			# blank entries
			[],
			[''],
			['192.168.3', ''],
			['192.168.3', 'ntp.monos.org', ''],
			['192.168.3',  '', 'ntp.monos.org'],
			['192.168.3',  '', ''],
			# repeated IPs:
			['192.168.3.1', '10.4.6.32', '192.168.3.1'],
			['192.168.3.1', '192.168.3.1', '10.4.56.23'],
			['10.4.6.31', '192.168.3.1', '192.168.3.1'],
			['192.168.3.1', '192.168.3.1', '192.168.3.1'],
			# repeated hosts
			['macaco', 'macaco'],
			['macaco', 'ntp.rhesus.org',  'macaco'],
			['macaco', 'macaco',  'ntp.rhesus.org'],
			['macaco', 'macaco',  'macaco'],

       );

    my $ntp = EBox::Global->modInstance('ntp');

    foreach my $case_r (@deviantCases) {
	my @params = @{ $case_r};
	dies_ok { $ntp->setServers(@params)   } "Checking deviant case with parameters: @params";
    }
}

sub setAndGetServersTest : Test(16)
{
    my @cases = (
		 # ips
		 ['192.168.3.4'],
		 ['192.168.3.4', '10.4.3.24'],
		 ['192.168.3.4', '10.4.3.24', '127.0.0.1'],
		 # hosts
		 ['ntp.macaco.org'],
		 ['ntp.macaco.org', 'saturno.pantheon.org'],
		 ['ntp.macaco.org', 'saturno.pantheon.org', 'madonna.timegososlowly.net'],                 # host and ips
		 ['192.168.3.4', 'ntp.macaco.org'],
		 ['192.168.3.4', 'ntp.macaco.org', '10.45.21.23'],
	    );

    my $ntp = EBox::Global->modInstance('ntp');

    foreach my $case_r (@cases) {
	my @expectedServers = @{ $case_r};
	lives_ok { $ntp->setServers(@expectedServers)   } "Checking deviant case with parameters: @expectedServers";

	my @actualServers = $ntp->servers();
	eq_or_diff \@actualServers, \@expectedServers, 'Checking that servers are stored and retrieved normally';
    }
}

1;
