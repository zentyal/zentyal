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

package EBox::Samba;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::LdapModule EBox::FirewallObserver);

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Service;
use EBox::SambaLdapUser;
use EBox::UsersAndGroups;
use EBox::Network;
use EBox::SambaFirewall;
use EBox::Summary::Module;
use EBox::Summary::Value;
use EBox::Summary::Status;
use EBox::Summary::Section;
use EBox::Menu::Item;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use constant SMBCONFFILE          => '/etc/samba/smb.conf';
use constant LIBNSSLDAPFILE       => '/etc/libnss-ldap.conf';
use constant SMBLDAPTOOLBINDFILE  => '/etc/smbldap-tools/smbldap_bind.conf';
use constant SMBLDAPTOOLCONFFILE  => '/etc/smbldap-tools/smbldap.conf';
use constant SMBPIDFILE           => '/var/run/samba/smbd.pid';
use constant NMBPIDFILE           => '/var/run/samba/nmbd.pid';
use constant MAXNETBIOSLENGTH 	  => 32;
use constant MAXWORKGROUPLENGTH   => 32;
use constant MAXDESCRIPTIONLENGTH => 255;
use constant SMBPORTS => qw(137 138 139 445);

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'samba',
					  domain => 'ebox-samba',
					  @_);
	bless($self, $class);
	return $self;
}

sub domain
{
	return 'ebox-samba';
}

sub _setSambaConf
{
	my $self = shift;
	
	my $net = EBox::Global->modInstance('network');
	my $interfaces = join (',', @{$net->InternalIfaces}, 'lo');
	my $ldap = EBox::Ldap->instance();
	my $smbimpl = new EBox::SambaLdapUser;
	
	my @array = ();
	push(@array, 'netbios'   => $self->netbios);
	push(@array, 'desc'      => $self->description);
	push(@array, 'workgroup' => $self->workgroup);
	push(@array, 'ldap'      => $ldap->ldapConf);
	push(@array, 'dirgroup'  => $smbimpl->groupShareDirectories);
	push(@array, 'ifaces'    => $interfaces); 
	push(@array, 'printers'  => $self->_sambaPrinterConf());
	push(@array, 'active_file' => $self->fileService());	
	push(@array, 'active_printer' => $self->printerService());	
	push(@array, 'pdc' => $self->pdc());
	
	$self->writeConfFile(SMBCONFFILE, "samba/smb.conf.mas", \@array);

	my $ldapconf = $ldap->ldapConf;
	my $users = EBox::Global->modInstance('users');
	
	@array = ();
	push(@array, 'basedc'    => $ldapconf->{'dn'});
	push(@array, 'ldapi'     => $ldapconf->{'ldapi'});
	push(@array, 'binddn'     => $ldapconf->{'rootdn'});
	push(@array, 'bindpw'    => $ldap->getPassword());
	push(@array, 'usersdn'   => $users->usersDn);
	push(@array, 'groupsdn'  => $users->groupsDn); 
	push(@array, 'computersdn' => 'ou=Computers,' . $ldapconf->{'dn'});
	
	$self->writeConfFile(LIBNSSLDAPFILE, "samba/libnss-ldap.conf.mas", 
					     \@array);

	@array = ();
	push(@array, 'netbios'  => $self->netbios());
	push(@array, 'domain'   => $self->domainName());
	push(@array, 'sid' 	=> $smbimpl->getSID());
	push(@array, 'ldap'     => $ldap->ldapConf());

	$self->writeConfFile(SMBLDAPTOOLCONFFILE, "samba/smbldap.conf.mas", 
					     \@array);
	
	@array = ();
	push(@array, 'pwd' 	=> $ldap->getPassword());
	push(@array, 'ldap'     => $ldap->ldapConf());

	$self->writeConfFile(SMBLDAPTOOLBINDFILE,
			"samba/smbldap_bind.conf.mas", \@array);

	# Set quotas
	$smbimpl->_setAllUsersQuota();
}

sub isRunning
{
	my $self = shift;
	
	return EBox::Service::running('smbd') and 
		EBox::Service::running('nmbd');
}

