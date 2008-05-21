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

package EBox::UsersAndGroups::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;

use MIME::Base64;


sub classesToProcess
{
    return [
	    {class => 'posixAccount', priority => -1 },
	    {class => 'posixGroup',   priority => 0 },
	   ];
}



sub processPosixAccount
{
    my ($package, $entry, %options) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    defined $usersMod or die 'Cannot instantiate users and groups module';
    
    my $name = $entry->get_value('cn');
    if ($name =~ m{\$$}) {
	# windows domain machine name, don't process here
	return;
    }

    if ( $usersMod->userExists($name) ) {
	if (not $options{overwrite}) {
	    print "User $name already exists. Skipping\n";
	    return;
	}

	print "Overwritting user $name\n";
	$usersMod->delUser($name)
    } 

    my $uidNumber = $entry->get_value('uidNumber');
    my $passwd = $entry->get_value('userPassword');

    my $fullName = $entry->get_value('sn');
    my $commentary = $entry->get_value('description');

    # the system parameter is useless for us bz it is only used to clacualte the
    # uid of new users and we already have it. However we use it for
    # completeness
    my $system = ($uidNumber < $usersMod->minUid); # if the uid is lesser or equal
                                                # than the last uid of system
                                                # user, we have a system user


    my $user = {
		user => $name,
		fullname => $fullName,
		password => $passwd, 
		commentary => $commentary,
	       };

    $usersMod->addUser($user, $system, uidNumber => $uidNumber);
}



sub processPosixGroup
{
    my ($package, $entry, %options) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    defined $usersMod or die 'Cannot instantiate users and groups module';

    my $group = $entry->get_value('cn');

    if ( $usersMod->groupExists($group) ) {
	if (not $options{overwrite}) {
	    print "Group $group already exists. Skipping it\n";
	    return;
	}

	print "Overwriting group $group\n";
	$usersMod->delGroup($group);
    }  
	

    my $gidNumber = $entry->get_value('gidNumber');
    my $comment = $entry->get_value('description');
    my @members = $entry->get_value('memberUid');

    my $system = ($gidNumber < $usersMod->minGid); # if the gid is lesser or equal
                                                # than the last gid of system
                                                 # user, we have a system user 

    $usersMod->addGroup($group, $comment, $system, gidNumber => $gidNumber);

    foreach my $user (@members) {
	$usersMod->addUserToGroup($user, $group);
    }
}




1;
