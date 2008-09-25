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

use EBox::Global;
use EBox::Sudo;
use EBox::Ldap;
use EBox::SambaLdapUser;

use constant DEFAULT_USERS_GROUP => 'Domain Users';


sub classesToProcess
{
    return [
            { class => 'sambaDomain', priority => -5 },
            { class => 'sambaSamAccount', priority => 10 },
            { class => 'sambaGroupMapping', priority => 15  },
           ];
}





sub _addDomainUsersAccount
{
    my ($package, %params) = @_;

    my $name = DEFAULT_USERS_GROUP;

    my $usersMod = EBox::Global->modInstance('users');
    $usersMod->groupExists($name) and 
        return;


    my $ldap = EBox::Ldap->instance();
    my $sambaLdap = EBox::SambaLdapUser->new();

    my %args = (
                attr => [
                         'cn'           => $name,
                         'gidNumber'    => 512,
                         'sambaSID'     =>  $sambaLdap->getSID(), 
                         'sambaGroupType'  => 2,
                         'displayName'  => $name, 
                         'objectclass'  => ['posixGroup',
                                            'sambaGroupMapping', 
                                            'eboxGroup']
                        ]
               );
    
    my $dn = "cn=$name,ou=Groups,dc=ebox";
    $ldap->add($dn, \%args);
}

sub processSambaDomain
{
    my ($package, $entry, %params)  = @_;

    my $domainName = $entry->get_value('sambaDomainName');
    my $sambaSID   = $entry->get_value('sambaSID');
    print "Overwriting old samba domain with domain $domainName\n";



    $package->_delAllComputerAccounts();

    my $samba = EBox::Global->modInstance('samba');
    $samba->setWorkgroup($domainName);
    $samba->setNetSID($sambaSID);

    print "Restarting samba module..\n";

 #   $samba->fixSIDs(); 
# fixSiDs restrts samba service so a call to _regenConfig call is not neccesary
    $samba->_regenConfig();

    $package->_addDomainUsersAccount();

}




sub processSambaGroupMapping
{
    my ($package, $entry, @params) = @_;

    my $group = $entry->get_value('cn');
    my $sid   = $entry->get_value('sambaSID');
    my $displayResource = $entry->get_value('displayResource');

    my $samba = EBox::Global->modInstance('samba');
    my $sambaUser = $samba->_ldapModImplementation();


    if ($group eq DEFAULT_USERS_GROUP) {
        $sambaUser->setGroupSID($group, $sid, isGroup => 1);
    }


    $sambaUser->addGroupLdapAttrs($group, SID => $sid);

    if (defined $displayResource) {
        $sambaUser->setSharingName($group, $displayResource);
    }
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
 
    my $samba = EBox::Global->modInstance('samba');
    my $sambaUser = $samba->_ldapModImplementation();

    my $sambaSID = $entry->get_value('sambaSID');
    $sambaUser->setUserSID($username, $sambaSID);

    my $flags = $entry->get_value('sambaAcctFlags');
    my $sharing = not ($flags =~ /D/) ? 'yes' : 'no';
    $sambaUser->setUserSharing($username, $sharing);
}



sub _processComputerAccount
{
    my ($package, $entry, %options) = @_;

    # we can always add computers account bz we have remove all the old accounts
    # when proccessing sambaSamDomian
    my $account = $entry->get_value('cn');
    my $sambaSID = $entry->get_value('sambaSID');
    $package->_addComputerAccount($account, $sambaSID);
}



# TODO we can move all computer account utility method to its own class but for
# now it is not neccessary

sub _addComputerAccount
{
    my ($package, $account, $sid) = @_;

    my $accountAddCmd = "/usr/sbin/smbldap-useradd -w $account";
    EBox::Sudo::root($accountAddCmd);
}


sub _computerAccountDn
{
    my ($package, $account) = @_;
    return "uid=$account,ou=Computers,dc=ebox";
}


sub _delComputerAccount
{
    my ($package, $account) = @_;

    my $accountDelCmd = "/usr/sbin/smbldap-userdel  $account";
    EBox::Sudo::root($accountDelCmd);
}       



sub _delAllComputerAccounts
{
    my ($package) = @_;

    my @accounts = @{  $package->_allComputerAccounts() };
    foreach my $account (@accounts) {
        $package->_delComputerAccount($account);
    }
}


sub _allComputerAccounts
{
    my ($package) = @_;

    my $dn = $package->_computersDn();
    my %attrs = (
                 base => $dn,
                 filter => "cn=*",
                 scope => 'sub',
                 attrs => ['cn'],
                );

    my $ldap   = EBox::Ldap->instance();
    my $result = $ldap->search(\%attrs);

    my @accounts = map {
        $_->get_value('cn');
    } $result->entries();

    return \@accounts;
}


sub _existsComputerAccount
{
    my ($package, $account) = @_;

    my $dn = $package->_computersDn();
    my %attrs = (
                 base => $dn,
                 filter => "&(objectclass=sambaSamAccount)(uid=$account)",
                 scope => 'one'
                );

    my $ldap   = EBox::Ldap->instance();
    my $result = $ldap->search(\%attrs);
    
    return ($result->count > 0);
}

sub _computersDn
{
    my $computersDn = 'ou=Computers,' . EBox::Ldap->dn();
    return $computersDn;
}


1;

