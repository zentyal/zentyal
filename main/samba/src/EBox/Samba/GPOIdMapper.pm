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

use strict;
use warnings;

package EBox::Samba::GPOIdMapper;

# Package: EBox::Samba::GPOIdMapper
#
#    GPO identifier mapper from DN to a valid HTML identifier and vice
#    versa.

# Function: dnToId
#
#    DN to HTML identifier
#
# Parameters:
#
#    dn - String the distinguished name
#
# Returns:
#
#    String - a valid HTML identifier translated from dn parameter
#
sub dnToId
{
    my ($dn) = @_;

    my $id = $dn;
    $id =~ s/=/equals/g;
    $id =~ s/,/comma/g;
    $id =~ s/{/obracket/g;
    $id =~ s/}/cbracket/g;
    return $id;
}

# Function: idToDn
#
#    HTML identifier to a valid Distinguished Name
#
#    This is the opposite function to <dnToId>.
#
#    > idToDn(dnToId($dn)) eq $dn => 1
#
# Parameters:
#
#    id - String the HTML identifier as a returned value of <dnToId>
#
# Returns:
#
#    String - a valid Distinguished Name
#
sub idToDn
{
    my ($id) = @_;

    my $dn = $id;
    $dn =~ s/equals/=/g;
    $dn =~ s/comma/,/g;
    $dn =~ s/obracket/{/g;
    $dn =~ s/cbracket/}/g;
    return $dn;
}

1;
