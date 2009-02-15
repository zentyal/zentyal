# Copyright (C) 2009 eBox Technologies S.L.
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

# This is the interface that modules that want to provide UserCorner CGIs need
# to implement
package EBox::UserCorner::Provider;

use strict;
use warnings;

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: userMenu
#
#   This function returns is similar to EBox::Module::Base::menu but
#   returns UserCorner CGIs for the eBox UserCorner. Override as needed.
sub userMenu
{
    #default empty implementation
    return undef;
}

1;
