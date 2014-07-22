# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::Samba::Computer
#
#   Samba computer, stored in samba LDAP
#

package EBox::Samba::Computer;

use base 'EBox::Samba::LdapObject';

sub name
{
    my ($self) = @_;
    return $self->get('name');
}

# Method: addSpn
#
#   Add a service principal name to this account
#
sub addSpn
{
    my ($self, $spn, $lazy) = @_;

    my @spns = $self->get('servicePrincipalName');

    # return if spn already present
    foreach my $s (@spns) {
        return if (lc ($s) eq lc ($spn));
    }
    push (@spns, $spn);

    $self->set('servicePrincipalName', \@spns, $lazy);
}


1;
