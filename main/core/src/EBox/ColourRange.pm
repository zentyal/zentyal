# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::ColourRange;
# Class: EBox::ColourRange
#
#       This class is intended to return a range of colours in RGB
#       which are similar and no kick in the head because of their
#       combination
#

my @colours = (
        '000000', #black
        '00BFFF', # deep sky blue
        '5C4033', # dark brown
        '2F4F2F', # dark green
        'FF8C00', # dark orange
        'FF1493', # deep pink
        '9932CC', # darok orchid
        'D9D919', # bright gold
        'C0C0C0', # silver grey
        '000080', # navy blue
        'DEB887', # burlywood
        'ADFF2F', # green yellow
        'FF2400', # orange red
        'FFB6C1', # light pink
        'DDA0DD', # plum
        'B8860B', # DarkGoldenrod
        '856363', # green cooper
);

# Function: range
#
#    Return a range of colours in RGB format.
#
#    The number of colours is limited. So if you asked for more
#    colours, a loop will be done and reuse the same colours again
#
# Parameters:
#
#    n - Int the number of colours
#
# Returns:
#
#    Array ref - the colours in the range, its number will 'n'
#
sub range
{
    my ($n) = @_;

    my @c;
    while ($n > @colours) {
        push @c, @colours;
        $n  = $n - @colours;
    }

    push @c, @colours[0 .. ($n -1)];

    return \@c;
}

1;
