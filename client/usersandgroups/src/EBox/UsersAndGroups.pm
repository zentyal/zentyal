# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::UsersAndGroups;

use strict;
use warnings;

use base qw(EBox::Module EBox::LdapModule);

use EBox::Global;
use EBox::Ldap;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo qw( :all );
use File::Slurp qw(read_file write_file);
use EBox::FileSystem;
use Error qw(:try);
use EBox::LdapUserImplementation;

use constant USERSDN	    => 'ou=Users';
use constant GROUPSDN       => 'ou=Groups';
use constant SYSMINUID	    => 1900;
use constant SYSMINGID	    => 1900;
use constant MINUID	    => 2000;
use constant MINGID	    => 2000;
use constant HOMEPATH       => '/nonexistent';
use constant MAXUSERLENGTH  => 24;
use constant MAXGROUPLENGTH => 24;
use constant MAXPWDLENGTH   => 15;
use constant DEFAULTGROUP   => '__USERS__';
 
sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'users',
					  domain => 'ebox-usersandgroups',
					  @_);

	$self->{ldap} = EBox::Ldap->instance();

	bless($self, $class);
	return $self;
}

# Method: _regenConfig
#
#       Overrides base method. It regenertates the ldap service configuration
#
sub _regenConfig 
{
	my $self = shift;
	
	my @array = ();

	push (@array, 'dn'      => $self->{ldap}->dn);
	push (@array, 'rootdn'  => $self->{ldap}->rootDn);
	push (@array, 'rootpw'  => $self->{ldap}->rootPw);
	push (@array, 'schemas' => $self->allLDAPIncludes);
	push (@array, 'acls'    => $self->allLDAPAcls);


	$self->writeConfFile($self->{ldap}->slapdConfFile, 
	 		     "/usersandgroups/slapd.conf.mas", \@array);
}

# Method: _rootCommands
#
#       Overrides base method. It regenertates the ldap service configuration
#
sub rootCommands 
{
	my $self = shift;
	my @cmds = ();
	my $ldapconf = $self->{ldap}->slapdConfFile;

	push(@cmds, $self->rootCommandsForWriteConfFile($ldapconf));
	push(@cmds, "/etc/init.d/slapd *");
	push @cmds, '/bin/tar';
	push @cmds, '/bin/chown * *';
	push @cmds, '/bin/mkdir -p  *';
	push @cmds, EBox::Sudo::rootCommandForStat('*');

	push @cmds, EBox::Ldap->rootCommands();

	return @cmds;
}

# Method: groupsDn 
#
#       Returns the dn where the groups are stored in the ldap directory
#
# Returns:
#
#       string - dn
#
sub groupsDn
{
	my $self = shift;
	return GROUPSDN . "," . $self->{ldap}->dn;
}

# Method: usersDn
#
#       Returns the dn where the users are stored in the ldap directory
#
# Returns:
#
#       string - dn
#
sub usersDn 
{
	my $self = shift;
	return USERSDN . "," . $self->{ldap}->dn;
}

# Method: userExists 
#
#      	Checks if a given user exists
#   
# Parameters:
#       
#       user - user name 
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub userExists # (user)
{
	my $self = shift;
	my $user = shift;

	my %attrs = (
			base => $self->usersDn,
			filter => "&(objectclass=*)(uid=$user)",
			scope => 'one'
		     );

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);
}


# Method: uidExists 
#
#      	Checks if a given uid exists
#   
# Parameters:
#       
#       uid - uid number to check
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub uidExists # (uid)
{
	my $self = shift;
	my $uid = shift;

	my %attrs = (
			base => $self->usersDn,
			filter => "&(objectclass=*)(memberUid=$uid)",
			scope => 'one'
		     );

	my $result = $self->{'ldap'}->search(\%attrs);
	
	return ($result->count > 0);
}

# Method: lastUid
#
#      	Returns the last uid used.
#   
# Parameters:
#       
#	system - boolan: if true, it returns the last uid for system users, 
#	otherwise the last uid for normal users
#
# Returns:
#
#       string - last uid
#
sub lastUid # (system)
{
	my $self = shift;
	my $system = shift;
	
	my %args = (
			base => $self->usersDn,
			filter => '(objectclass=posixAccount)',
			scope => 'one', 
			attrs => ['uidNumber']
		   );

	my $result = $self->{ldap}->search(\%args);

	my @users = $result->sorted('uidNumber');

	my $uid = -1;
	foreach my $user (@users) {
		my $curruid = $user->get_value('uidNumber');
		if ($system) {
			last if ($curruid > MINUID);
		} else {
			next if ($curruid < MINUID);
		}
		if ( $curruid > $uid){
			$uid = $curruid;
		}
	}

	if ($system) {
		return ($uid < SYSMINUID ?  SYSMINUID : $uid);
	} else {
		return ($uid < MINUID ?  MINUID : $uid);
	}
}

