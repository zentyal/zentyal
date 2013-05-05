# Copyright (C) 2011-2013 Zentyal S.L.
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
#

use strict;
use warnings;

package EBox::Util::Debconf;

use Debconf::Db;
use Debconf::Question;

# Method: value
#
#   Gets the value of the first debconf key that matches the given name
#
# Parameters:
#
#   name - name of the key
#
# Returns
#
#   string with the value of the key or undef if key not found
#
sub value
{
    my ($name) = @_;

    Debconf::Db->load(readonly => 1);

    my $it = Debconf::Question->iterator();
    while (my $key = $it->iterate()) {
        next unless ($key->name() eq $name);
        return $key->value();
    }

    return undef;
}

1;
