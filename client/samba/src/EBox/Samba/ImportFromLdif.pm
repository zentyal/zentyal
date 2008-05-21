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

use EBox::Sudo;
use EBox::Ldap;

sub classesToProcess
{
    return [
	    'sambaSamAccount',
	   ];
}


sub processSambaSamAccount
{
    my ($package, $entry, @params) = @_;

    my $username = $entry->get_value('cn');

    if ($username =~ m{\$$}) {
	$package->_processComputerAccount($entry, @params);
    }
    else {
	$package->_processUserAccount($entry, @params);
    }

}

sub _processUserAccount
{
    my ($package, $entry) = @_;

    my $username = $entry->get_value('cn');

    my $flags = $entry->get_value('sambaAcctFlags');
    my $sharing = not ($flags =~ /D/) ? 'yes' : 'no';
    
    my $samba = EBox::Global->modInstance('samba');
    my $sambaUser = $samba->_ldapModImplementation();

    $sambaUser->setUserSharing($username, $sharing);
}



sub _processComputerAccount
{
    my ($package, $entry, %options) = @_;

    my $account = $entry->get_value('cn');

    if ($package->_existsComputerAccount($account)) {
	if (not $options{overwrite}) {
	    print "Computer Account $account already exists. Skipping it\n";
	    return;
	}

	print "Overwriting computer account $account\n";
	$package->_delComputerAccount($account);
    }

    $package->_addComputerAccount($account);
}



sub _addComputerAccount
{
    my ($package, $account) = @_;

    my $accountAddCmd = "/usr/sbin/smbldap-useradd -w $account";
    EBox::Sudo::root($accountAddCmd);
	
}


sub _delComputerAccount
{
    my ($package, $account) = @_;

    my $accountDelCmd = "/usr/sbin/smbldap-userdel  $account";
    EBox::Sudo::root($accountDelCmd);
}	


sub _existsComputerAccount
{
    my ($package, $account) = @_;

    my $computersDn = 'ou=Computers,' . EBox::Ldap->dn();

    my %attrs = (
		 base => $computersDn,
		 filter => "&(objectclass=*)(uid=$account)",
		 scope => 'one'
		);

    my $ldap   = EBox::Ldap->instance();
    my $result = $ldap->search(\%attrs);
    
    return ($result->count > 0);
}


1;

