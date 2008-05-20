# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Jabber::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;

use EBox::Global;
use EBox::JabberLdapUser;


sub classesToProcess
{
    return [
	    { class => 'userJabberAccount',           priority => 10 },

	   ];
}


sub processUserJabberAccount
{
    my ($package, $entry) = @_;

    my $ldapUser = EBox::JabberLdapUser->new();

    my $username = $entry->get_value('cn');

    my $jabberUid = $entry->get_value('jabberUid');
    my $jabberAdmin = $entry->get_value('jabberAdmin');

    print "jabberUid $jabberUid jabberAdmin $jabberAdmin\n\n";

    my $enableAccount = 0;
    if (($jabberAdmin eq 'TRUE') or ($jabberAdmin eq 'FALSE')) {
	$enableAccount = 1;
    }

    print "enableAccount $enableAccount\n";

    $ldapUser->setHasAccount($username, $enableAccount);
    if ($jabberAdmin eq 'TRUE') {
	$ldapUser->setIsAdmin($username, 1);
    }


}


1;
