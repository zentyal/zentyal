# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::MailUserLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

# LDAP schema
use constant SCHEMAS		=> ('/etc/ldap/schema/authldap.schema', '/etc/ldap/schema/eboxmail.schema');
use constant DIRVMAIL	=>	'/var/vmail/';
use constant BYTES				=> '1048576';

use base qw(EBox::LdapUserBase);

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = new EBox::Ldap;
	bless($self, $class);
	return $self;
}

# Implements LdapUserBase interface
sub setUserAccount () {
	my ($self, $user, $lhs, $rhs, $mdsize)  = @_;
	
	my $ldap = $self->{ldap};
	my $users = EBox::Global->modInstance('users');
	my $mail = EBox::Global->modInstance('mail');
  	my $email = $lhs.'@'.$rhs;
	
	unless ($email =~ /^[^\.\-][\w\.\-]+\@[^\.\-][\w\.\-]+$/) {
		throw EBox::Exceptions::InvalidData('data' => __('mail account'),
														'value' => $email);
   }
	
	if ($mail->{malias}->accountExists($email)) {
		throw EBox::Exceptions::DataExists('data' => __('mail account'),
														'value' => $email);
   }
	

	my $userinfo = $users->userInfo($user);

	my $dn = "uid=$user," .  $users->usersDn;
	my %attrs = ( 
		changes => [ 
			add => [
				objectClass          => 'couriermailaccount',
				objectClass          => 'usereboxmail',
				mail		=> $email,
				mailbox	=> $rhs.'/'.$lhs.'/',
				quota		=> '0',
				userMaildirSize => $mdsize,
				mailHomeDirectory => DIRVMAIL
			]
		]
	);
	my $add = $ldap->modify($dn, \%attrs ); 

	$self->_createMaildir($lhs, $rhs);
	
	my @list = $mail->{malias}->listMailGroupsByUser($user);

	foreach my $item(@list) {
		my $alias = $mail->{malias}->groupAlias($item);
		$mail->{malias}->addMaildrop($alias, $email);
	}
}

sub delUserAccount () { #username, mail
	my ($self, $username, $usermail) = @_;
	
	my $mail = EBox::Global->modInstance('mail');
	my $users = EBox::Global->modInstance('users');

	# First we remove all mail aliases asociated with the user account.
	foreach my $alias ($mail->{malias}->accountAlias($usermail)) {
		$mail->{malias}->delAlias($alias);
	}

	# Remove mail account from group alias maildrops
	foreach my $alias ($mail->{malias}->groupAccountAlias($usermail)) {
		$mail->{malias}->delMaildrop($alias,$usermail);
	}


	# Now we remove all mail atributes from user ldap leaf
	my $mailbox = $self->getUserLdapValue($username, "mailbox");
	my %attrs = (
			changes => [
				delete => [
					mail			=> $self->getUserLdapValue($username, "mail"),
					mailbox 		=> $mailbox,
					quota			=> $self->getUserLdapValue($username, "quota"),
					userMaildirSize => $self->getUserLdapValue($username, "userMaildirSize"),
					mailHomeDirectory => $self->getUserLdapValue($username, "mailHomeDirectory"),
					objectClass	=> 'couriermailaccount',
					objectClass => 'usereboxmail'
				]
			]
	);

	my $ldap = $self->{ldap};
	my $dn = "uid=$username," .  $users->usersDn;
	my $removed = $ldap->modify($dn, \%attrs ); 

	# Here we remove mail directorie of user account.
	root("/bin/rm -rf ".DIRVMAIL.$mailbox);

}

sub delAccountsFromVDomain () { #vdomain
	my ($self, $vdomain) = @_;

	my %accs = %{$self->allAccountsFromVDomain($vdomain)};

	my $mail = "";
	foreach my $uid (keys %accs) {
		$mail = $accs{$uid};
		$self->delUserAccount($uid, $accs{$uid});
	}
}

sub getUserLdapValue () { #uid, ldap value
	my ($self, $uid, $value) = @_;
	my $users = EBox::Global->modInstance('users');

	my %args = (
			base => $users->usersDn(),
			filter => "&(objectclass=*)(uid=$uid)",
			scope => 'one',
			attrs => [$value]
	);

	my $result = $self->{ldap}->search(\%args);
	my $entry = $result->entry(0);
	
	return $entry->get_value($value);
}


sub _delGroup() { #groupname
	my ($self, $group) = @_;
	my $mail = EBox::Global->modInstance('mail');

	$mail->{malias}->delAliasGroup($group);
	
}

sub _delGroupWarning() {
	my ($self, $group) = @_;
	my $mail = EBox::Global->modInstance('mail');

	settextdomain('ebox-mail');
	my $txt = __('This group has a mail alias');
	settextdomain('ebox-usersandgroups');
	
	if ($mail->{malias}->groupHasAlias($group)) {
		return ($txt);
	}

	return undef;
}


sub _delUser() { #username
	my ($self, $user) = @_;

	$self->delUserAccount($user);
	
}

sub _delUserWarning() {
	my ($self, $user) = @_;

	settextdomain('ebox-mail');
	my $txt = __('This user has a mail account');
	settextdomain('ebox-usersandgroups');
	
	if ($self->_accountExists($user)) {
		return ($txt);
	}

	return undef;
}

