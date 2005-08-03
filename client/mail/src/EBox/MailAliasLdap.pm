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

package EBox::MailAliasLdap;

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

use constant ALIASDN     => 'ou=mailalias, ou=postfix';

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = new EBox::Ldap;
	bless($self, $class);
	return $self;
}

sub addAlias ($$$$) { #mail alias account, maildrop, id(mailuser or groupname)
	my $self = shift;
	my $alias = shift;
	my $maildrop = shift;
	my $id = shift;
	
	#RFC compliant
	unless ($alias =~ /^[^\.\-][\w\.\-]+\@[^\.\-][\w\.\-]+$/) {
		throw EBox::Exceptions::InvalidData('data' => __('mail account'),
														'value' => $alias);
   }
	# Verify mail exists
	if ($self->accountExists($alias)) {
		throw EBox::Exceptions::DataExists('data' => __('mail account'),
														'value' => $alias);
	}
	
	my $dn = "mail=$alias, " . $self->aliasDn();
	my %attrs = ( 
		attr => [
			'objectclass'		=> 'couriermailalias',
			'objectclass'		=>	'account',
			'userid'				=> $id,
			'mail'				=>	$alias,
			'maildrop'			=> $maildrop
		]
	);

	my $r = $self->{'ldap'}->add($dn, \%attrs);
}

sub addGroupAlias ($$$) { #mail alias, groupname
	my $self = shift;
	my $alias = shift;
	my $groupname = shift;
	my $users = EBox::Global->modInstance('users');

	unless ($alias =~ /^[^\.\-][\w\.\-]+\@[^\.\-][\w\.\-]+$/) {
		throw EBox::Exceptions::InvalidData('data' => __('mail account'),
														'value' => $alias);
   }
	
	if ($self->accountExists($alias)) {
		throw EBox::Exceptions::DataExists('data' => __('mail account'),
														'value' => $alias);
	}

	my %args = (
		base => $users->usersDn,
		filter => "(objectclass=couriermailaccount)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @mailusers;
	foreach my $user ($result->sorted('mail')) {
		push(@mailusers, $user->get_value('mail'));
	}
	my @usersingroup = @{$users->usersInGroup($groupname)};
	
	# the intersection between users with mail and users of the group
	my @mailingroup;
	foreach my $m (@mailusers) {
		my $temp = (split(/@/, $m))[0];
		if (grep(/^$temp$/,@usersingroup)) {
			push (@mailingroup, $m);
		}
	}

	my $aux = 0;
	foreach my $mail (@mailingroup)
	{
		if ($aux++ == 0) { 
			$self->addAlias($alias, $mail, $groupname); 
		} else {
			$self->addMaildrop($alias, $mail);
		}
	}

}

sub updateGroupAlias ($$$) {
	my ($self, $group, $alias) = @_;

	my $users = EBox::Global->modInstance('users');

	unless ($self->accountExists($alias)) {
		throw EBox::Exceptions::DataNotFound('data' => __('mail account'),
														'value' => $alias);
	}

	my %args = (
		base => $users->usersDn,
		filter => "(objectclass=couriermailaccount)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @mailusers;
	foreach my $user ($result->sorted('mail')) {
		push(@mailusers, $user->get_value('mail'));
	}
	my @usersingroup = @{$users->usersInGroup($group)};
	
	# the intersection between users with mail and users of the group
	my @mailingroup;
	foreach my $m (@mailusers) {
		my $temp = (split(/@/, $m))[0];
		if (grep(/^$temp$/,@usersingroup)) {
			push (@mailingroup, $m);
		}
	}

	%args = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(userid=$group)",
		scope => 'one',
		attrs => ['maildrop']
	);
	
	$result = $self->{ldap}->search(\%args);

	my @maildrops;
	foreach my $md ($result->sorted('maildrop')) {
		push(@maildrops, $md->get_value('maildrop'));
	}

	$self->delAliasGroup($group);
	$self->addGroupAlias($alias,$group);
}


sub addMaildrop ($$$) { #alias account, mail account to add
	my $self = shift;
	my $alias = shift;
	my $maildrop = shift;

	unless ($self->aliasExists($alias)) {
		throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
														'value' => $alias);
	}

	my $dn = "mail=$alias, " . $self->aliasDn();

	my %attrs = (
		changes => [
			add => [ 'maildrop'	=> $maildrop ]
		]
	);

	my $r = $self->{'ldap'}->modify($dn, \%attrs);
}