sub _doDaemon
{
        my $self = shift;
        if ($self->service and $self->isRunning) {
		EBox::Service::manage('smbd','restart');
		EBox::Service::manage('nmbd','restart');
        } elsif ($self->service) {
		EBox::Service::manage('smbd','start');
		EBox::Service::manage('nmbd','start');
        } elsif ($self->isRunning) {
		EBox::Service::manage('smbd','stop');
		EBox::Service::manage('nmbd','stop');
        }
}

sub _stopService
{
	EBox::Service::manage('smbd','stop');
	EBox::Service::manage('nmbd','stop');
}

sub _regenConfig
{
	my $self = shift;
	$self->_setSambaConf;
	$self->_doDaemon();
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
        my ($self, $protocol, $port, $iface) = @_;

	return undef unless($self->service());

	foreach my $smbport (SMBPORTS) {
		return 1 if ($port eq $smbport);
	}

	return undef;
}

sub firewallHelper
{
	my $self = shift;
	if ($self->service) {
		return new EBox::SambaFirewall();
	}
	return undef;
}

sub statusSummary
{
	my $self = shift;
	my $running;
	if ($self->fileService()) {
		$running = $self->isRunning();
	}
	return new EBox::Summary::Status('samba', __('File sharing'),
					$running, $self->fileService);
}

sub menu
{
        my ($self, $root) = @_;
        $root->add(new EBox::Menu::Item('url' => 'Samba/Index',
                                        'text' => __('File sharing')));
}

