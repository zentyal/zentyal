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

package EBox::MailUserLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use Perl6::Junction qw(any);

# LDAP schema
use constant SCHEMAS		=> ('/etc/ldap/schema/authldap.schema', '/etc/ldap/schema/eboxmail.schema');
use constant DIRVMAIL	=>	'/var/vmail/';
use constant BYTES				=> '1048576';
use constant MAXMGSIZE				=> '104857600';

use base qw(EBox::LdapUserBase);

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = EBox::Ldap->instance();

	bless($self, $class);
	return $self;
}

# Method: setUserAccount
#
#  This method sets a mail account to a user
#
# Parameters:
#
# 		user - username
# 		lhs - the left hand side of a mail (the foo on foo@bar.baz account)
# 		rhs - the right hand side of a mail (the bar.baz on previus account)
# 		mdsize - the maildir size of the account
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

	if ($mail->mdQuotaAvailable) {
	  $self->_setUserAccountWithMdQuota($dn, $mdsize);
	}
}

# Method: delUserAccount
#
#  This method removes a mail account to a user
#
# Parameters:
#
# 		username - username
#		usermail - the user's mail address
sub delUserAccount () { #username, mail
	my ($self, $username, $usermail) = @_;

	($self->_accountExists($username)) or return;
	
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

	# get the mailbox attribute for later use..
	my $mailbox = $self->getUserLdapValue($username, "mailbox");

	# Now we remove all mail atributes from user ldap leaf
	my @toDelete = (
			mail			=> $self->getUserLdapValue($username, "mail"),
			mailbox 		=> $mailbox,
			quota			=> $self->getUserLdapValue($username, "quota"),

			mailHomeDirectory => $self->getUserLdapValue($username, "mailHomeDirectory"),
			objectClass	=> 'couriermailaccount',
			objectClass => 'usereboxmail'
		       );


	push @toDelete, $self->_userWithMdQuotaLdapAttrs($username);



	my %attrs = (
		     changes => [
				 delete => \@toDelete,
				]
		    );
	
	my $ldap = $self->{ldap};
	my $dn = "uid=$username," .  $users->usersDn;
	$ldap->modify($dn, \%attrs ); 

	# Here we remove mail directorie of user account.
	root("/bin/rm -rf ".DIRVMAIL.$mailbox);


}


# Method: userAccount
#
#  return the user mail account or undef if it doesn't exists
#
sub userAccount
{
      my ($self, $username) = @_;

      my $mail = EBox::Global->modInstance('mail');
      my $users = EBox::Global->modInstance('users');

      my %args = (
		  base => $users->usersDn,
		  filter => "&(objectclass=*)(uid=$username)",
		  scope => 'one',
		  attrs => ['mail', 'userMaildirSize'],
		  active => $mail->service,
		 );
      
      my $result = $self->{ldap}->search(\%args);
      my $entry = $result->entry(0);
      
      my $usermail = $entry->get_value('mail');
      
      return $usermail;
}


# Method: delAccountsFromVDomain
#
#  This method removes all mail accounts from a virtual domain
#
# Parameters:
# 
#		vdomain - the virtual domain name
sub delAccountsFromVDomain () { #vdomain
	my ($self, $vdomain) = @_;

	my %accs = %{$self->allAccountsFromVDomain($vdomain)};

	my $mail = "";
	foreach my $uid (keys %accs) {
		$mail = $accs{$uid};
		$self->delUserAccount($uid, $accs{$uid});
	}
}

# Method: getUserLdapValue
#
#  This method returns the value of an atribute in users leaf
#
# Parameters:
#
# 		uid - uid of the user
#		value - the atribute name
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

sub existsUserLdapValue () { #uid, ldap value
	my ($self, $uid, $value) = @_;
	my $users = EBox::Global->modInstance('users');

	my %args = (
			base => $users->usersDn(),
			filter => "&(objectclass=*)(uid=$uid)",
			scope => 'one',
			attrs => [$value]
	);

	my $result = $self->{ldap}->search(\%args);

	foreach my $entry ($result->entries()) {
	    if (defined ($entry->get_value($value))) {
		return 1;
	    }
	}

	return undef;
}



