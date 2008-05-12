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

package EBox::MailFilter::VDomainsLdap;
use base qw(EBox::LdapUserBase EBox::LdapVDomainBase);

use strict;
use warnings;



use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Gettext;
use EBox::MailVDomainsLdap;


# LDAP schema
use constant SCHEMAS		=> ('/etc/ldap/schema/amavis.schema', '/etc/ldap/schema/eboxfilter.schema');




sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = EBox::Ldap->instance();
	bless($self, $class);
	return $self;
}

sub _moduleConfigured
{
    my ($self) = @_;
    my $mf =  EBox::Global->modInstance('mailfilter');

    return $mf->configured();
}

sub _vdomainAttr
{
  my ($self, $vdomain, $attr) = @_;

    my %args = (
		base => $self->vdomainTreeDn($vdomain),
		filter => 'domainComponent=' . $vdomain,
		scope => 'one',
		attrs => ["$attr"],
	       );
	
    my $result = $self->{ldap}->search(\%args);
  
  
  my $entry = $result->entry(0);
  defined $entry or return undef;

  my @values = $entry->get_value($attr);
  if (wantarray) {
    return @values;
  }
  else {
    return $values[0];
  }
}


sub _vdomainBoolAttr
{
  my $value = _vdomainAttr(@_);

  if (defined $value) {
    if ($value eq 'TRUE') {
      return 1;
    }
    elsif ($value eq 'FALSE') {
      return 0;
    }
    else {
      throw EBox::Exceptions::Internal ("A bool attr must return either FALSE or TRUE (waas $value)");
    }


  }
  else {
    return undef;
  }
  

}


sub _setVDomainAttr
{
  my ($self, $vdomain, $attr, $value) = @_;

  my $dn =  $self->vdomainDn($vdomain);



  my $ldap = $self->{'ldap'};
  if (defined $value) {
    $ldap->modifyAttribute($dn, $attr => $value);
  }
  else {
    $ldap->modifyAttribute(
			   $dn,
			   delete => [
				      $attr,
				     ],
			  );
  }

  $self->_updateVDomain($vdomain);
}


sub _setVDomainBoolAttr
{
  my ($self, $vdomain, $attr, $value) = @_;

  if (defined $value) {
    $value = $value ? 'TRUE' : 'FALSE';
  }

  $self->_setVDomainAttr($vdomain, $attr, $value);
}


sub _addVDomainAttr
{
  my ($self, $vdomain, $attr, @values) = @_;

  my $dn =  $self->vdomainDn($vdomain);
  my $ldap = $self->{'ldap'};


  my @addList;
  if (@values == 1) {
    @addList = ($attr => $values[0]);
  }
  else {
    @addList = ($attr => \@values)
  }

  $ldap->modify(
		$dn,
		{
		 add => [
			 @addList
			],
		}
	       );

  $self->_updateVDomain($vdomain);
}


sub _deleteVDomainAttr
{
  my ($self, $vdomain, $attr, @values) = @_;

  my $dn =  $self->vdomainDn($vdomain);
  my $ldap = $self->{'ldap'};

  my @deleteParams;
  if (@values == 0) {
    @deleteParams = ($attr);
  }
  elsif (@values == 1) {
    @deleteParams = ($attr  => $values[0]);
  }
  else {
    @deleteParams = ($attr => \@values);
  }

    $ldap->modify(
		  $dn,
		  {
		   delete => [
			      @deleteParams
			     ],
		  }
		 );

  $self->_updateVDomain($vdomain);
}


sub whitelist
{
  my ($self, $vdomain) = @_;
  my @wl = $self->_vdomainAttr($vdomain, 'amavisWhitelistSender');
  return @wl;
}


sub setWhitelist
{
  my ($self, $vdomain, $senderList_r) = @_;

  if ($self->whitelist($vdomain)) {
    $self->_deleteVDomainAttr($vdomain, 'amavisWhitelistSender');
  }


  my @senderList = @{ $senderList_r };
  if (@senderList) {
    $self->_addVDomainAttr($vdomain, 'amavisWhitelistSender', @senderList);
  }

}

sub blacklist
{
  my ($self, $vdomain) = @_;
  my @wl = $self->_vdomainAttr($vdomain, 'amavisBlacklistSender');
  return @wl;
}


sub setBlacklist
{
  my ($self, $vdomain, $senderList_r) = @_;

  if ($self->blacklist($vdomain)) {
    $self->_deleteVDomainAttr($vdomain, 'amavisBlacklistSender');
  }


  my @senderList = @{ $senderList_r };
  if (@senderList) {
    $self->_addVDomainAttr($vdomain, 'amavisBlacklistSender', @senderList);
  }

}








sub spamThreshold
{
    my ($self, $vdomain) = @_;
    my $threshold = $self->_vdomainAttr($vdomain, 'amavisSpamTag2Level');
    return $threshold;
}



sub setSpamThreshold
{
  my ($self, $vdomain, $threshold) = @_;

  my $dn =  $self->vdomainDn($vdomain);

  $self->_updateVDomain($vdomain);

  my $ldap = $self->{'ldap'};
  if (defined $threshold) {
    $ldap->modifyAttribute($dn,  'amavisSpamTag2Level' => $threshold);
    $ldap->modifyAttribute($dn,  'amavisSpamKillLevel' => $threshold);
  }
  else {
    $ldap->modify(
		  $dn,
		  {
		   delete => [
			      'amavisSpamTag2Level',
			      'amavisSpamKillLevel',
			     ],
		  }
		 );
  }

}


