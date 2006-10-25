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

package EBox::SambaLdapUser;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Network;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;


use Crypt::SmbHash qw(nthash ntlmgen);

# LDAP schema
use constant SCHEMAS            => ('/etc/ldap/schema/samba.schema',
				    '/etc/ldap/schema/ebox.schema');
# Default values for samba user
use constant SMBLOGONTIME       => '0'; 
use constant SMBLOGOFFTIME      => '2147483647'; 
use constant SMBKICKOFFTIME     => '2147483647'; 
use constant SMBPWDCANCHANGE    => '0'; 
use constant SMBPWDMUSTCHANGE   => '2147483647'; 
use constant SMBHOMEDRIVE       => 'H:'; 
use constant SMBGROUP 		=> '513'; 
use constant SMBACCTFLAGS       => '[U]'; 
use constant GECOS              => 'Ebox file sharing user '; 
use constant USERGROUP          => 513;
# Home path for users and groups
use constant BASEPATH          => '/home/samba';
use constant USERSPATH 	       => BASEPATH . '/users';
use constant GROUPSPATH	       => BASEPATH . '/groups';
use constant PROFILESPATH      => BASEPATH . '/profiles';


BEGIN 
{
	use Exporter ();
        our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

        @ISA = qw(Exporter);
        @EXPORT = qw{ USERSPATH GROUPSPATH PROFILESPATH };
        %EXPORT_TAGS = ( DEFAULT => \@EXPORT );
        @EXPORT_OK = qw();
        $VERSION = EBox::Config::version;
	
}

use base qw(EBox::LdapUserBase);

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = EBox::Ldap->instance();
	bless($self, $class);
	return $self;
}


sub _smbHomes {
	my  $samba = EBox::Global->modInstance('samba');
	return "\\\\" . $samba->netbios() . "\\homes\\";
}

sub _smbProfiles {
	my  $samba = EBox::Global->modInstance('samba');
	return "\\\\" . $samba->netbios() . "\\profiles\\";
}

# Implements LdapUserBase interface
sub _addUser ($$)
{
	my $self = shift;
	my $user = shift;
	
	my $ldap = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	my $unixuid = $users->lastUid;
	my $rid = 2 * $unixuid + 1000;
	my $sambaSID = getSID() . '-' .  $rid;
	my $userinfo = $users->userInfo($user);
	my ($lm ,$nt) = ntlmgen $userinfo->{'password'};

	my $dn = "uid=$user," .  $users->usersDn;
	unless ($self->_isSambaObject('sambaSamAccount', $dn)) {
	   my %attrs = ( 
			changes => [ 
                    		add => [
                        	  objectClass          => 'sambaSamAccount',    
                        	  sambaLogonTime       => SMBLOGONTIME,
                           	  sambaLogoffTime      => SMBLOGOFFTIME,
                                  sambaKickoffTime     => SMBKICKOFFTIME,
                                  sambaPwdCanChange    => SMBPWDCANCHANGE,
                                  sambaPwdMustChange   => SMBPWDMUSTCHANGE,
                                  sambaHomePath        => _smbHomes() . $user,
                                  sambaHomeDrive       => SMBHOMEDRIVE,
                                  sambaProfilePath     => _smbProfiles . $user,
                                  sambaPrimaryGroupSID => 
				  		getSID() . '-' . SMBGROUP,
                        	  sambaLMPassword      => $lm,
                        	  sambaNTPassword      => $nt,
                        	  sambaAcctFlags       => SMBACCTFLAGS,
                        	  sambaSID             => $sambaSID
                         	  # gecos                => GECOS
                           	        ],
				 replace => [ homeDirectory =>  
				 	      BASEPATH . "/users/$user" 
					    ]
				       ]
		     );
	
	   my $add = $ldap->modify($dn, \%attrs ); 
	}	
	
	my  $samba = EBox::Global->modInstance('samba');
	$self->_createDir(USERSPATH . "/$user", $unixuid, USERGROUP, '0700');
	$self->_createDir(PROFILESPATH . "/$user", $unixuid, USERGROUP, '0700');
	$self->_setUserQuota($unixuid, $samba->defaultUserQuota);
}