sub _delGroup() { #groupname
	my ($self, $group) = @_;
    
	return unless (EBox::Global->modInstance('mail')->configured());

	my $mail = EBox::Global->modInstance('mail');
	$mail->{malias}->delAliasGroup($group);
	
}

sub _delGroupWarning() {
	my ($self, $group) = @_;

	return unless (EBox::Global->modInstance('mail')->configured());

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

	return unless (EBox::Global->modInstance('mail')->configured());

	$self->delUserAccount($user);
	
}

sub _delUserWarning() {
	my ($self, $user) = @_;

	return unless (EBox::Global->modInstance('mail')->configured());

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

	return unless (EBox::Global->modInstance('mail')->configured());

	my $mail = EBox::Global->modInstance('mail');

	my $usermail = $self->userAccount($username);
	my @aliases = $mail->{malias}->accountAlias($usermail);
	my @vdomains =  $mail->{vdomains}->vdomains();

	my @paramsList = ( 
			  'username'	=>	$username,
			  'mail'	=>	$usermail,
			  'aliases'	=> \@aliases,
			  'vdomains'	=> \@vdomains,
			  service => $mail->service,
			 );


	if ($mail->mdQuotaAvailable) {
	  push @paramsList, $self->_mdQuotaAccountAddonParams($username);
	  
	}

	return { path => '/mail/account.mas', params => { @paramsList } };
}





sub _groupAddOns() {
	my ($self, $group) = @_;

	return unless (EBox::Global->modInstance('mail')->configured());

	my $mail = EBox::Global->modInstance('mail');
	my $users = EBox::Global->modInstance('users');

	
	my %args = (
			base => $mail->{malias}->aliasDn,
			filter => "&(objectclass=*)(uid=$group)",
			scope => 'one',
			attrs => ['mail'],
		        service => $mail->service,
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
			'alias'		=> $alias,
			'nacc' => scalar ($self->usersWithMailInGroup($group)),
	};
	
	return { path => '/mail/groupalias.mas', params => $args };
}

