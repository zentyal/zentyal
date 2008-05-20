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

package EBox::Samba::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;



sub classesToProcess
{
    return [
	    'sambaSamAccount',
	   ];
}


sub processSambaSamAccount
{
    my ($package, $entry) = @_;

    my $samba = EBox::Global->modInstance('samba');
    if (not defined $samba) {
	print "Samba module not available. Ignoring samba data";
	return;
    }

    my $sambaUser = $samba->_ldapModImplementation();

    my $username = $entry->get_value('cn');

    my $flags = $entry->get_value('sambaAcctFlags');
    my $sharing = not ($flags =~ /D/) ? 'yes' : 'no';
    
    $sambaUser->setUserSharing($username, $sharing);

}



1;
