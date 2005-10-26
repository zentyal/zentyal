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

package EBox::MailVDomainsLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use constant VDOMAINDN     => 'ou=vdomains, ou=postfix';
use constant BYTES				=> '1048576';
use constant MAXMGSIZE				=> '104857600';

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = new EBox::Ldap;
	bless($self, $class);
	return $self;
}

sub addVDomain { #vdomain
	my ($self, $vdomain, $dftmdsize) = @_;
	
	my $ldap = $self->{ldap};

	checkDomainName($vdomain, 'Virtual domain name');
	
	# Verify vdomain exists
	if ($self->vdomainExists($vdomain)) {
		throw EBox::Exceptions::DataExists('data' => __('virtual domain'),
														'value' => $vdomain);
	}
	
	unless (isAPositiveNumber($dftmdsize)) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $dftmdsize);
	}
	
	if($dftmdsize > MAXMGSIZE) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $dftmdsize);
	}
	
	my $dn = "domainComponent=$vdomain, " . $self->vdomainDn;
	my %attrs = ( 
		attr => [
			'domainComponent'	=> $vdomain,
			'vddftMaildirSize'=> ($dftmdsize * $self->BYTES),
			'objectclass'		=> 'domain',
			'objectclass'		=> 'vdeboxmail'
		]
	);

	my $r = $self->{'ldap'}->add($dn, \%attrs);

	$self->_initVDomain($vdomain);
}

sub _initVDomain() {
	my ($self, $vdomain) = @_;

	my @mods = @{$self->_modsVDomainModule()};

	foreach my $mod (@mods){
		$mod->_addVDomain($vdomain);
	}
}

sub delVDomain($$) { #vdomain
	my $self = shift;
	my $vdomain = shift;
	my $mail = EBox::Global->modInstance('mail');
	
	# Verify vdomain exists
	unless ($self->vdomainExists($vdomain)) {
		throw EBox::Exceptions::DataNotFound('data' => __('virtual domain'),
														'value' => $vdomain);
	}

	# We Should warn about users whose mail account belong to this vdomain.
	$mail->{malias}->delAliasesFromVDomain($vdomain);
	$mail->{musers}->delAccountsFromVDomain($vdomain);

	$self->_cleanVDomain($vdomain);

	my $r = $self->{'ldap'}->delete("domainComponent=$vdomain, " .
	$self->vdomainDn);
}

sub _cleanVDomain() {
	my ($self, $vdomain) = @_;

	my @mods = @{$self->_modsVDomainModule()};

	foreach my $mod (@mods){
		$mod->_delVDomain($vdomain);
	}
}

sub vdomains($)
{
	my $self = shift;

	my %args = (
		base => $self->vdomainDn,
		filter => 'objectclass=*',
		scope => 'one',
		attrs => ['domainComponent']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my @vdomains = map { $_->get_value('dc')} $result->sorted('domainComponent');

	return @vdomains;
}

sub vdandmaxsizes()
{
	my $self = shift;

	my %args = (
		base => $self->vdomainDn,
		filter => 'objectclass=*',
		scope => 'one',
		attrs => ['domainComponent', 'vddftMaildirSize']
	);
	
	my $result = $self->{ldap}->search(\%args);

	my %vdomains = map { $_->get_value('dc'), ($_->get_value('vddftMaildirSize') / $self->BYTES)}
	$result->sorted('domainComponent');

	return %vdomains;
}

sub getMDSize() {
	my ($self, $vdomain) = @_;
	
	my %args = (
		base => $self->vdomainDn,
		filter => 'domainComponent='.$vdomain,
		scope => 'one',
		attrs => ['vddftMaildirSize']
	);
	
	my $result = $self->{ldap}->search(\%args);
	my $entry = $result->entry(0);

	my $mdsize = $entry->get_value('vddftMaildirSize');

	return ($mdsize / $self->BYTES);
}

sub setMDSize() {
	my ($self, $vdomain, $mdsize) = @_;
   
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

	my $dn = "domainComponent=$vdomain," .  $self->vdomainDn;

	$self->_updateVDomain($vdomain);

	my $r = $self->{'ldap'}->modify($dn, {
		replace => { 'vddftMaildirSize' => $mdsize * $self->BYTES }});
}

sub updateMDSizes() {
	my ($self, $vdomain, $mdsize) = @_;
	my $mail = EBox::Global->modInstance('mail');
	
	my %accounts = %{$mail->{musers}->allAccountsFromVDomain($vdomain)};

	foreach my $uids (keys %accounts) {
		$mail->{musers}->setMDSize($uids, $mdsize);
	}
}

sub _updateVDomain() {
	my ($self, $vdomain) = @_;

	my @mods = @{$self->_modsVDomainModule()};

	foreach my $mod (@mods){
		$mod->_modifyVDomain($vdomain);
	}
}

sub vdomainDn
{
	my $self = shift;
	return VDOMAINDN . ", " . $self->{ldap}->dn;
}
		
sub vdomainExists($$) { #vdomain 
	my $self = shift;
	my $vdomain = shift;

	my %attrs = (
		base => $self->vdomainDn,
		filter => "&(objectclass=*)(dc=$vdomain)",
		scope => 'one'
	);

	my $result = $self->{'ldap'}->search(\%attrs);

	return ($result->count > 0);
}

sub _modsVDomainModule {
	my $self = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};

	my @modules;
	foreach my $name (@names) {
		my $mod = EBox::Global->modInstance($name);
		if ($mod->isa('EBox::VDomainModule')) {
			push (@modules, $mod->_vdomainModImplementation);
		}
	}

	return \@modules;
}

# Method: allWarning
#
#  Returns all the the warnings provided by the modules when a certain
#  virtual domain is going to be deleted. Function _delVDomainWarning 
#  is called in all module implementing them.
#
# Parameters:
#
#  name - name of the virtual domain
#
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings($$$)
{
	my ($self, $name) = @_;

	my @modsFunc = @{$self->_modsVDomainModule()};
	my @allWarns;

	foreach my $mod (@modsFunc) {
		my $warn = undef;
		$warn = $mod->_delVDomainWarning($name);
		push (@allWarns, $warn) if ($warn);
	}

	return \@allWarns;
}

sub allVDomainsAddOns # (user)
{
	my ($self, $vdomain) = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};

	my @modsFunc = @{$self->_modsVDomainModule()};
	my @components;
	foreach my $mod (@modsFunc) {
		my @comp = @{$mod->_vdomainAddOns($vdomain)};
		if (@comp) {
			push (@components, @comp);
		}
	}

	return \@components;
}

1;