sub _modifyGroup() {
	my ($self, $group) = @_;

	return unless (EBox::Global->modInstance('mail')->configured());

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

# Method: _accountExists
#
#  This method returns if a user have a mail account
#
# Parameters:
# 
# 		username - username
# Returnss:
#
# 		bool - true if user have mail account
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


# Method: allAccountFromVDomain
#
#  This method returns all accounts from a virtual domain
#
# Parameters:
#
# 		vdomain - The Virtual domain name
#
# Returns:
#
# 		hash ref - with (uid, mail) pairs of the virtual domain
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

# Method: usersWithMailInGroup
#
#  This method returns the list of users with mail account on the group
#
# Parameters:
#
# 		groupname - groupname
# 	
sub usersWithMailInGroup() {
	my ($self, $groupname) = @_;
	my $users = EBox::Global->modInstance('users');

	my %args = (
		base => $users->usersDn,
		filter => "(objectclass=couriermailaccount)",
		scope => 'one',
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @mailusers;
	foreach my $entry ($result->entries()) {
	    push @mailusers, $entry->get_value('uid');
	}

	my $anyUserInGroup = any( @{ $users->usersInGroup($groupname) } );
	
	# the intersection between users with mail and users of the group
	my @mailingroup = grep {
	    $_ eq $anyUserInGroup
	} @mailusers;

	return @mailingroup;
}

# Method: checkUserMDSize
#
#  This method returns all users that should be warned about a reduction on the
#  maildir size
#
# Parameters:
#
# 		vdomain - The Virtual domain name
#		newmdsize - The new maildir size
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

# Method: _getActualMDSize
#
#  This method returns the maildir size of a user account
#
# Parameters:
#
# 		username - username
#
# Returns:
#
# 		maildir size
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

	   return [] unless (EBox::Global->modInstance('mail')->configured());

	   my @schemas = SCHEMAS;

	   return \@schemas;
}

# Method: _createMaildir
#
#  This method creates the maildir of an account
#
# Parameters:
#
# 		lhs - left hand side of an account (foo on foo@bar.baz)
#		vdomain - Virtual Domain name
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



#  Method: maildir
#
#     get the maildir which will be used by the given account
#
#   Parameters:
# 		lhs - left hand side of an account (foo on foo@bar.baz)
#		vdomain - Virtual Domain name
#  
#   Returns:
#         full path of the maildir
sub maildir
{
  my ($class, $lhs, $vdomain) = @_;

  return "/var/vmail/$vdomain/$lhs/";
}


# Method: gidvmail
#
#  This method returns the gid value of ebox user
#
sub gidvmail() {
	my $self = shift;

	return scalar (getgrnam(EBox::Config::group));
}

# Method: uidvmail
#
#  This method returns the uid value of ebox user
#
sub uidvmail() {
	my $self = shift;

	return scalar (getpwnam(EBox::Config::user));
}

# Method: _isCourierObject
#
#  This method returns if the leaf have a courierobject class
#
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


sub _accountAddOn
{
        my ($self, $username) = @_;

	my $mail = EBox::Global->modInstance('mail');



}



# mail dir quota stuff///


sub _setUserAccountWithMdQuota
{
  my ($self, $dn, $mdsize) = @_;
  defined $mdsize  or $mdsize = 0;

  unless (isAPositiveNumber($mdsize)) {
    throw EBox::Exceptions::InvalidData(
					'data'	=> __('maildir size'),
					'value'	=> $mdsize);
  }
  
  if ($mdsize > MAXMGSIZE) {
    throw EBox::Exceptions::InvalidData(
					'data'	=> __('maildir size'),
					'value'	=> $mdsize);
  }

  my %attrs = ( 
	       changes => [ 
			   add => [
				   userMaildirSize => $mdsize * BYTES,
			],
			 
			  ]
	      );

  my $ldap = $self->{ldap};
  $ldap->modify($dn, \%attrs);
}



sub _userWithMdQuotaLdapAttrs
{
  my ($self, $username) = @_;

  # to be sure we check for the presence of mdQuota related attributes even when
  # quota is not available bz the attribute may be from a previous installation
  # via backup  or postfix upgrade

  my $attrExists =  $self->existsUserLdapValue($username, "userMaildirSize");

  if (not  $attrExists) {
    # attribute deos not exist so nothing to delete
    return ();
  }

  return (
	  userMaildirSize => $self->getUserLdapValue($username, "userMaildirSize")
	 );

}




# Method: setMDSize
#
#  This method sets maildir size to a user account
#
# Parameters:
#
# 		uid - username
#		mdsize - new maildir size
sub setMDSize() {
	my ($self, $uid, $mdsize) = @_;

	my $mail = EBox::Global->modInstance('mail');
	$mail->assureMdQuotaIsAvailable();


	my $users = EBox::Global->modInstance('users');
	
	unless (isAPositiveNumber($mdsize)) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $mdsize);
	}
	
	if($mdsize > MAXMGSIZE) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $mdsize);
	}

	my $dn = "uid=$uid," .  $users->usersDn;
	my $r = $self->{'ldap'}->modify($dn, {
		replace => { 'userMaildirSize' => $mdsize * $self->BYTES }});
}




sub _mdQuotaAccountAddonParams
{
  my ($self, $username) = @_;

  my $mail = EBox::Global->modInstance('mail');
  my $users = EBox::Global->modInstance('users');
  
  my %args = (
	      base => $users->usersDn,
	      filter => "&(objectclass=*)(uid=$username)",
	      scope => 'one',
	      attrs => ['mail', 'userMaildirSize'],
	      active => $mail->service,
	     );
  
  my $result = $self->{ldap}->search(\%args);
  my $entry = $result->entry(0);

  my $mdsize = $entry->get_value('userMaildirSize');



  my @params = (
		mdQuotaAvailable  => 1,
		mdsize => ($mdsize / BYTES),
	       );

  return @params;
}

1;