sub delMaildrop ($$$) { #alias account, mail account to remove
	my $self = shift;
	my $alias = shift;
	my $maildrop = shift;

	unless ($self->aliasExists($alias)) {
		throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
														'value' => $alias);
	}

	my $dn = "mail=$alias, " . $self->aliasDn();

	#if is the last maildrop delete the alias account
	my @mlist = @{$self->accountListByAliasGroup($alias)};
	my %attrs;

	if (@mlist == 1) {
		$self->delAlias($alias);
	} else {
		%attrs = (
			changes => [
				delete => [ 'maildrop'	=> $maildrop ]
			]
		);
		my $r = $self->{'ldap'}->modify($dn, \%attrs);
	}	

}

sub delAlias($$) { #mail alias account
	my $self = shift;
	my $alias = shift;

	unless ($self->aliasExists($alias)) {
		throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
														'value' => $alias);
	}

	# We Should warn about users whose mail account belong to this vdomain.

	my $r = $self->{'ldap'}->delete("mail=$alias, " . $self->aliasDn);
}

sub delAliasesFromVDomain () {
	my ($self, $vdomain) = @_;

	my @aliases = @{$self->_allAliasFromVDomain($vdomain)};

	foreach (@aliases) {
		$self->delAlias($_);
	}
}

sub delAliasGroup($$) {
	my ($self, $group) = @_;

	my %args = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(userid=$group)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	if ($result->count > 0) {
		my $alias = ($result->sorted('mail'))[0]->get_value('mail');
		$self->delAlias($alias);
	}
}

sub accountAlias($$) { #mail account
	my $self = shift;
	my $mail = shift;

	my %args = (
		base => $self->aliasDn,
		filter => "&(userid=$mail)(maildrop=$mail)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @malias = ();
	foreach my $alias ($result->sorted('mail'))
	{
		@malias = (@malias, $alias->get_value('mail'));
	}

	return @malias;
}

sub groupAccountAlias($$) { #mail account
	my $self = shift;
	my $mail = shift;

	my %args = (
		base => $self->aliasDn,
		filter => "&(!(userid=$mail))(maildrop=$mail)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @malias = ();
	foreach my $alias ($result->sorted('mail'))
	{
		@malias = (@malias, $alias->get_value('mail'));
	}

	return @malias;
}

sub accountListByAliasGroup() {
	my ($self, $mail) = @_;

	my %args = (
		base => $self->aliasDn,
		filter => "(mail=$mail)",
		scope => 'one',
		attrs => ['maildrop']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @mlist = map { $_->get_value('maildrop') } $result->sorted('uid');

	return \@mlist;
}

sub aliasDn
{
	my $self = shift;
	return ALIASDN . ", " . $self->{ldap}->dn;
}

sub listMailGroupsByUser($$) {
	my ($self, $user) = @_;
	my @list;
	my $users = EBox::Global->modInstance('users');

	my @groups = @{$users->groupOfUsers($user)};
	
	foreach my $group (@groups) {
		if ($self->groupHasAlias($group)) {
			push(@list, $group);
		}
	}
	return @list;
}

sub groupAlias ($$) {
	my ($self, $group) = @_;

	my %args = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(uid=$group)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	return (($result->sorted('mail'))[0]->get_value('mail'));
}

sub groupHasAlias ($$) {
	my ($self, $group) = @_;

	my %args = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(uid=$group)",
		scope => 'one',
		attrs => ['mail']
	);
	
	my $result = $self->{ldap}->search(\%args);

	return ($result->count > 0);
}
		
sub aliasExists($$) { #mail alias account
	my $self = shift;
	my $alias = shift;

	my %attrs = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(mail=$alias)",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);
}

sub accountExists($$) { #mail alias account
	my $self = shift;
	my $alias = shift;
	my $users = EBox::Global->modInstance('users');

	my %attrs = (
		base => $users->usersDn,
		filter => "&(objectclass=couriermailaccount)(mail=$alias)",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);

	return (($result->count > 0) || ($self->aliasExists($alias)));
}

sub _allAliasFromVDomain () { #vdomain
	my ($self, $vdomain) = @_;

	my %attrs = (
		base => $self->aliasDn,
		filter => "&(objectclass=couriermailalias)(mail=*@".$vdomain.")",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);

	my @alias = map { $_->get_value('mail')} $result->sorted('mail');

	return \@alias;
}

1;