sub _modifyUser($$) {
	my $self = shift;
	my $user   = shift;

	my $users = EBox::Global->modInstance('users');
	my $dn = "uid=$user," .  $users->usersDn;
	my $ldap = $self->{ldap};

	my %attrs = (
			base   => $dn,
			filter => "(objectclass=*)",
			attrs  => [ 'sambaNTPassword', 'sambaLMPassword', 
				    'userPassword' ],
			scope  => 'base'
		    );
	
	my $result = $ldap->search(\%attrs);
	
	my $entry = $result->pop_entry();
	# We are only interested in seeing if the pwd has changed
	if ($self->_pwdChanged($entry)) {
		my ($lm, $nt) = ntlmgen ($entry->get_value('userPassword'));
		$entry->replace( 'sambaNTPassword' => $nt , 
				 'sambaLMPassword' => $lm );
		$entry->update($ldap->ldapCon);
	}
}

sub _delUser($$){
	my $self = shift;
	my $user = shift;

	if ( -d BASEPATH . "/users/$user"){
 		root ("rm -rf \'" .  BASEPATH . "/users/$user\'");
	}
	if ( -d BASEPATH . "/profiles/$user"){
 		root ("rm -rf \'" .  BASEPATH . "/profiles/$user\'");
	}

	# Remove user from printers
	my $samba = EBox::Global->modInstance('samba');
	$samba->setPrintersForUser($user, []); 
}

sub _delUserWarning($$) {
	my $self = shift;
	my $user = shift;

	my $path = BASEPATH . "/users/$user";
	
	settextdomain('ebox-samba');
	my $txt = __('This user has a sharing directory associated ' .
	                           'which conatins data');
	settextdomain('ebox-usersandgroups');
	unless ($self->_directoryEmpty($path)) {
		return ($txt);
	}

	return undef;
}

sub _addGroup ($$)
{
	my $self  = shift;
	my $group = shift;
	 
	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	my $rid = 2 * $users->lastGid + 1001;
	my $sambaSID = getSID() . '-' .  $rid;

	my $dn = "cn=$group," .  $users->groupsDn;
        
	unless ($self->_isSambaObject('sambaGroupMapping', $dn)) {
	     my %attrs = (
		     changes => [
                    		add => [
                       		 	 objectClass    => 'sambaGroupMapping',
					 objectClass    => 'eboxGroup',
                        		 sambaSID       => $sambaSID,
                        		 sambaGroupType => '2',
                        		 displayName    => $group,
                           		]
                  		]
		         );
	     $ldap->modify($dn, \%attrs);
	}
}

sub _delGroup($$){
	my $self = shift;
	my $group = shift;

	if ( -d BASEPATH . "/groups/$group"){
 		root ("rm -rf \'" .  BASEPATH . "/groups/$group\'");
	}
	
	# Remove group from printers
	my $samba = EBox::Global->modInstance('samba');
	$samba->setPrintersForGroup($group, []); 

}



sub _delGroupWarning($$) {
	my $self = shift;
	my $group = shift;

	my $path = BASEPATH . "/groups/$group";
	settextdomain('ebox-samba');
	my $txt = __('This group has a sharing directory associated' .
	                           'which conatins data');
	settextdomain('ebox-usersandgroups');

	unless ($self->_directoryEmpty($path)) {
		return ($txt);
	}

	return undef;
}

sub _userAddOns($$) {
	my $self = shift;
        my $username = shift;

	my $samba = EBox::Global->modInstance('samba');
	unless ($samba->service){
		return undef;
	}
	
        my @args;
	my $share = $self->_userSharing($username) ? "yes" : "no";
	my $printers = $samba->_printersForUser($username);
        my $args =  { 'username' => $username,
		      'share'    => $share,
		      'printers' => $printers,
		      'is_admin' => $samba->adminUser($username)
		      };
	use Data::Dumper;
        return { path => '/samba/samba.mas',
                 params => $args };

}

