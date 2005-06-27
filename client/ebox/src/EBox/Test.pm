# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Test;

use Test::Unit::Procedural;

my @modules = ("EBox::Test::Firewall");

sub testModule # (module) 
{
	my $mod = shift;
	create_suite();
	create_suite($mod);
	add_suite($mod);
	run_suite();
}

sub testAllModules 
{
	create_suite();
	foreach (@modules) {
		create_suite($_);
		add_suite($_);
	}

	run_suite();
}
