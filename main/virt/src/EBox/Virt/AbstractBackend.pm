# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::Virt::AbstractBackend;

use strict;
use warnings;

use EBox::Exceptions::NotImplemented;

# Class: EBox::Virt::AbstractBackend
#
#   Abstract class with the methods that each virtualization backend
#   has to implement

# Method: createDisk
#
#   Creates a disk image.
#
# Parameters:
#
#   file    - filename of the disk image
#   size    - size of the disk in megabytes
#
sub createDisk
{
    throw Ebox::Exceptions::NotImplemented();
}

1;