sub _initUser 
{
	my $self = shift;
	my $user = shift;

	# Tell modules depending on users and groups
	# a new new user is created
	my @mods = @{$self->_modsLdapUserBase()};
	
	foreach my $mod (@mods){
		$mod->_addUser($user);
	}
}


# Method: addUser 
#
#      	Adds a user
#   
# Parameters:
#       
#	user - hash ref containing: 'user' (user name), 'fullname', 'password',
#	and comment
#	system - boolan: if true it adds the user as system user, otherwise as 
#	normal user
sub addUser # (user, system)
{
	my $self = shift;
	my $user = shift;
	my $system = shift;

	if (length($user->{'user'}) > MAXUSERLENGTH) {
		throw EBox::Exceptions::External(
			__("Username must not be longer than " . MAXUSERLENGTH .
			   "characters"));
	}
	unless (_checkName($user->{'user'})) {
		throw EBox::Exceptions::InvalidData(
					'data' => __('user name'),
					'value' => $user->{'user'});
	}

	 # Verify user exists
	if ($self->userExists($user->{'user'})) {
		throw EBox::Exceptions::DataExists('data' => __('user name'),
						   'value' => $user->{'user'});
	}

	my $uid;
	if ($system) {
		$uid = $self->lastUid(1) + 1;
		if ($uid == MINUID) {
			thrown EBox::Exceptions::Internal(
				__('Maximum number of system users reached'));
		}
	} else {
		$uid = $self->lastUid + 1;
	}
	
	my $gid = $self->groupGid(DEFAULTGROUP);
	
	$self->_checkPwdLength($user->{'password'});
	my %args = ( 
		    attr => [
			     'cn'	     => $user->{'user'},
			     'uid'	     => $user->{'user'},
			     'sn'	     => $user->{'fullname'},
			     'uidNumber'     => $uid,
			     'gidNumber'     => $gid,
			     'homeDirectory' => HOMEPATH ,
			     'userPassword'  => $user->{'password'},
			     'objectclass'   => ['inetOrgPerson','posixAccount']
			      ]
		   );

	my $dn = "uid=" . $user->{'user'} . "," . $self->usersDn;	
	my $r = $self->{'ldap'}->add($dn, \%args);
	

	$self->_changeAttribute($dn, 'description', $user->{'comment'});
	unless ($system) {
		$self->_initUser($user->{'user'});
	}
}

sub _modifyUserPwd($$$) 
{
	my $self = shift;
	my $user = shift;
	my $pwd  = shift;

	$self->_checkPwdLength($pwd);
	my $dn = "uid=" . $user . "," . $self->usersDn;	
	my $r = $self->{'ldap'}->modify($dn, { 
				replace => { 'userPassword' => $pwd }});
	
}

sub _updateUser($$) 
{
	my $self = shift;
	my $user = shift;
	
	# Tell modules depending on users and groups
	# a user  has been updated
	my @mods = @{$self->_modsLdapUserBase()};
	
	foreach my $mod (@mods){
		$mod->_modifyUser($user);
	}
}

# Method: modifyUser 
#
#      	Modifies a user
#   
# Parameters:
#       
#	user - hash ref containing: 'user' (user name), 'fullname', 'password',
#	and comment
#
sub modifyUser # (\%user)
{
	my $self =  shift;
	my $user =  shift;

	my $cn = $user->{'username'};
	my $dn = "uid=$cn," . $self->usersDn;
   	# Verify user  exists
	unless ($self->userExists($user->{'username'})) {
		throw EBox::Exceptions::DataNotFound('data'  => __('user name'),
						     'value' => $cn);
	}

	foreach my $field (keys %{$user}) {
		if ($field eq 'comment') {
			$self->_changeAttribute($dn, 'description', 
						$user->{'comment'});
		} elsif ($field eq 'fullname') {
			$self->_changeAttribute($dn, 'sn', $user->{'fullname'});
		} elsif ($field eq 'password') {
			$self->_modifyUserPwd($user->{'username'}, 
						$user->{'password'});
		}
	}
	
	$self->_updateUser($cn);
}