sub _userAddOns() {
	my ($self, $username) = @_;

	my $mail = EBox::Global->modInstance('mail');
	my $users = EBox::Global->modInstance('users');
	
	unless ($mail->service){
		return undef;
	}
	
	my %args = (
			base => $users->usersDn,
			filter => "&(objectclass=*)(uid=$username)",
			scope => 'one',
			attrs => ['mail', 'userMaildirSize']
	);

	my $result = $self->{ldap}->search(\%args);
	my $entry = $result->entry(0);

	my $usermail = $entry->get_value('mail');
	my $mdsize = $entry->get_value('userMaildirSize');
	my %vd =  $mail->{vdomains}->vdandmaxsizes();
	my @aliases = $mail->{malias}->accountAlias($usermail);

	my $args = { 'username'	=>	$username,
			'mail'	=>	$usermail,
			'aliases'	=> \@aliases,
			'vdomains'	=> \%vd,
			'mdsize'	=> ($mdsize / $self->BYTES) };
	
	return { path => '/mail/account.mas', params => $args };

}

sub _groupAddOns() {
	my ($self, $group) = @_;

	my $mail = EBox::Global->modInstance('mail');
	my $users = EBox::Global->modInstance('users');
	
	unless ($mail->service) {
		return undef;
	}
	
	my %args = (
			base => $mail->{malias}->aliasDn,
			filter => "&(objectclass=*)(uid=$group)",
			scope => 'one',
			attrs => ['mail']
	);

	my $alias = undef;
	my $result = $self->{ldap}->search(\%args);
	

	if ($result->count > 0) {
		my $entry = $result->entry(0);
		$alias = $entry->get_value('mail');
	}

	my @vd =  $mail->{vdomains}->vdomains();

	my $args = { 	'group' => $group,
						'vdomains'	=>	\@vd,
						'alias'		=> $alias
	};
	
	return { path => '/mail/groupalias.mas', params => $args };
}

sub _modifyGroup() {
	my ($self, $group) = @_;
	my $mail = EBox::Global->modInstance('mail');

	my %args = (
		base => $mail->{malias}->aliasDn,
		filter => "&(objectclass=couriermailalias)(uid=$group)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	if($result->count > 0) {
		my $alias = ($result->sorted('mail'))[0]->get_value('mail');
		$mail->{malias}->updateGroupAlias($group, $alias);
	}

}

sub _accountExists() { #username
	my ($self, $username) = @_;

	my $users = EBox::Global->modInstance('users');

	my %attrs = (
		base => $users->usersDn,
		filter => "&(objectclass=couriermailaccount)(uid=$username)",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);

}

sub setMDSize() {
	my ($self, $uid, $mdsize) = @_;
	my $users = EBox::Global->modInstance('users');
	
	my $dn = "uid=$uid," .  $users->usersDn;
	my $r = $self->{'ldap'}->modify($dn, {
		replace => { 'userMaildirSize' => $mdsize * $self->BYTES }});
}

sub allAccountsFromVDomain() { #vdomain
	my ($self, $vdomain) = @_;

	my $users = EBox::Global->modInstance('users');

	my %attrs = (
		base => $users->usersDn,
		filter => "&(objectclass=couriermailaccount)(mail=*@".$vdomain.")",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);
	
	my %accounts = map { $_->get_value('uid'), $_->get_value('mail')} $result->sorted('uid');

	return \%accounts;
}

sub checkUserMDSize () {
	my ($self, $vdomain, $newmdsize) = @_;

	my %accounts = %{$self->allAccountsFromVDomain($vdomain)};
	my @warnusers = ();
	my $size = 0;

	foreach my $acc (keys %accounts) {
		$size = $self->_getActualMDSize($acc);
		($size > $newmdsize) and push (@warnusers, $acc);
	}

	return \@warnusers;
}

sub _getActualMDSize() {
	my ($self, $username) = @_;

	my $mailhome = $self->getUserLdapValue($username, 'mailHomeDirectory');
	my $mailbox = $mailhome . $self->getUserLdapValue($username, 'mailbox');

	open(FILE,$mailbox.'maildirsize');
	my @lines = <FILE>;
	
	shift(@lines);
	
	my $sum = 0;
	for my $line (@lines) {
		my @array = split(' ', $line);
		$sum += $array[0];
	}

	return ($sum / $self->BYTES);
}

sub _includeLDAPSchemas {
       my $self = shift;
       my @schemas = SCHEMAS;
      
       return \@schemas;
}

#sub _includeLDAPAcls {
#}

sub _createMaildir() { #user (lhs of account), vdomain (rhs of account)
	my ($self, $lhs, $vdomain) = @_;
	
	root("/bin/mkdir -p /var/vmail");
	root("/bin/chmod 2775 /var/mail/");
	root("/bin/chown ebox.ebox /var/vmail/");

	root("/bin/mkdir -p /var/vmail/$vdomain");
	root("/bin/chown ebox.ebox /var/vmail/$vdomain");
	root("/usr/bin/maildirmake /var/vmail/$vdomain/$lhs/");
	root("/bin/chown ebox.ebox -R /var/vmail/$vdomain/$lhs/");

}

sub gidvmail() {
	my $self = shift;

	return scalar (getgrnam(EBox::Config::group));
}

sub uidvmail() {
	my $self = shift;

	return scalar (getpwnam(EBox::Config::user));
}

sub _isCourierObject() {
	my ($self, $object, $dn) = @_;
	
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

1;
