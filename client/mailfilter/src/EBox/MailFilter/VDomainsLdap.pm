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
use EBox::MailAliasLdap;
use EBox::MailFilter::Types::AntispamThreshold;

# LDAP schema
use constant SCHEMAS            => ('/etc/ldap/schema/amavis.schema', '/etc/ldap/schema/eboxfilter.schema');




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
        $self->_deleteVDomainAttr($vdomain, $attr);
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
    $self->_setSenderList($vdomain, 'amavisWhitelistSender', $senderList_r);
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
    $self->_setSenderList($vdomain, 'amavisBlacklistSender', $senderList_r);
}


sub _setSenderList
{
    my ($self, $vdomain, $listName, $senderList_r) = @_;
    my @senderList = @{ $senderList_r };

    # validate senders
    foreach my $sender (@senderList) {
        EBox::MailFilter::Types::AmavisSender->validate($sender);
    }

    # remove old list
    if ($self->_vdomainAttr($vdomain, $listName)) {
        $self->_deleteVDomainAttr($vdomain, $listName);
    }
    
    # set new list
    if (@senderList) {
        $self->_addVDomainAttr($vdomain, $listName, @senderList);
    }
}


# Method: spamThreshold
#
#  get the spam threshold for the vdomain. Please note than in the actual
#  implementation amavisSpamTag2Level and amavisSpamKillLevel are setted to the
#  same value
sub spamThreshold
{
    my ($self, $vdomain) = @_;
    my $threshold = $self->_vdomainAttr($vdomain, 'amavisSpamTag2Level');
    return $threshold;
}


