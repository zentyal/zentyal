# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::Objects::Observer;

use EBox::Gettext;

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: usesObject
#
#   	Used to check if your module uses the given object. You should override
#   	this methods if your module uses objects.
#
# Parameters:
#
#       object - the name of an Object
#
# Returns
#
#      booelan  - true if this module currently uses the object, otherwise false
sub usesObject # (object)
{
        # default implementation: always returns false. Subclasses should
        # override this as needed.
        return undef;
}

# Method: freeObject
#
# 	Tells this module that an object is going to be removed, so that it can
#  	remove it from its configuration.
#
# Parameters:
#
#       object - the name of an Object
sub freeObject # (object)
{
        # default empty implementation. Subclasses should override this as
        # needed.
}

1;