sub _groupAddOns($$) {
	my $self = shift;
        my $groupname = shift;
	
	my $samba = EBox::Global->modInstance('samba');
	unless ($samba->service){
		return undef;
	}
	
	use Data::Dumper;
        my @args;
	my $share = $self->_groupSharing($groupname) ? "yes" : "no";
	my $printers = $samba->_printersForGroup($groupname);
        my $args =  { 'groupname' => $groupname,
		      'share'     => $share,
		      'sharename' => $self->sharingName($groupname),
		      'printers'  => $printers};

	
        return { path => '/samba/samba.mas',
                 params => $args };

}

sub _includeLDAPSchemas {
       my $self = shift;
       my @schemas = SCHEMAS;
       
       return \@schemas;
}

sub _includeLDAPAcls {
	my $self = shift;
	
	my $ldapconf = $self->{ldap}->ldapConf;

	my @acls = ("access to attrs=sambaNTPassword,sambaLMPassword\n" .
		    "\tby dn.regex=\"" . $ldapconf->{'rootdn'} . "\" write\n" .
		    "\tby * none\n");
	
	return \@acls;
}

sub _createDir {
	my $self = shift;
	my $path = shift;
	my $uid  = shift;
	my $gid  = shift;
	my $chmod = shift;

	unless (-d $path) {
		root ("/bin/mkdir \'$path\'");
	}
	root ("/bin/chown $uid:$gid \'$path\'");

	if ($chmod) {
		root ("/bin/chmod $chmod \'$path\'");
	}
}

sub _setUserQuota($$){
	my $self  = shift;
	my $uid   = shift;
	my $quota = shift;

	#FIXME
	use constant INSOFT => 10000;
	use constant INHARD => 10000;
	
	$quota = $quota * 1024; #~Blocks
	root("/usr/sbin/setquota -u $uid $quota $quota " . INSOFT . " " . INHARD . " -a");
	root("/usr/sbin/setquota -t 0 0 -a");
}

sub _setAllUsersQuota {
	my $self = shift;

	my $users = EBox::Global->modInstance('users');
	my $samba = EBox::Global->modInstance('samba');
	my $quota = $samba->defaultUserQuota;

        
	foreach my $user ($users->users) {
		$self->_setUserQuota($user->{'uid'}, $quota);
	}
}

sub _directoryEmpty($$) {
	my $self = shift;
	my $path = shift;
	
	opendir(DIR, $path) or return 1;
	my @ent = readdir(DIR);
	
	return ($#ent == 1);
	
}



sub getSID 
{
	return EBox::Config::configkey('sid');
}

sub _groupSharing($$)
{
	my $self = shift;
	my $group = shift;
	
	return $self->sharingName($group) ? 1 : undef; 
}

# Checks if a resource name exists
sub _sharingResourceExists($$)
{
	my $self  = shift;
	my $name  = shift;
	
	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	my $dn =  $users->groupsDn;
	my %attrs = (
		base   => $dn,
		filter => "(&(objectclass=eboxGroup) " . 
				  "(displayResource=$name))",
		scope  => 'one'
		    );
	my $result = $ldap->search(\%attrs);

	return ($result->count == 1)
}

# TODO Find another name more self-explanatory, this one is  crap
sub  groupShareDirectories
{
	my $self = shift;
	
	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	my $dn =  $users->groupsDn;
	my %attrs = (
		base   => $dn,
		filter => '(&(objectclass=posixGroup) (objectclass=eboxGroup))',
		attrs  => [ 'cn', 'displayResource'],
		scope  => 'one'
		    );
	my $result = $ldap->search(\%attrs);
	
	my @share;
	foreach my $entry ($result->entries) {
		my $group = $entry->get_value('cn');
		my $name  = $entry->get_value('displayResource');
		($name) or next;
		push (@share, { path      =>  BASEPATH . "/groups/$group",
				groupname => $group,
				sharename => $name 
			      });
	}
	return \@share;
}

sub  sharingName($$) {
	my $self = shift;
	my $group = shift;

	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');

	unless ($users->groupExists($group)) {
                throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                                     'value' => $group);
        }

	my $dn =  "cn=$group," . $users->groupsDn;
	my %attrs = (
			base   => $dn,
			filter => "(objectclass=eboxGroup)",
			attrs  => [ 'displayResource'],
			scope  => 'base'
		    );
		    
	my $result = $ldap->search(\%attrs);
	
	my $entry = $result->entry(0);
	my $value = $entry->get_value('displayResource');

	return $value ? $value : "";
}