# Clean user stuff when deleting a user
sub _cleanUser($$) 
{
	my $self = shift;
	my $user = shift;

	my @mods = @{$self->_modsLdapUserBase()};
	
	# Tell modules depending on users and groups
	# an user is to be deleted 
	foreach my $mod (@mods){
		$mod->_delUser($user);
	}
	
	# Delete user from groups
	foreach my $group (@{$self->groupOfUsers($user)}) {
		$self->delUserFromGroup($user, $group);		
	}
}

# Method: delUser
#
#      	Removes a given user
#   
# Parameters:
#       
#	user - user name to be deleted 
#
sub delUser # (user)
{
	my $self = shift;
	my $user = shift;

	# Verify user exists
	unless ($self->userExists($user)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $user);
	}

	$self->_cleanUser($user);	
	my $r = $self->{'ldap'}->delete("uid=" . $user . "," . $self->usersDn);
	
}

# Method: userInfo 
#
#      	Returns a hash ref containing the inforamtion for a given user
#   
# Parameters:
#       
#	user - user name to gather information
#	entry - *optional* ldap entry for the user
#
# Returns:
#
#	hash ref - holding the keys: 'username', 'fullname', password', 
#	'homeDirectory', 'uid' and 'group'
#
sub userInfo # (user, entry)
{
	my $self = shift;
	my $user = shift;
	my $entry = shift;

	# Verify user  exists
	unless ($self->userExists($user)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $user);
	}
	
	# If $entry is undef we make a search to get the object, otherwise
	# we already have the entry
	unless ($entry) {
		my %args = (
			   base => $self->usersDn,
			   filter => "&(objectclass=*)(uid=$user)",
			   scope => 'one',
			   attrs => ['cn', 'description', 'userPassword', 'sn', 
				     'homeDirectory', 'uidNumber', 'gidNumber']
		   );

		my $result = $self->{ldap}->search(\%args);
		$entry = $result->entry(0);	
	}
	
	# Mandatory data
	my $userinfo = {
			username => $entry->get_value('cn'),
			fullname => $entry->get_value('sn'),
			password => $entry->get_value('userPassword'),
			homeDirectory => $entry->get_value('homeDirectory'),
			uid => $entry->get_value('uidNumber'),
			group => $entry->get_value('gidNumber'),
			};
     
	# Optional Data
	my $desc = $entry->get_value('description');
	if ($desc) {
		$userinfo->{'comment'} = $desc;
	} else {
		$userinfo->{'comment'} = ""; 
	}

	return $userinfo;

}

# Method: users
#
#      	Returns an array containing all the users (not system users)
#
# Returns:
#
#	array - holding the users
#
sub users 
{
	my $self = shift;
	
	my %args = (
			base => $self->usersDn,
			filter => 'objectclass=*',
			scope => 'one',
			attrs => ['uid', 'cn', 'sn', 'homeDirectory',  
				  'userPassword', 'uidNumber', 'gidNumber', 
				  'description']
		   );

	my $result = $self->{ldap}->search(\%args);
	
	my @users = ();
	foreach my $user ($result->sorted('uid'))
	{
		next if ($user->get_value('uidNumber') < MINUID);
		@users = (@users,  $self->userInfo($user->get_value('uid'),
						       $user))		
	}

	return @users;
}

# Method: groupExists
#
#      	Checks if a given group name exists
#   
# Parameters:
#       
#       group - group name
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub groupExists # (group) 
{
	my $self = shift;
	my $group = shift;

	my %attrs = (
		   	base => $self->groupsDn,
			filter => "&(objectclass=*)(cn=$group)",
			scope => 'one'
		     );

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);
}

# Method: gidExists
#
#      	Checks if a given gid number exists
#   
# Parameters:
#       
#       gid - gid number
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub gidExists($$) 
{
	my $self = shift;
	my $gid = shift;

	my %attrs = (
		   	base => $self->groupsDn,
			filter => "&(objectclass=*)(gidNumber=$gid)",
			scope => 'one'
		     );

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);
}

