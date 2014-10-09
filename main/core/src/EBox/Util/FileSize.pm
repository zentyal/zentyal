#!/usr/bin/perl -w
#
# Copyright (C) 2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::Util::FileSize;

# Utility methods for file sizing

# Function: printableSize
#
#     Return a string with a printable string from a bytes number.
#
# Parameters:
#
#     size - Int the number of bytes
#
# Returns:
#
#     String - the bytes in a printable format.
#
#     Example: 10.00 MB, 12.04 GB, 102 B
#
sub printableSize
{
    my ($size) =  @_;

    if ($size < 1024) {
        return "$size B";
    }

    my @units = qw(KB MB GB);
    foreach my $unit (@units) {
        $size = sprintf("%.2f", $size / 1024);
        if ($size < 1024) {
            return "$size $unit";
        }
    }

    return $size . ' ' . (pop @units);
}

1;
