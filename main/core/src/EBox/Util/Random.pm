# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::Util::Random;

use strict;
use warnings;

use EBox::Exceptions::Internal;

# Function: generate
#
#   Generate a random string with the given length
#
# Parameters:
#
#   len - Desired pasword length
#
# Returns:
#
#   String with a generated random password
#
sub generate {
    my ($len) = @_;
    my $char;
    my $data;
    my @chars;

    $len = int($len);
    if ($len <= 0) {
        throw EBox::Exceptions::Internal('Wrong length argument');
    }

    @chars = split(//, "abcdefghijklmnopqrstuvwxyz"
            . "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@/");

    open(RD, "</dev/urandom") or die "Failed to open random source";
    $data = "";
    while ($len-- > 0) {
        read(RD, $char, 1) == 1 or die "Failed to read random data";
        $data .= $chars[ord($char) % @chars];
    }
    close(RD);
    return $data;
}

1;
