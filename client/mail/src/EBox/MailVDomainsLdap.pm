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
use EBox::Global;
use EBox::Ldap;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use constant VDOMAINDN     => 'ou=vdomains, ou=postfix';

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

	# Verify vdomain exists
	if ($self->vdomainExists($vdomain)) {
		throw EBox::Exceptions::DataExists('data' => __('virtual domain'),
														'value' => $vdomain);
	}
	
	# Black magic here! the atribute default maildir size for the virtual domains 
	# 
	my $dn = "domainComponent=$vdomain, " . $self->vdomainDn;
	my %attrs = ( 
		attr => [
			'domainComponent'	=> $vdomain,
			'vddftMaildirSize'=> $dftmdsize,
			'objectclass'		=> 'domain',
			'objectclass'		=> 'vdeboxmail'
		]
	);

	my $r = $self->{'ldap'}->add($dn, \%attrs);

#	$self->_createHome("/var/vmail/$vdomain");
}

sub delVDomain($$) { #vdomain
	my $self = shift;
	my $vdomain = shift;

	# Verify vdomain exists
	unless ($self->vdomainExists($vdomain)) {
		throw EBox::Exceptions::DataNotFound('data' => __('virtual domain'),
														'value' => $vdomain);
	}

	# We Should warn about users whose mail account belong to this vdomain.

	my $r = $self->{'ldap'}->delete("domainComponent=$vdomain, " .
	$self->vdomainDn);
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

	my %vdomains = map { $_->get_value('dc'), $_->get_value('vddftMaildirSize')}
		$result->sorted('domainComponent');

	return %vdomains;
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

1;