# Sets the name for a sharing resource in a group
sub setSharingName($$$) {
        my ($self, $group, $name)  = @_;
          	
	my $users = EBox::Global->modInstance('users');

	unless ($users->groupExists($group)) {
                throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                                     'value' => $group);
        }

       if ((not defined $name) or ( $name =~ /^\s*$/)) {
	 throw EBox::Exceptions::External(__("A name should be provided for the share"));
       }
	
	my $oldname = $self->sharingName($group);
	return if ($oldname and $oldname eq $name);
	
	if ($self->_sharingResourceExists($name)) {
		 throw EBox::Exceptions::DataExists(
                                       'data'  => __('sharing resource'),
                                       'value' => $name);
	}
	
	my $dn = "cn=$group," .  $users->groupsDn;
	my %attrs;
	if ($self->_groupSharing($group)) {
		%attrs = ( changes => 
				[ replace => [ displayResource => $name ]]);
	} else {
		%attrs = ( changes => 
				[ add => [ displayResource => $name ]]);
	}
	my $add = $self->{ldap}->modify($dn, \%attrs);
	
	# we need to set the module as changed to regenConfig when saving
	# Above stuff is stored in ldap so global has no idea its conf
	# has changed.
	my $global = EBox::Global->modInstance('global');
	$global->modChange('samba');
	
	unless ( -d BASEPATH . "/groups/$group"){
		my $uid = getpwnam(EBox::Config::user);
		my $gid = $users->groupGid($group);
 		$self->_createDir(BASEPATH . "/groups/$group", 
				   $uid, $gid, "+t,g+w");
	}
}



sub removeSharingName($$) {
	my $self  = shift;
	my $group = shift;
	
	my $users = EBox::Global->modInstance('users');

	unless ($users->groupExists($group)) {
                throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                                     'value' => $group);
        }
	
	my $dn = "cn=$group," .  $users->groupsDn;
	my %attrs = ( changes => [ delete => [ displayResource => [] ]]);
 	$self->{ldap}->modify($dn, \%attrs);

	# we need to set the module as changed to regenConfig when saving
	# Above stuff is stored in ldap so global has no idea its conf
	# has changed.
	my $global = EBox::Global->modInstance('global');
	$global->modChange('samba');

}



sub _pwdChanged ($$) {
	my $self = shift;
	my $result   = shift;
	
	my $ntpwd = $result->get_value('sambaNTPassword');
	my $userpwd = $result->get_value('userPassword');
	
	return ($ntpwd ne nthash($userpwd));
}


sub _getAccountFlags($$) {
	my $self       = shift;
	my $username   = shift;
	
	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	my $dn = "uid=$username," .  $users->usersDn;

	my %attrs = (
		 	base   => $dn,
                        filter => "(objectclass=*)",
                        attrs  => [ 'sambaAcctFlags'],
                        scope  => 'base'
		    );

	my $result = $ldap->search(\%attrs);
	
	my $entry = $result->entry(0);
	return  $entry->get_value('sambaAcctFlags');

}

sub _userSharing($$) {
	my $self       = shift;
	my $username   = shift;
	
	my $flags = $self->_getAccountFlags($username);
	return (not ($flags =~ /D/));
}

sub setUserSharing($$) {
	my $self = shift;
	my $username = shift;
	my $share = shift;

	my $ldap  = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	
	unless ($users->userExists($username)){
		 throw EBox::Exceptions::DataNotFound(
                                        'data'  => __('group'),
                                        'value' => $username);
	}
        my $dn = "uid=$username," .  $users->usersDn;

	my $flags;
	if ($share eq 'yes') {
		return  if $self->_userSharing($username);
		$flags = $self->_getAccountFlags($username);
		$flags =~ s/D//g;
	} else {
		return  unless $self->_userSharing($username);
		$flags = $self->_getAccountFlags($username);
		$flags =~ s/U/UD/g;
	}

	
	my %attrs = ( replace => {  'sambaAcctFlags' => $flags });
	$ldap->modify($dn, \%attrs );
}