sub antispam
{
  my ($self, $vdomain) = @_;
  my $value = $self->_vdomainBoolAttr($vdomain, 'amavisBypassSpamChecks');
  $value = $value ? 0 : 1;  # the ldap attribute has reverse logic..
  return $value;
}


sub setAntispam
{
  my ($self, $vdomain, $value) = @_;

  $value = $value ? 0 : 1;  # the ldap attribute has reverse logic..

  $self->_setVDomainBoolAttr($vdomain, 'amavisBypassSpamChecks', $value);
}



sub antivirus
{
    my ($self, $vdomain) = @_;
    my $value =  $self->_vdomainBoolAttr($vdomain, 'amavisBypassVirusChecks');
    $value = $value ? 0 : 1;  # the ldap attribute has reverse logic..
    return $value;
}


sub setAntivirus
{
  my ($self, $vdomain, $value) = @_;
  
  $value = $value ? 0 : 1;  # the ldap attribute has reverse logic..

  $self->_setVDomainBoolAttr($vdomain, 'amavisBypassVirusChecks', $value);
}


sub _addVDomain() {
  my ($self, $vdomain) = @_;
  
  return unless ($self->_moduleConfigured());

  my $ldap = $self->{ldap};
  my $dn =  $self->vdomainDn($vdomain);

  if (not $ldap->isObjectClass($dn, 'vdmailfilter')) {
	   my %attrs = ( 
			changes => [ 
				    add => [
					    objectClass       => 'vdmailfilter',    
					    domainMailPortion => "\@$vdomain",
					   ],
				   ],
		     );
	
	   my $add = $ldap->modify($dn, \%attrs ); 
  }
}



sub _delVDomain() 
{
  my ($self, $vdomain) = @_;

  return unless ($self->_moduleConfigured());

  my $ldap = $self->{ldap};
  my $dn =  $self->vdomainDn($vdomain);

  if ( $ldap->isObjectClass($dn, 'vdmailfilter')) {
    $ldap->delObjectclass($dn, 'vdmailfilter');
  }
}

sub _modifyVDomain() {
}

sub _delVDomainWarning() {
}

sub _vdomainAddOns() {
  my ($self, $vdomain) = @_;

  return unless ($self->_moduleConfigured());

  my $mailfilter =  EBox::Global->modInstance('mailfilter');
  my $antivirus = $mailfilter->antivirus();
  my $antispam  = $mailfilter->antispam();

  my $globalSpamThreshold = 
  my $spamThreshold       = $antispam->vdomainSpamThreshold($vdomain);

  my @params = (
		vdomain => $vdomain,

		antivirus       => $antivirus->vdomainService($vdomain),
		globalAntivirus => $antivirus->service,
		
		antispam       => $antispam->vdomainService($vdomain),
		globalAntispam => $antispam->service,

		spamThreshold  =>  $antispam->vdomainSpamThreshold($vdomain),
		globalSpamThreshold => $antispam->spamThreshold(),
		
		whitelist     => $antispam->vdomainWhitelist($vdomain),
		blacklist     => $antispam->vdomainBlacklist($vdomain),
	       );


	my $pages = [
		{ 
			'name' => __('Mail filter settings'),
			'path' => 'mailfilter/vdomain.mas',
			'params' => \@params,
		},
	];
	

  return $pages;
}



sub _includeLDAPSchemas {
       my $self = shift;

       return [] unless ($self->_moduleConfigured());

       my @schemas = SCHEMAS;
      
       return \@schemas;
}


sub vdomains
{
  my $mailvdomain = new  EBox::MailVDomainsLdap();
  return $mailvdomain->vdomains();
}

sub vdomainDn
{
  my ($self, $vdomain) = @_;

  return "domainComponent=$vdomain," . $self->vdomainTreeDn() ;
}


sub vdomainTreeDn
{
  my $mailvdomain = new  EBox::MailVDomainsLdap();
  return $mailvdomain->vdomainDn();
}


sub _updateVDomain
{
  my ($self, $vdomain) = @_;
  EBox::MailVDomainsLdap->new()->_updateVDomain($vdomain);
}

sub checkVDomainExists
{
  my ($self, $vdomain) = @_;
  my $mailvdomains = EBox::MailVDomainsLdap->new();
  if (not $mailvdomains->vdomainExists($vdomain)) {
    throw EBox::Exceptions::External(__x(q{Virtual mail domain {vd} does not exist}, 
					 vd => $vdomain));
  }
}


#
#
#
sub resetVDomain
{
  my ($self, $vdomain) = @_;

  my $ldap = $self->{ldap};
  my $dn =  $self->vdomainDn($vdomain);

  $ldap->isObjectClass($dn, 'vdmailfilter') or 
    throw EBox::Exceptions::Internal("Bad objectclass");

  # reset booleans to false 
  my @boolMethods = qw(setAntivirus setAntispam);
  foreach my $method (@boolMethods) {
    $self->$method($vdomain, 1); 
  }

  # clear non-boolean atributtes
  my @delAttrs = ( 
		  'amavisVirusLover', 'amavisBannedFilesLover', 'amavisSpamLover',
		  'amavisSpamTagLevel', 'amavisSpamTag2Level',
		  'amavisSpamKillLevel', 'amavisSpamModifiesSubj',
		  'amavisSpamQuarantineTo',
		 );
  # use only setted attributes
  @delAttrs = grep { 
    my $value = $self->_vdomainAttr($vdomain, $_) ;
    defined $value;
  } @delAttrs;
  my %delAttrs = ( 
		  delete => \@delAttrs, 
		 );
	
  $ldap->modify($dn, \%delAttrs ); 

}

1;