# Method: lastGid
#
#      	Returns the last gid used.
#   
# Parameters:
#       
#	system - boolan: if true, it returns the last gid for system users, 
#	otherwise the last gid for normal users
#
# Returns:
#
#       string - last gid
#
sub lastGid # (gid) 
{
	my $self = shift;
	my $system = shift;
	
	my %args = (
			base => $self->groupsDn,
			filter => '(objectclass=posixGroup)',
			scope => 'one', 
			attrs => ['gidNumber']
		   );

	my $result = $self->{ldap}->search(\%args);

	my @users = $result->sorted('gidNumber');

	my $gid = -1;
	foreach my $user (@users) {
		my $currgid = $user->get_value('gidNumber');
		if ($system) {
			last if ($currgid > MINGID);
		} else {
			next if ($currgid < MINGID);
		}

		if ( $currgid > $gid){
			$gid = $currgid;
		}
	}

	if ($system) {
		return ($gid < SYSMINUID ?  SYSMINUID : $gid);
	} else {
		return ($gid < MINUID ?  MINUID : $gid);
	}

}

# Method: addGroup
#
#      	Adds a new group
#   
# Parameters:
#       
#	group - group name
#	comment - comment's group
#	system - boolan: if true it adds the group as system group, 
#	otherwise as normal group
#
sub addGroup # (group, comment, system)
{
	my $self = shift;
	
	my $group = shift;
	my $comment = shift;
	my $system = shift;

	if (length($group) > MAXGROUPLENGTH) {
		throw EBox::Exceptions::External(
			__("Groupname must not be longer than ".MAXGROUPLENGTH .
			   "characters"));
	}
	
	if (($group eq DEFAULTGROUP) and (not $system)) {
		throw EBox::Exceptions::External(
			__('The group name is not valid because it is used' .
			   ' internally'));
	}
	
	unless (_checkName($group)) {
		throw EBox::Exceptions::InvalidData(
				'data' => __('group name'),
				'value' => $group);
	}
 	# Verify group exists
	if ($self->groupExists($group)) {
		throw EBox::Exceptions::DataExists('data' => __('group name'),
						   'value' => $group);
	}
	#FIXME
	my $gid;
	if ($system) {
		$gid = $self->lastGid(1) + 1;
		if ($gid == MINGID) {
			thrown EBox::Exceptions::Internal(
				__('Maximum number of system users reached'));
		}
	} else {
		$gid = $self->lastGid + 1;
	}

	my %args = ( 
		    attr => [
			      'cn'	  => $group,
			      'gidNumber'   => $gid,
			      'objectclass' => ['posixGroup']
			    ]
		    );

	my $dn = "cn=" . $group ."," . $self->groupsDn;
	my $r = $self->{'ldap'}->add($dn, \%args); 
	
	
	$self->_changeAttribute($dn, 'description', $comment);

	unless ($system) {
		my @mods = @{$self->_modsLdapUserBase()};
		foreach my $mod (@mods){
			$mod->_addGroup($group);
		}
	}
}

sub _updateGroup($$) 
{
	my $self = shift;
	my $group = shift;
	
	# Tell modules depending on groups and groups
	# a group  has been updated
	my @mods = @{$self->_modsLdapUserBase()};
	
	foreach my $mod (@mods){
		$mod->_modifyGroup($group);
	}
}

# Method: modifyGroup
#
#      	Modifies a group
#   
# Parameters:
#       
#	hash ref - holding the keys 'groupname' and 'comment'. At the moment
#	comment is the only modifiable attribute
#
sub modifyGroup # (\%groupdata)) 
{
	my $self =  shift;
	my $groupdata =  shift;

	my $cn = $groupdata->{'groupname'};
	my $dn = "cn=$cn," . $self->groupsDn;
   	# Verify group  exists
	unless ($self->groupExists($cn)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('user name'),
						     'value' => $cn);
	}

	$self->_changeAttribute($dn, 'description', $groupdata->{'comment'});
}

# Clean group stuff when deleting a user
sub _cleanGroup($$) 
{
	my $self = shift;
	my $group= shift;

	my @mods = @{$self->_modsLdapUserBase()};
	
	# Tell modules depending on users and groups
	# a group is to be deleted 
	foreach my $mod (@mods){
		$mod->_delGroup($group);
	}
}

# Method: delGroup
#
#      	Removes a given group
#   
# Parameters:
#       
#	group - group name to be deleted 
#
sub delGroup # (group)
{
	my $self = shift;
	my $group = shift;

	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFoud('data' => __('group name'),
						    'value' => $group);
	}
	
	$self->_cleanGroup($group);
	my $dn = "cn=" . $group . "," . $self->groupsDn;
	my $result = $self->{'ldap'}->delete($dn);

}

