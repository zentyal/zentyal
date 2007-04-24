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

package EBox::FirewallHelper;

use strict;
use warnings;

use EBox::Gettext;

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: prerouting
# 
# 	Rules returned by this method are added to the PREROUTING chain in
#	the NAT table. You can use them to do NAT on the destination
#	address of packets.
#
# Returns:
#
#	array ref - containing prerouting rules
sub prerouting
{
	return [];
}

# Method: postrouting
#
# 	Rules returned by this method are added to the POSTROUTING chain in
#	the NAT table. You can use them to do NAT on the source
#	address of packets.
#
# Returns:
#
#	array ref - containing postrouting rules
sub postrouting
{
	return [];
}

# Method: forward
#
# 	Rules returned by this method are added to the FORWARD chain in
#	the filter table. You can use them to filter packets passing through
#	the firewall.
#
# Returns:
#
#	array ref - containing forward rules
sub forward
{
	return [];
}

# Method: input
#
# 	Rules returned by this method are added to the INPUT chain for INTERNAL ifaces in
#	the filter table. You can use them to filter packets directed at
#	the firewall itself.
#
# Returns:
#
#	array ref - containing input rules
sub input
{
	return [];
}

# Method: output
#
# 	Rules returned by this method are added to the OUTPUT chain in 
#	the filter table. You can use them to filter packets originated 
#	within the firewall.
#
# Returns:
#
#	array ref - containing output rules
sub output
{
	return [];
}



# Method: externalInput
#
# 	Rules returned by this method are added to the INPUT for EXTERNAL interfaces chain in
#	the filter table. You can use them to filter packets directed at
#	the firewall itself.
#
# Returns:
#
#	array ref - containing input rules
sub externalInput
{
	return [];
}


1;
