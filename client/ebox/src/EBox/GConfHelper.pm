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

package EBox::GConfHelper;

use strict;
use warnings;

use EBox::Exceptions::NotImplemented;
use EBox::Gettext;

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{mod} = shift;
	my $ro = shift;
	if (($self->{mod}->name ne "global") && $ro) {
		$self->{ro} = 1;
	}
	bless($self, $class);
	return $self;
}

sub isReadOnly
{
	my $self = shift;
	return $self->{ro};
}

# must be implemented by subclasses
sub key # (key)
{
	throw EBox::Exceptions::NotImplemented();
}

# empty, may be implemented by subclasses
sub backup 
{
}

1;