# Method: groupInfo 
#
#      	Returns a hash ref containing the inforamtion for a given group
#   
# Parameters:
#       
#	group - group name to gather information
#	entry - *optional* ldap entry for the group
#
# Returns:
#
#	hash ref - holding the keys: 'groupname' and 'description'
sub groupInfo # (group) 
{
	my $self = shift;
	my $group = shift;

	# Verify user don't exists
	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $group);
	}

	my %args = (
			base => $self->groupsDn,
			filter => "&(objectclass=*)(cn=$group)",
			scope => 'one',
			attrs => ['cn', 'description']
		   );

	my $result = $self->{ldap}->search(\%args);

	my $entry = $result->entry(0);
	# Mandatory data
	my $groupinfo = {
			 groupname => $entry->get_value('cn'),
			};
	
	
	my $desc = $entry->get_value('description');
	if ($desc) {
		$groupinfo->{'comment'} = $desc;
	} else {
		$groupinfo->{'comment'} = ""; 
	}

	return $groupinfo;

}

# Method: groups
#
#      	Returns an array containing all the groups (not system groupss)
#
# Returns:
#
#	array - holding the groups
#
sub groups 
{
	my $self = shift;
	
	my %args = (
		      base => $self->groupsDn,
		      filter => '(objectclass=*)',
		      scope => 'one', 
		      attrs => ['cn', 'gidNumber', 'description']
		   );

	my $result = $self->{ldap}->search(\%args);

	my @groups = ();
	foreach ($result->sorted('cn'))
	{
		next if ($_->get_value('gidNumber') < MINGID);

		my $info = {
				'account' => $_->get_value('cn'),
				'gid' => $_->get_value('gidNumber'),
			    };

		my $desc = $_->get_value('description');
		if ($desc) {
			$info->{'desc'} = $desc;
		}

		@groups = (@groups, $info);
	}

	return @groups;
}

# Method: addUserToGroup 
#
#	Adds a user to a given group
#   
# Parameters:
#       
#	user - user name to add to the group
#	group - group name 
#
# Exceptions:
#
#	DataNorFound - If user or group don't exist
sub addUserToGroup # (user, group)
{
	my $self = shift;

	my $user = shift;
	my $group = shift;

	unless ($self->userExists($user)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $user);
	}

	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFound('data' => __('group name'),
						     'value' => $group);
	}

	my $dn = "cn=" . $group . "," . $self->groupsDn;

	my %attrs = ( add => { memberUid => $user } );
 	$self->{'ldap'}->modify($dn, \%attrs);

	$self->_updateGroup($group);
}

# Method: delUserFromGroup 
#
#	Removes a user from a group
#   
# Parameters:
#       
#	user - user name to remove  from the group
#	group - group name 
#
# Exceptions:
#
#	DataNorFound - If user or group don't exist
sub delUserFromGroup # (user, group)
{
	my $self = shift;

	my $user = shift;
	my $group = shift;

	unless ($self->userExists($user)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $user);
	}

	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFoud('data' => __('group name'),
						    'value' => $group);
	}

	my $dn = "cn=" . $group . "," . $self->groupsDn;
	my %attrs = ( delete => {  memberUid => $user  } );
	$self->{'ldap'}->modify($dn, \%attrs);

	$self->_updateGroup($group);
}

# Method: groupOfUsers 
#
#	Given a user it returns all the groups which the user belongs to
#   
# Parameters:
#       
#	user - user name 
#
# Returns:
#
#	array ref - holding the groups
#
# Exceptions:
#
#	DataNorFound - If user does not  exist
sub groupOfUsers # (user)
{
	my $self = shift;
	my $user = shift;

	unless ($self->userExists($user)) {
		throw EBox::Exceptions::DataNotFound('data' => __('user name'),
						     'value' => $user);
	}

	my %attrs = (
		       base => $self->groupsDn,
		       filter => "&(objectclass=*)(memberUid=$user)",
		       scope => 'one',
		       attrs => ['cn']
		    );
	
	my $result = $self->{'ldap'}->search(\%attrs);

	my @groups;
	foreach my $entry ($result->entries){
		push @groups, $entry->get_value('cn');
	}
	
	return \@groups;
}