# Method: setSpamThreshold
#
#  set the spam threshold for the vdomain. Please note than in the actual
#  implementation amavisSpamTag2Level and amavisSpamKillLevel are setted to the
#  same value
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
        my @toDelete;
        foreach my $attr (qw(amavisSpamTag2Level amavisSpamKillLevel)) {
            # if attribute exists, mark for deletion
            if ($self->_vdomainAttr($attr)) {
                push @toDelete, $attr;
            }
        }

        # if we don;t have nothing to delete end here
        @toDelete or
            return;


        $ldap->modify(
                      $dn,
                      {
                       delete =>  \@toDelete
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


sub _addVDomain
{
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




sub spamAccount
{
    my ($self, $vdomain) = @_;
    return $self->_hasAccount($vdomain, 'spam');
}


sub hamAccount
{
    my ($self, $vdomain) = @_;
    return $self->_hasAccount($vdomain, 'ham');
}

sub learnAccountsExists
{
    my ($self) = @_;

    my @vdomains =  $self->vdomains() ;
    foreach my $vdomain (@vdomains) {
        if ($self->spamAccount($vdomain) or $self->hamAccount($vdomain)) {
            return 1;
        }
    }

    return 0;
}


sub _hasAccount
{
    my ($self, $vdomain, $user) = @_;

    my $mail         = EBox::Global->modInstance('mail');
    my $mailUserLdap = $mail->_ldapModImplementation();
    my $mailAliasLdap = new EBox::MailAliasLdap;


    my $account = $mailUserLdap->userAccount($user);
    if (not defined $account) {
        # control account not defined in any domain
        return 0;
    }
    
    my ($lh, $accountVdomain) = split '@', $account;
        
    if ($vdomain eq $accountVdomain) {
        # this domain has the control account itseldf
        return 1;
    }
        
    my $alias = $user . '@' . $vdomain;
    if ($mailAliasLdap->aliasExists($alias)) {
        return 1;
    }

    # neither account itself or alias in this domain
    return 0;
}


sub setSpamAccount
{
    my ($self, $vdomain, $active) = @_;
    $self->_setAccount($vdomain, 'spam', $active);
}


sub setHamAccount
{
    my ($self, $vdomain, $active) = @_;
    $self->_setAccount($vdomain, 'ham', $active);
}



sub _setAccount
{
    my ($self, $vdomain, $user, $active) = @_;

    if ($active) {
        $self->_addAccount($vdomain, $user);
    }
    else {
        $self->_removeAccount($vdomain, $user);
    }

}


sub _addAccount
{
    my ($self, $vdomain, $user) = @_;

    my $mail         = EBox::Global->modInstance('mail');
    my $mailUserLdap = $mail->_ldapModImplementation();
    my $mailAliasLdap = new EBox::MailAliasLdap;

    my $account = $mailUserLdap->userAccount($user);
    
    if (defined $account) {
        my ($lh, $accountVdomain) = split '@', $account;
        
        if ($vdomain eq $accountVdomain) {
            # this domain has the account so we haven't nothing to do
            return;
        }
        
        my $alias = $user . '@' . $vdomain;
        if (not $mailAliasLdap->aliasExists($alias)) {
            $mailAliasLdap->addAlias($alias, $account, $user);
            }
    }
    else {
        $mailUserLdap->setUserAccount($user, $user, $vdomain);      
    }
}


sub _removeAccount
{
    my ($self, $vdomain, $user) = @_;
    
    my $mail         = EBox::Global->modInstance('mail');
    my $mailUserLdap = $mail->_ldapModImplementation();

    my $account = $mailUserLdap->userAccount($user);
    defined $account or
        return;

    my @vdomains = grep {
        ($_ ne $vdomain) and $self->_hasAccount($_, $user) 
    } $self->vdomains();


    # remove account and all its addresses
    $mailUserLdap->delUserAccount($user, $account);
    # add account for domains which need it
    foreach my $vd (@vdomains) {
        $self->_addAccount($vd, $user);
    }
    
}

sub _delVDomain
{
    my ($self, $vdomain) = @_;
    
    return unless ($self->_moduleConfigured());
    

    # remove ham and spam accounts
    $self->setSpamAccount($vdomain, 0);
    $self->setHamAccount($vdomain, 0);


    # remove from ldap if neccesary
    my $ldap = $self->{ldap};
    my $dn =  $self->vdomainDn($vdomain);

    if ( $ldap->isObjectClass($dn, 'vdmailfilter')) {
        $ldap->delObjectclass($dn, 'vdmailfilter');
    }

}

sub _modifyVDomain
{
}

sub _delVDomainWarning
{
}




sub _includeLDAPSchemas 
{
    my ($self) = @_;

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


# Method: resetVDomain
#
#  restore default antispam configuration for the give domain
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

    # remove ham/spam ocntrol accounts
    $self->setSpamAccount($vdomain, 0);
    $self->setHamAccount($vdomain, 0);
}


sub regenConfig
{
    my ($self) = @_;

    my %vdomainsNotConfigured = map {  $_ => 1 } $self->vdomains();

    my $mf =  EBox::Global->modInstance('mailfilter');
    my $vdomainsTable = $mf->model('VDomains');

    foreach my $vdRow (@{ $vdomainsTable->rows() }) {
        my $vdomain     = $vdomainsTable->nameFromRow($vdRow);
        my $antivirus   = $vdRow->elementByName('antivirus')->value();
        my $antispam    = $vdRow->elementByName('antispam')->value();
        my $threshold   = $vdomainsTable->spamThresholdFromRow($vdRow);
        my $hamAccount  = $vdRow->elementByName('hamAccount')->value();
        my $spamAccount = $vdRow->elementByName('spamAccount')->value();

        $self->setAntivirus($vdomain, $antivirus);        
        $self->setAntispam($vdomain, $antispam);
        $self->setSpamThreshold($vdomain, $threshold);

        
        $self->setHamAccount($vdomain, $hamAccount);
        $self->setSpamAccount($vdomain, $spamAccount);


        my @whitelist;
        my @blacklist;

        my $acl = $vdRow->subModel('acl');
        foreach my $aclRow (@{ $acl->rows  }) {
            my $sender = $aclRow->elementByName('sender')->value();
            my $policy = $aclRow->elementByName('policy')->value();

            if ($policy eq 'blacklist') {
                push @blacklist, $sender;
            }
            elsif ($policy eq 'whitelist') {
                push @whitelist, $sender;
            }
        }

        $self->setWhitelist($vdomain, \@whitelist);
        $self->setBlacklist($vdomain, \@blacklist);

        delete $vdomainsNotConfigured{$vdomain};
    }

    # vdomains no present in the table are reseted to not config state
    foreach my $vdomain (keys %vdomainsNotConfigured) {
        $self->resetVDomain($vdomain);
    }
}


1;
