# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Util::SystemKernel;

use EBox;
use AptPkg::Cache;
use strict;

sub kernels
{
	my $cache = AptPkg::Cache->new;
	my @flavours = ('server', 'virtual', 'ec2', '386', 'generic', 'generic-pae');
	my @kernels = ();

	foreach my $flavour (@flavours) {
		if ($cache->{'linux-image-' . $flavour}) {
			if ( $cache->{'linux-image-' . $flavour}{CurrentState} eq 'Installed') {
				push (@kernels, 'linux-image-' . $flavour);
			}
		}
	}
	
	return \@kernels;
}

1;