# Method: usersInGroup 
#
#	Given a group it returns all the users belonging to it
#   
# Parameters:
#       
#	group - group name
#
# Returns:
#
#	array ref - holding the groups
#
# Exceptions:
#
#	DataNorFound - If group does not  exist
sub  usersInGroup # (group) 
{
	my $self = shift;
	my $group= shift;

	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFound('data' => __('group name'),
						     'value' => $group);
	}

	my %attrs = (
		       base => $self->groupsDn,
		       filter => "&(objectclass=*)(cn=$group)",
		       scope => 'one',
		       attrs => ['memberUid']
		    );
	
	my $result = $self->{'ldap'}->search(\%attrs);

	my @users;
	foreach my $res ($result->sorted('memberUid')){
		push @users, $res->get_value('memberUid');
	}
	
	return \@users;

}

# Method: usersNotInGroup 
#
#	Given a group it returns all the users who not belonging to it
#   
# Parameters:
#       
#	group - group name
#
# Returns:
#
#	array  - holding the groups
#
sub usersNotInGroup # (group)
{
	my $self  = shift;
	my $groupname = shift;
	
	my $grpusers = $self->usersInGroup($groupname);
	my @allusers = $self->users();

	my @users;
	foreach my $user (@allusers){
		my $uid = $user->{username};
		unless (grep (/^$uid$/, @{$grpusers})){
			push @users, $uid;
		}
	}

	return @users;
}


# Method: gidGroup 
#
#	Given a gid number it returns its group name
#   
# Parameters:
#       
#	gid - gid number
#
# Returns:
#
#	string - group name
#
sub gidGroup # (gid)
{
	my $self = shift;
	my $gid  = shift;

	my %attrs = (
		   	base => $self->groupsDn,
			filter => "&(objectclass=*)(gidNumber=$gid)",
			scope => 'one',
			attr => ['cn']
		     );

	my $result = $self->{'ldap'}->search(\%attrs);
	
	if ($result->count == 0){
		  throw EBox::Exceptions::DataNotFound(
			'data' => "Gid", 'value' => $gid);
	}	

	return $result->entry(0)->get_value('cn');
}	

# Method: groupGid 
#
#	Given a group name  it returns its gid number
#   
# Parameters:
#       
#	group - group name 
#
# Returns:
#
#	string - gid number
#
sub groupGid # (group)
{
	my $self = shift;
	my $group  = shift;

	unless ($self->groupExists($group)) {
		throw EBox::Exceptions::DataNotFound('data' => __('group name'),
						     'value' => $group);
	}

	my %attrs = (
		   	base => $self->groupsDn,
			filter => "&(objectclass=*)(cn=$group)",
			scope => 'one',
			attr => ['cn']
		     );

	my $result = $self->{'ldap'}->search(\%attrs);
	
	return $result->entry(0)->get_value('gidNumber');
}

sub _groupIsEmpty($$) 
{
	my $self = shift;
	my $group = shift;
	
	my @users = @{$self->usersInGroup($group)};

	return @users ? undef : 1;
}

sub _changeAttribute 
{
	my $self = shift;
	my $dn   = shift;
	my $attr = shift;
	my $value = shift;

	unless ($value and length($value) > 0){
		$value = undef;
	}
	my %args = (
		      base => $dn,
		      filter => 'objectclass=*',
		      scope =>  'base'
		   );

	my $result = $self->{ldap}->search(\%args);

	my $entry = $result->pop_entry();
	my $oldvalue = $entry->get_value($attr);

	# There is no value 
	return if ( (not $value) and (not $oldvalue));  
	# There is no change
	return if (($oldvalue and $value) and $oldvalue eq $value); 
	
	if (($oldvalue and $value) and $value ne $oldvalue) {
		$entry->replace($attr => $value);
	} elsif ((not $value) and $oldvalue) {
		$entry->delete($attr);
	} elsif (($value) and (not $oldvalue)) {
		$entry->add($attr => $value);
	}
	
	$entry->update($self->{ldap}->ldapCon);
	
}



sub _checkPwdLength($$) 
{
	my $self = shift;
	my $pwd  = shift;
	
	if (length($pwd) > MAXPWDLENGTH) {
		throw EBox::Exceptions::External(
			__("Password must not be longer than " . MAXPWDLENGTH .
			   "characters"));
	}
}


sub _checkName
{
	my $name = shift;
	($name =~ /[^A-Za-z0-9_\s]/) and return undef;
	return 1;
}