# Method: sambaDomainName
#
# 	Fetch the samba domain name
# 
# Returns:
#
# 	string - samba domain name
# 	
sub sambaDomainName
{
	my $self = @_;
	my $ldap = $self->{ldap}; 
	my %attrs = ( 
			base => "dc=ebox", 
			filter => "(objectclass=sambaDomain)", 
			scope => "sub"
	    	    ); 
	my $entry = $ldap->search(\%attrs)->pop_entry();

	if ($entry) {
		return $entry->get_value('sambaDomainName');
	} else {
		return undef;
	}
}

# Method: setSambaDomainName
#
# 	Set the samba domain name. The entry is created if it does not
#	exits
# 
# Parameters:
#
#	name - string containing the domain name
#
# Throws:
#
#	InvalidData - wrong domain name
sub setSambaDomainName
{
	my ($self, $domain) = @_;
	
	my $ldap = $self->{ldap}; 
	my %attrs = (
				base => "dc=ebox",
				filter => "(sambaDomainName=*)",
				attrs => ['sambaDomainName'],
				scope => "sub"
		    );

	foreach my $entry ($ldap->search(\%attrs)->entries()) {
		my $dn = 'sambaDomainName=' . 
			$entry->get_value('sambaDomainName') . ',dc=ebox';
		$ldap->delete($dn);	
	}

	my $users = EBox::Global->modInstance('users');
	%attrs = (
		attr => [
			'sambaDomainName'	=> $domain,
			'sambaSID'		=> getSID(),
			'uidNumber'		=> $users->lastUid,
			'gidNumber'		=> $users->lastGid,
			'objectclass'		=> ['sambaDomain', 
						    'sambaUnixidPool']
			]
		   );

	my $dn = "sambaDomainName=$domain,dc=ebox";
	$ldap->add($dn, \%attrs);
}

# Method: updateNetbiosName
#
#	Update in LDAP all those attributes which contain the netbios name
# 
# Parameters:
#
#	netbios - string containing the new netbios name
#
# Throws:
#
#	InvalidData - wrong domain name
sub updateNetbiosName
{
	my ($self, $netbios) = @_;
	
	my $users = EBox::Global->modInstance('users');
	my $ldap = $self->{'ldap'};
	
	foreach my $user ($users->users){
		my $username = $user->{'username'};
		my $dn = "uid=$username," .  $users->usersDn;
		$ldap->modifyAttribute($dn, 'sambaHomePath', 
					"\\\\$netbios\\homes\\$username");
		$ldap->modifyAttribute($dn, 'sambaProfilePath', 
					"\\\\$netbios\\profiles\\$username");
	}
}

sub _isSambaObject($$$) {
	my $self = shift;
	my $object = shift;
	my $dn   = shift;
	
	my $ldap = $self->{ldap};
	
	my %attrs = (
			base   => $dn,
			filter => "(objectclass=$object)",
			attrs  => [ 'objectClass'],
			scope  => 'base'
		    );
	 
	my $result = $ldap->search(\%attrs);

	if ($result->count ==  1) {
		return 1;
	}

	return undef;
}

# return a ref to a list of the paths of all (users and group) shared directories
sub sharedDirectories
{
  my ($self) = @_;

  my @dirs;
  @dirs = map {
    $_->{path}
  } @{ $self->groupShareDirectories() };

  my $users = EBox::Global->modInstance('users');
  defined $users or throw EBox::Exceptions::Internal('Can not get users and groups module');

  my @homedirs = map {  $_->{homeDirectory}} $users->users();
  push @dirs, @homedirs;
  
  return \@dirs;
}


sub basePath
{
  return BASEPATH;
}

sub  usersPath
{
  return USERSPATH;
} 


sub groupsPath
{
  return GROUPSPATH;
}

1;
