# Copyright (C) 2009 EBox Technologies S.L.
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


package EBox::Squid::LdapUserImplementation;
use base 'EBox::LdapUserBase';

use EBox::Global;


sub _delGroup
{
    my ($self, $group) = @_;
    my $squid = EBox::Global->modInstance('squid');

    my $policyModel = $squid->model('GlobalGroupPolicy');
    $policyModel->delPoliciesForGroup($group);

    my $objectPolicy = $squid->model('ObjectPolicy');
    $objectPolicy->delPoliciesForGroup($group);
}


sub _delGroupWarning
{
    my ($self, $group) = @_;
    my $squid = EBox::Global->modInstance('squid');

    my $policyModel = $squid->model('GlobalGroupPolicy');
    if ($policyModel->existsPoliciesForGroup($group)) {
        return ( q{HTTP proxy's group policies }  )
    }

    my $objectPolicy = $squid->model('ObjectPolicy');
    if ($objectPolicy->existsPoliciesForGroup($group)) {
        return ( q{HTTP proxy's object group policies }  )
    }
    return ();
}



1;