# Returns modules implementing LDAP user base interface
sub _modsLdapUserBase($) 
{
	my $self = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};
	
	my @modules;
	foreach my $name (@names) {
		my $mod = EBox::Global->modInstance($name);
		if ($mod->isa('EBox::LdapModule')) {
			push (@modules, $mod->_ldapModImplementation);
		}
	}
	
	return \@modules;
}

# Method: allUserAddOns
#
#       Returns all the mason components from those modules implementing
#	the function _userAddOns from EBox::LdapUserBase
#   
# Parameters:
#       
#       user - username
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allUserAddOns # (user)
{
	my $self = shift;
	my $username = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};
	
	my @modsFunc = @{$self->_modsLdapUserBase()};
	my @components;
	foreach my $mod (@modsFunc) {
		my $comp = $mod->_userAddOns($username);
		if ($comp) {
			push (@components, $comp);
		}
	}
	
	return \@components;
}

# Method: allGroupAddOns
#
#       Returns all the mason components from those modules implementing
#	the function _groupAddOns from EBox::LdapUserBase
#   
# Parameters:
#       
#       group  - group name
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allGroupAddOns($$) 
{
	my $self = shift;
	my $groupname = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};
	
	my @modsFunc = @{$self->_modsLdapUserBase()};
	my @components;
	foreach my $mod (@modsFunc) {
		my $comp = $mod->_groupAddOns($groupname);
	 	push (@components, $comp) if ($comp); 
	}
	
	return \@components;
}

# Method: allLDAPIncludes
#
#	Returns all the ldap schemas requested by those modules implementing
#	the function _includeLDAPSchemas from EBox::LdapUserBase
#   
# Returns:
#
#       array ref - holding all the schemas 
#
sub allLDAPIncludes 
{
	my $self = shift;
	
	my @modsFunc = @{$self->_modsLdapUserBase()};
	my @includes;
	foreach my $mod (@modsFunc) {
		foreach my $path (@{$mod->_includeLDAPSchemas}) {
			push (@includes,  $path) if ($path);
		}
	}

	#We removes duplicated elements
	my %temp = ();
	@includes = grep ++$temp{$_} < 2, @includes;

	return \@includes;
}

# Method: allLDAPAcls
#
#	Returns all the ldap acls requested by those modules implementing
#	the function _includeLDAPSchemas from EBox::LdapUserBase
#   
# Returns:
#
#       array ref - holding all the acls
#
sub allLDAPAcls 
{
	my $self = shift;

	my @modsFunc = @{$self->_modsLdapUserBase()};
	my @allAcls;
	foreach my $mod (@modsFunc) {
		foreach my $acl (@{$mod->_includeLDAPAcls}) {
			push (@allAcls,  $acl) if ($acl);
		}
	}

	return \@allAcls;
}

# Method: allWarning
#
#	Returns all the the warnings provided by the modules when a certain 
#	user or group is going to be deleted. Function _delUserWarning or
#	_delGroupWarning is called in all module implementing them.
#
# Parameters:
#
# 	object - Sort of object: 'user' or 'group'
# 	name - name of the user or group
#   
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings($$$) 
{
	my $self = shift;
	my $object = shift;
	my $name = shift;
	
	my @modsFunc = @{$self->_modsLdapUserBase()};
	my @allWarns;
	foreach my $mod (@modsFunc) {
		my $warn = undef;
		if ($object eq 'user') {
			$warn = $mod->_delUserWarning($name);
		} else {
			$warn = $mod->_delGroupWarning($name);
		}
		push (@allWarns, $warn) if ($warn);
	}

	return \@allWarns;
}

# Method: menu 
#
#       Overrides EBox::Module method.
#   
#
sub menu
{
        my ($self, $root) = @_;
        $root->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Users',
                                        'text' => __('Users')));
        $root->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Groups',
                                        'text' => __('Groups')));
}

# LdapModule implmentation 
sub _ldapModImplementation 
{
	my $self;
	
	return new EBox::LdapUserImplementation();
}





sub _dump_to_file
{
  my ($self, $dir) = @_;
  my $backupDir = $self->createBackupDir($dir);

  $self->{ldap}->dumpLdapData($backupDir);
}


sub _load_from_file
{
  my ($self, $dir) = @_;

  $self->{ldap}->loadLdapData($dir);
}




1;