sub rootCommands 
{
	my $self = shift;
	my @array = ();
	push(@array, $self->rootCommandsForWriteConfFile(SMBCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(LIBNSSLDAPFILE));
	push(@array, $self->rootCommandsForWriteConfFile(SMBLDAPTOOLBINDFILE));
	push(@array, $self->rootCommandsForWriteConfFile(SMBLDAPTOOLCONFFILE));
	push(@array, "/bin/mkdir " . USERSPATH . "/*");
	push(@array, "/bin/chown * " . USERSPATH . "/*");
	push(@array, "/bin/chmod * " . USERSPATH . "/*");
	push(@array, "/bin/rm -rf " . USERSPATH. "/*");
	push(@array, "/bin/mkdir " . GROUPSPATH . "/*");
	push(@array, "/bin/chown * " . GROUPSPATH . "/*");
	push(@array, "/bin/chmod * " . GROUPSPATH . "/*");
	push(@array, "/bin/rm -rf " . GROUPSPATH. "/*");
	push(@array, "/bin/mkdir " . PROFILESPATH . "/*");
	push(@array, "/bin/chown * " . PROFILESPATH . "/*");
	push(@array, "/bin/chmod * " . PROFILESPATH . "/*");
	push(@array, "/bin/rm -rf " . PROFILESPATH. "/*");
	push(@array, "/usr/sbin/setquota *");
	push(@array, "/usr/sbin/smbldap-useradd *");
	push(@array, "/usr/sbin/smbldap-userdel *");
	push(@array, "/usr/sbin/smbldap-usermod *");
	push(@array, "/usr/sbin/setquota *");

	return @array;
}

#   Function: service
#
#       Returns if the printer or file sharing service is enabled  
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef      
#
sub service
{
        my $self = shift;
        return ($self->fileService()  or $self->printerService());
}

#   Function: setFileService 
#
#       Sets the file sharing service through samba
#
#   Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setFileService # (enabled) 
{
        my ($self, $active) = @_;
        ($active and $self->fileService) and return;
        (!$active and !$self->fileService) and return;

	if ($active) {
		if (not $self->printerService) {
			my $fw = EBox::Global->modInstance('firewall');
			foreach my $smbport (SMBPORTS) {
				unless ($fw->availablePort('tcp',$smbport) and
					$fw->availablePort('udp',$smbport)) {
					throw EBox::Exceptions::DataExists(
					'data'  => __('listening port'),
					'value' => $smbport);
				}
			}
		}
	}
        $self->set_bool('file_active', $active);
}

#   Function: serviceFile
#
#       Returns if the file sharing service is enabled  
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef      
#
sub fileService
{
        my $self = shift;
        return $self->get_bool('file_active');
}


#   Function: setPrinterService 
#
#       Sets the printer sharing service through samba and cups
#
#   Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setPrinterService # (enabled) 
{
        my ($self, $active) = @_;
        ($active and $self->printerService) and return;
        (!$active and !$self->printerService) and return;

	if ($active) {
		if (not $self->fileService) {
			my $fw = EBox::Global->modInstance('firewall');
			foreach my $smbport (SMBPORTS) {
				unless ($fw->availablePort('tcp',$smbport) and
					$fw->availablePort('udp',$smbport)) {
					throw EBox::Exceptions::DataExists(
					'data'  => __('listening port'),
					'value' => $smbport);
				}
			}
		}
	}
        $self->set_bool('printer_active', $active);
}

#   Method: servicePrinter
#
#       Returns if the printer sharing service is enabled  
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef      
#
sub printerService 
{
        my $self = shift;
        return $self->get_bool('printer_active');
}



#   Method: setDomainName
#
#      	Set the domain's name. Needed for PDC mode
#
#   Parameters:
#
#       name - string containing the name
#
sub setDomainName
{
        my ($self, $domain) = @_;
	unless (_checkWorkgroupName($domain)) {
		 throw EBox::Exceptions::InvalidData
		        ('data' => __('Domain Name'), 'value' => $domain);
	}
	($domain eq $self->domain) and return;
        $self->set_string('domain', $domain);

}

#   Method: domainName
#
#       Return the domain's name.
#
#   Returns:
#
#       string - containing the domain's name
#
sub domainName
{
        my ($self) = @_;
        return $self->get_string('domain');
}

#   Method: pdc
#
#       Returns if samba must configured as a PDC 
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef      
#
sub pdc
{
        my ($self) = @_;
        return $self->get_bool('pdc');
}

#   Method: setPdc
#
#      	Set the configuration for samba, PDC or file server
#
#   Parameters:
#
#       enable - true if enabled, otherwise undef      
#
sub  setPdc
{
        my ($self, $enable) = @_;
	
	($self->pdc eq $enable) and return;
        $self->set_bool('pdc', $enable);
}
#   Method: adminUser
#
#	Check if a given user is a Domain Administrator
#
#   Parameters:
#
#       user - string containign the username
#
#  Returns:
#
#  	bool - true if it is, otherwise undef
#
sub  adminUser
{
        my ($self, $user) = @_;
	($user) or return;
        my $usermod = EBox::Global->modInstance('users');
	foreach my $u (@{$usermod->usersInGroup('Domain Admins')}) {
		return 1 if ($u eq $user);
	}
	return undef;
}


#   Method: setAdminUser
#
#	Add a given user to the Domain Admins group
#
#   Parameters:
#
#       user - string containign the username
#	admin -  true if it must be an administrator, undef otherwise
#
#
sub  setAdminUser 
{
        my ($self, $user, $admin) = @_;
	($user) or return;
	($admin xor $self->adminUser($user)) or return;
        my $usermod = EBox::Global->modInstance('users');
	if ($admin) {
		$usermod->addUserToGroup($user, 'Domain Admins');
	} else {
		$usermod->delUserFromGroup($user, 'Domain Admins');
	}
}

sub setNetbios # (enabled) 
{
        my ($self, $netbios) = @_;
        unless (_checkNetbiosName($netbios)) {
                 throw EBox::Exceptions::InvalidData
                        ('data' => __('netbios'), 'value' => $netbios);
        }
        ($netbios eq $self->netbios) and return;
        $self->set_string('netbios', $netbios);
}

#returns netbios name
#ret: bool
sub netbios
{
        my $self = shift;
        return $self->get_string('netbios');
}

sub setDescription # (enabled) 
{
        my ($self, $description) = @_;
	unless (_checkDescriptionName($description)) {
		 throw EBox::Exceptions::InvalidData
		        ('data' => __('description'), 'value' => $description);
	}
	($description eq $self->description) and return;
        $self->set_string('description', $description);
}

#returns description name
#ret: bool
sub description
{
        my $self = shift;
        return $self->get_string('description');
}

sub setWorkgroup # (enabled) 
{
        my ($self, $workgroup) = @_;
	unless (_checkWorkgroupName($workgroup)) {
		 throw EBox::Exceptions::InvalidData
		        ('data' => __('working group'), 'value' => $workgroup);
	}
	($workgroup eq $self->workgroup) and return;
        $self->set_string('workgroup', $workgroup);
}

#returns workgroup name
#ret: bool
sub workgroup
{
        my $self = shift;
        return $self->get_string('workgroup');
}

sub setDefaultUserQuota # (enabled) 
{
        my ($self, $userQuota) = @_;
	unless (_checkQuota($userQuota)) {
		 throw EBox::Exceptions::InvalidData
		        ('data' => __('quota'), 'value' => $userQuota);
	}
	($userQuota eq $self->defaultUserQuota) and return;
        $self->set_int('userquota', $userQuota);
}

#returns userQuota name
#ret: bool
sub defaultUserQuota
{
        my $self = shift;
        return $self->get_int('userquota');
}

# LdapModule implmentation    
sub _ldapModImplementation    
{
        my $self;
        
        return new EBox::SambaLdapUser();
}

# Helper functions
sub _checkNetbiosName ($)
{
	my $name = shift;
	(length($name) <= MAXNETBIOSLENGTH) or return undef;
	(length($name) > 0) or return undef;
	return 1;
}

sub _checkWorkgroupName ($)
{
	my $name = shift;
	(length($name) <= MAXWORKGROUPLENGTH) or return undef;
	(length($name) > 0) or return undef;
	return 1;
}

sub _checkDescriptionName ($)
{
	my $name = shift;
	(length($name) <= MAXDESCRIPTIONLENGTH) or return undef;
	(length($name) > 0) or return undef;
	return 1;
}

sub _checkQuota ($)
{
	my $quota = shift;
	($quota =~ /\D/) and return undef;
	return 1;
}	

sub addPrinter # (resource)
{
	my $self = shift;
	my $name = shift;

	return if ($self->dir_exists("printers/$name"));
	$self->set_list("printers/$name/users", "string", []);
	$self->set_list("printers/$name/groups", "string", []);
	
}

sub printers 
{
	my $self = shift;
	
	my @printers;
	for my $printer (@{$self->array_from_dir("printers")}) {
		push (@printers,  $printer->{'_dir'});
	}

	return \@printers;
}

sub _addUsersToPrinter # (printer, users)
{
	my $self = shift;
	my $printer = shift;
	my $users = shift;

	unless ($self->dir_exists("printers/$printer")) {
		throw EBox::Exceptions::DataNotFound('data' => 'printer',
						     'value' => $printer);
	}
	
	
	for my $username (@{$users}) {
		_checkUserExists($username);
	}


	$self->set_list("printers/$printer/users", "string", $users);
}

sub _addGroupsToPrinter # (printer, groups)
{
	my $self = shift;
	my $printer = shift;
	my $groups = shift;

	unless ($self->dir_exists("printers/$printer")) {
		throw EBox::Exceptions::DataNotFound('data' => 'printer',
						     'value' => $printer);
	}
	
	
	for my $groupname (@{$groups}) {
		_checkGroupExists($groupname);
	}

	$self->set_list("printers/$printer/groups", "string", $groups);
}

sub _printerUsers # (printer)
{
	my $self = shift;
	my $printer = shift;
	
	unless ($self->dir_exists("printers/$printer")) {
		throw EBox::Exceptions::DataNotFound('data' => 'printer',
						     'value' => $printer);
	}

	return $self->get_list("printers/$printer/users");
}

sub _printerGroups # (group)
{
	my $self = shift;
	my $printer = shift;
	
	unless ($self->dir_exists("printers/$printer")) {
		throw EBox::Exceptions::DataNotFound('data' => 'printer',
						     'value' => $printer);
	}

	return $self->get_list("printers/$printer/groups");
}

sub _printersForUser # (user)
{
	my $self = shift;
	my $user = shift;

	_checkUserExists($user);
	
	my @printers;
	for my $printer (@{$self->array_from_dir("printers")}) {
		my $name = $printer->{'_dir'};
		my $print = { 	'name' => $name, 'allowed' => undef };
		my $users = $printer->{'users'};
		if (@{$users}) {
			$print->{'allowed'} = 1 if (grep(/^$user$/, @{$users}));
		}
		push (@printers, $print);
	}
	
	return \@printers;
}

sub _printersForGroup # (user)
{
	my $self = shift;
	my $group = shift;

	_checkGroupExists($group);
	
	my @printers;
	for my $printer (@{$self->array_from_dir("printers")}) {
		my $name = $printer->{'_dir'};
		my $print = { 'name' => $name, 'allowed' => undef };
		my $groups = $self->get_list("printers/$name/groups");
		if (@{$groups}) {
			$print->{'allowed'} = 1 if (grep(/^$group$/, @{$groups}));
		}
		push (@printers, $print);
	}
	
	return \@printers;
}

sub setPrintersForUser # (user, printers)
{
	my $self = shift;
	my $user = shift;
	my $newconf = shift;

	_checkUserExists($user);

	my %currconf;
	for my $conf (@{$self->_printersForUser($user)}) {
		$currconf{$conf->{'name'}} = $conf->{'allowed'};
	}
	my @changes;
	for my $conf (@{$newconf}) {
		if ($currconf{$conf->{'name'}} xor $conf->{'allowed'}) {
			push (@changes, $conf);
		}
	}
	
	for my $printer (@changes) {
		my @users;
		my $new = undef;
		my $name = $printer->{'name'};
		if ($printer->{'allowed'}) {
		 	@users = @{$self->_printerUsers($name)};
			next if (grep(/^$user$/, @users));
			push (@users, $user);
			$new = 1;
		} else {
			my @ousers = @{$self->_printerUsers($name)};
			@users = grep (!/^$user$/, @ousers);
			if (@users != @ousers) {
				$new = 1;
			}
		}

		$self->_addUsersToPrinter($name, \@users) if ($new);
	}
}

sub setPrintersForGroup # (user, printers)
{
	my $self = shift;
	my $group = shift;
	my $newconf = shift;

	_checkGroupExists($group);
	
	my %currconf;
	for my $conf (@{$self->_printersForGroup($group)}) {
		$currconf{$conf->{'name'}} = $conf->{'allowed'};
	}
	my @changes;
	for my $conf (@{$newconf}) {
		if ($currconf{$conf->{'name'}} xor $conf->{'allowed'}) {
			push (@changes, $conf);
		}
	}
	
	for my $printer (@changes) {
		my @groups;
		my $new = undef;
		my $name = $printer->{'name'};
		if ($printer->{'allowed'}) {
		 	@groups = @{$self->_printerGroups($name)};
			next if (grep(/^$group$/, @groups));
			push (@groups, $group);
			$new = 1;
		} else {
			my @ogroups = @{$self->_printerGroups($name)};
			@groups = grep (!/^$group$/, @ogroups);
			if (@groups != @ogroups) {
				$new = 1;
			}
		}

		$self->_addGroupsToPrinter($name, \@groups) if ($new);
	}
}


sub delPrinter # (resource)
{
	my $self = shift;
	my $name = shift;

	unless ($self->dir_exists("printers/$name")) {
		throw EBox::Exceptions::DataNotFound('data' => 'printer',
						     'value' => $name);
	}

	$self->delete_dir("printers/$name");
}

sub existsShareResource # (resource)
{
	my $self = shift;
	my $name = shift;

	my $usermod = EBox::Global->modInstance('users');
	if ($usermod->userExists($name)) {
		return __('user');
	}
	if ($usermod->groupExists($name)) {
		return __('group');
	}
	for my $printer (@{$self->printers()}) {
		return __('printer') if ($name eq $printer);
	}

	return undef;
}

sub _checkUserExists # (user)
{
	my $user = shift;
	
	my $usermod = EBox::Global->modInstance('users');
	unless ($usermod->userExists($user)){
			 throw EBox::Exceptions::DataNotFound(
						'data'  => __('user'),
						'value' => $user);
	}

	return 1;
}

sub _checkGroupExists # (user)
{
	my $group = shift;
	
	my $groupmod = EBox::Global->modInstance('users');
	unless ($groupmod->groupExists($group)){
			 throw EBox::Exceptions::DataNotFound(
						'data'  => __('group'),
						'value' => $group);
	}
	
	return 1;
}

sub _sambaPrinterConf 
{
	my $self = shift;

	my @printers;
	foreach my $printer (@{$self->printers()}) {
		my $users = "";
		for my $user (@{$self->_printerUsers($printer)}) {
			$users .= "\"$user\" ";
		}
		for my $group (@{$self->_printerGroups($printer)}) {
			$users .= "\@\"$group\" ";
		}
		push (@printers, { 'name' => $printer , 'users' => $users});
	}

	return \@printers;
}

1;
